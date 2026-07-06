// Codex-style subagents for Pi.
// Local, dotfiles-managed replacement for npm:@tintinweb/pi-subagents.
// Reload Pi with /reload after editing this file.
// @ts-nocheck

import { Type } from "typebox";
import {
  DefaultResourceLoader,
  SessionManager,
  SettingsManager,
  createAgentSession,
  defineTool,
  getAgentDir,
  parseFrontmatter,
  type ExtensionAPI,
  type ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import { randomUUID } from "node:crypto";

type AgentStatus = "queued" | "running" | "completed" | "errored" | "interrupted";

type AgentDef = {
  name: string;
  description: string;
  tools?: string[];
  model?: string;
  thinking?: string;
  systemPrompt: string;
};

type AgentRecord = {
  id: string;
  path: string;
  taskName: string;
  parentPath: string;
  type: string;
  description: string;
  prompt: string;
  modelOverride?: string;
  thinkingOverride?: string;
  status: AgentStatus;
  createdAt: number;
  startedAt?: number;
  completedAt?: number;
  session?: any;
  abortController: AbortController;
  result?: string;
  error?: string;
  pendingMessages: string[];
  toolUses: number;
  turns: number;
};

const MAX_CONCURRENT = Number.parseInt(process.env.PI_CODEX_SUBAGENTS_MAX_CONCURRENT ?? "4", 10);
const DEFAULT_WAIT_MS = Number.parseInt(process.env.PI_CODEX_SUBAGENTS_WAIT_MS ?? "30000", 10);
const RESULT_PREVIEW_CHARS = 4000;
const NOTIFICATION_PREVIEW_CHARS = 12000;
const SUBAGENT_NOTIFICATION_TYPE = "pi-codex-subagent-notification";
const LIVE_WIDGET_KEY = "codex-subagents-live";
const LIVE_WIDGET_TICK_MS = 250;
const LIVE_WIDGET_FINISHED_LINGER_MS = 5000;
const LIVE_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

const DEFAULT_AGENTS = new Map<string, AgentDef>([
  [
    "general-purpose",
    {
      name: "general-purpose",
      description: "General-purpose agent for research, coding, and multi-step tasks.",
      tools: ["read", "bash", "edit", "write", "grep", "find", "ls"],
      systemPrompt: "You are a capable coding subagent. Work autonomously on the delegated task. Return a concise final answer with what you found or changed, tests run, and any blockers.",
    },
  ],
  [
    "Explore",
    {
      name: "Explore",
      description: "Fast read-only search agent for locating code, files, symbols, and references. Do not modify files.",
      tools: ["read", "grep", "find", "ls", "bash"],
      model: "anthropic/claude-haiku-4-5",
      systemPrompt: `# READ-ONLY EXPLORATION AGENT
You locate code and summarize findings. Do not create, edit, delete, move, or copy files. Use bash only for read-only commands such as ls, git status, git diff, find, rg, cat, head, and tail. Report exact paths and concise findings.`,
    },
  ],
  [
    "Plan",
    {
      name: "Plan",
      description: "Software architect agent for implementation plans and design trade-offs. Prefer read-only analysis.",
      tools: ["read", "grep", "find", "ls", "bash"],
      systemPrompt: "You are a planning subagent. Inspect the codebase as needed, then return a concrete implementation plan with key files, risks, and verification steps. Do not edit files unless explicitly asked.",
    },
  ],
]);

function textResult(text: string, details?: any) {
  return { content: [{ type: "text" as const, text }], details: details ?? {} };
}

function summarizeRecord(r: AgentRecord) {
  return {
    task_name: r.path,
    agent_id: r.id,
    type: r.type,
    status: r.status,
    turns: r.turns,
    tool_uses: r.toolUses,
    createdAt: r.createdAt,
    startedAt: r.startedAt,
    completedAt: r.completedAt,
    result_preview: r.result ? truncate(r.result) : undefined,
    error: r.error,
  };
}

function truncate(text: string | undefined, max = RESULT_PREVIEW_CHARS): string {
  const value = text ?? "";
  return value.length <= max ? value : `${value.slice(0, max)}\n\n[truncated ${value.length - max} chars]`;
}

function firstText(result: any): string {
  const item = result?.content?.find?.((part: any) => part?.type === "text");
  return item?.text ?? "";
}

function oneLine(text: string | undefined, max = 88): string {
  const value = (text ?? "").replace(/\s+/g, " ").trim();
  return value.length <= max ? value : `${value.slice(0, Math.max(0, max - 1))}…`;
}

function age(start?: number, end = Date.now()): string | undefined {
  if (!start) return undefined;
  const seconds = Math.max(0, Math.round((end - start) / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${minutes}m${rest.toString().padStart(2, "0")}`;
}

function statusIcon(status?: string, theme?: any): string {
  switch (status) {
    case "completed": return theme?.fg?.("success", "✓") ?? "✓";
    case "errored": return theme?.fg?.("error", "✗") ?? "✗";
    case "interrupted": return theme?.fg?.("warning", "■") ?? "■";
    case "running": return theme?.fg?.("warning", "⏳") ?? "⏳";
    case "queued": return theme?.fg?.("muted", "○") ?? "○";
    default: return theme?.fg?.("muted", "•") ?? "•";
  }
}

function statusLabel(status?: string): string {
  switch (status) {
    case "completed": return "completed";
    case "running": return "running";
    case "queued": return "queued";
    case "interrupted": return "interrupted";
    case "errored": return "error";
    default: return status ?? "unknown";
  }
}

function recordLine(record: any, theme: any, expanded = false): string {
  const name = record.task_name ?? record.path ?? record.agent_id ?? "agent";
  const title = theme.bold(name);
  const status = record.status ?? "unknown";
  const isError = status === "errored" || status === "interrupted";
  const icon = status === "running" ? theme.fg("accent", "⠋") : statusIcon(status, theme);
  const statusColor = isError ? "error" : status === "running" ? "accent" : "dim";
  let line = `${icon} ${title} ${theme.fg(statusColor, statusLabel(status))}`;

  const parts: string[] = [];
  if (record.type) parts.push(record.type);
  if (record.turns > 0) parts.push(`↻${record.turns}`);
  if (record.tool_uses > 0) parts.push(`${record.tool_uses} tool use${record.tool_uses === 1 ? "" : "s"}`);
  const elapsed = age(record.startedAt ?? record.createdAt, record.completedAt ?? Date.now());
  if (elapsed) parts.push(elapsed);
  if (parts.length) line += `\n  ${parts.map((p) => theme.fg("dim", p)).join(` ${theme.fg("dim", "·")} `)}`;

  if (record.error) {
    const err = expanded ? truncate(record.error, 1200).split("\n").slice(0, 20).join("\n") : oneLine(record.error, 100);
    line += `\n  ${theme.fg("error", `⎿  ${err}`)}`;
  } else if (record.result_preview) {
    if (expanded) {
      for (const l of truncate(record.result_preview, 2400).split("\n").slice(0, 30)) line += `\n${theme.fg("dim", `  ${l}`)}`;
    } else {
      line += `\n  ${theme.fg("dim", `⎿  ${oneLine(record.result_preview, 100)}`)}`;
    }
  } else if (status === "running" || status === "queued") {
    line += `\n  ${theme.fg("dim", `⎿  ${status === "queued" ? "waiting…" : "thinking…"}`)}`;
  }
  return line;
}

function renderRecords(records: any[], theme: any, expanded = false): Text {
  if (!records?.length) return new Text(theme.fg("muted", "No subagents."), 0, 0);
  const shown = expanded ? records : records.slice(0, 8);
  let text = shown.map((record) => recordLine(record, theme, expanded)).join("\n");
  if (!expanded && records.length > shown.length) text += `\n${theme.fg("muted", `… ${records.length - shown.length} more · Ctrl+O to expand`)}`;
  return new Text(text, 0, 0);
}

function extractRecordsFromResult(result: any): any[] {
  const details = result?.details ?? {};
  if (details.record) return [details.record];
  if (Array.isArray(details.records)) return details.records;
  if (Array.isArray(details.updates)) return details.updates;
  try {
    const parsed = JSON.parse(firstText(result));
    if (Array.isArray(parsed.agents)) return parsed.agents;
    if (Array.isArray(parsed.updates)) return parsed.updates;
    if (parsed.task_name || parsed.agent_id) return [parsed];
  } catch {
    // not json
  }
  return [];
}

function renderPlainResult(result: any, theme: any): Text {
  const text = firstText(result).trim();
  return new Text(text ? theme.fg("toolOutput", text) : theme.fg("success", "✓ delivered"), 0, 0);
}

function extractTaskPreview(args: any): string {
  return oneLine(args?.message ?? args?.prompt ?? "", 100);
}

function extractTarget(args: any): string {
  return args?.target ?? args?.task_name ?? args?.agent_id ?? "agent";
}

function extractText(content: any): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => {
      if (part?.type === "text") return part.text ?? "";
      if (part?.type === "toolCall") return `[tool:${part.name ?? part.toolName ?? "unknown"}]`;
      return "";
    })
    .filter(Boolean)
    .join("\n");
}

function lastAssistantText(session: any): string {
  const messages = session?.messages ?? [];
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg.role === "assistant") {
      const text = extractText(msg.content).trim();
      if (text) return text;
      try {
        const raw = JSON.stringify(msg.content ?? "");
        if (raw && raw !== "[]" && raw !== "\"\"") return raw;
      } catch {
        // ignore stringify fallback failures
      }
    }
  }
  return "";
}

function normalizeFinalAnswer(text: string | undefined): string {
  const value = (text ?? "").trim();
  return value || "(subagent completed without a final message)";
}

function collectResponseText(session: any) {
  let text = "";
  let finalText = "";
  const captureAssistant = (candidate: any) => {
    if (!candidate) return;
    if (candidate.role && candidate.role !== "assistant") return;
    const value = extractText(candidate.content ?? candidate).trim();
    if (value) finalText = value;
  };
  const unsubscribe = session.subscribe((event: any) => {
    if (event.type === "message_start") text = "";
    if (event.type === "message_update") {
      const update = event.assistantMessageEvent;
      if (update?.type === "text_delta") text += update.delta ?? "";
      if (update?.type === "text_end") finalText = String(update.content ?? text ?? "").trim();
      captureAssistant(event.message);
    }
    if (event.type === "turn_end") captureAssistant(event.message);
    if (event.type === "agent_end" && Array.isArray(event.messages)) {
      for (let i = event.messages.length - 1; i >= 0; i--) {
        captureAssistant(event.messages[i]);
        if (finalText) break;
      }
    }
  });
  return { getText: () => (finalText || text).trim(), unsubscribe };
}

function resolvePath(parentPath: string, taskName: string): string {
  const clean = taskName.trim().replace(/^\/+|\/+$/g, "");
  if (!clean) throw new Error("task_name is required");
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(clean)) {
    throw new Error("task_name must use letters, digits, dots, underscores, or hyphens");
  }
  return `${parentPath.replace(/\/$/, "")}/${clean}`;
}

function buildParentContext(ctx: ExtensionContext, forkTurns?: string): string {
  const mode = (forkTurns ?? "all").trim().toLowerCase();
  if (mode === "none") return "";

  const branch = ctx.sessionManager.getBranch?.() ?? [];
  const messages = branch.filter((entry: any) => entry.type === "message");
  let selected = messages;
  if (mode !== "all") {
    const n = Number.parseInt(mode, 10);
    if (Number.isFinite(n) && n > 0) selected = messages.slice(-n * 2);
  }

  const lines: string[] = [];
  for (const entry of selected) {
    const msg = entry.message;
    if (!msg) continue;
    if (msg.role === "user") {
      const text = extractText(msg.content).trim();
      if (text) lines.push(`[User]\n${text}`);
    } else if (msg.role === "assistant") {
      const text = extractText(msg.content).trim();
      if (text) lines.push(`[Assistant]\n${text}`);
    }
  }
  if (!lines.length) return "";
  return `# Forked parent context\n${lines.join("\n\n")}\n\n---\n`;
}

function loadCustomAgents(cwd: string): Map<string, AgentDef> {
  const out = new Map<string, AgentDef>();
  for (const dir of [join(getAgentDir(), "agents"), join(cwd, ".pi", "agents")]) {
    if (!existsSync(dir)) continue;
    for (const file of readdirSync(dir).filter((f) => f.endsWith(".md"))) {
      const raw = readFileSync(join(dir, file), "utf8");
      const { frontmatter, body } = parseFrontmatter(raw);
      const name = String(frontmatter.name ?? basename(file, ".md"));
      const toolsRaw = frontmatter.tools;
      const tools = Array.isArray(toolsRaw)
        ? toolsRaw.map(String)
        : typeof toolsRaw === "string"
          ? toolsRaw.split(",").map((s) => s.trim()).filter(Boolean)
          : undefined;
      out.set(name, {
        name,
        description: String(frontmatter.description ?? name),
        tools,
        model: frontmatter.model ? String(frontmatter.model) : undefined,
        thinking: frontmatter.thinking ? String(frontmatter.thinking) : undefined,
        systemPrompt: body.trim(),
      });
    }
  }
  return out;
}

function getAgentDef(cwd: string, requested?: string): AgentDef {
  const all = new Map(DEFAULT_AGENTS);
  for (const [name, def] of loadCustomAgents(cwd)) all.set(name, def);
  const key = requested ?? "general-purpose";
  if (all.has(key)) return all.get(key)!;
  const found = [...all.values()].find((def) => def.name.toLowerCase() === key.toLowerCase());
  if (found) return found;
  return { ...DEFAULT_AGENTS.get("general-purpose")!, name: key, description: key };
}

function listAgentDefs(cwd: string): AgentDef[] {
  const all = new Map(DEFAULT_AGENTS);
  for (const [name, def] of loadCustomAgents(cwd)) all.set(name, def);
  return [...all.values()].sort((a, b) => a.name.localeCompare(b.name));
}

function resolveModel(ctx: ExtensionContext, input?: string, fallback?: any): any | undefined {
  const wanted = input?.trim();
  if (!wanted) return fallback ?? ctx.model;
  const registry: any = ctx.modelRegistry;
  const slash = wanted.indexOf("/");
  if (slash !== -1) {
    const provider = wanted.slice(0, slash);
    const id = wanted.slice(slash + 1);
    const exact = registry.find?.(provider, id);
    if (exact) return exact;
  }
  const available = registry.getAvailable?.() ?? registry.getAll?.() ?? [];
  const lowered = wanted.toLowerCase();
  return available.find((m: any) => `${m.provider}/${m.id}`.toLowerCase() === lowered)
    ?? available.find((m: any) => m.id?.toLowerCase?.() === lowered)
    ?? available.find((m: any) => `${m.provider}/${m.id}`.toLowerCase().includes(lowered))
    ?? fallback
    ?? ctx.model;
}

export default function codexSubagents(pi: ExtensionAPI) {
  const agents = new Map<string, AgentRecord>();
  const queue: string[] = [];
  let running = 0;
  let activityVersion = 0;
  const waiters: Array<() => void> = [];
  let currentCtx: ExtensionContext | undefined;
  let uiCtx: any | undefined;
  let widgetTui: any | undefined;
  let widgetRegistered = false;
  let widgetTimer: ReturnType<typeof setInterval> | undefined;
  let widgetFrame = 0;

  function visibleWidgetAgents() {
    const now = Date.now();
    return [...agents.values()]
      .filter((r) => r.status === "queued" || r.status === "running" || (r.completedAt && now - r.completedAt < LIVE_WIDGET_FINISHED_LINGER_MS))
      .sort((a, b) => (a.startedAt ?? a.createdAt) - (b.startedAt ?? b.createdAt));
  }

  function renderWidgetLine(record: AgentRecord, theme: any): string[] {
    const status = record.status;
    const icon = status === "running" ? theme.fg("accent", LIVE_SPINNER[widgetFrame % LIVE_SPINNER.length]) : statusIcon(status, theme);
    const name = theme.bold(record.path);
    const meta: string[] = [];
    if (record.type) meta.push(record.type);
    if (record.turns > 0) meta.push(`↻${record.turns}`);
    if (record.toolUses > 0) meta.push(`${record.toolUses} tool use${record.toolUses === 1 ? "" : "s"}`);
    const elapsed = age(record.startedAt ?? record.createdAt, record.completedAt ?? Date.now());
    if (elapsed) meta.push(elapsed);
    const lines = [`${icon} ${name} ${theme.fg(status === "errored" ? "error" : status === "running" ? "accent" : "dim", statusLabel(status))}${meta.length ? ` ${theme.fg("dim", meta.join(" · "))}` : ""}`];
    const preview = record.error ? record.error : record.result;
    if (preview) lines.push(`  ${theme.fg(record.error ? "error" : "dim", `⎿  ${oneLine(preview, 90)}`)}`);
    else if (status === "queued" || status === "running") lines.push(`  ${theme.fg("dim", `⎿  ${status === "queued" ? "waiting…" : "thinking…"}`)}`);
    return lines;
  }

  function ensureWidgetTimer() {
    if (widgetTimer) return;
    widgetTimer = setInterval(() => {
      widgetFrame++;
      updateLiveWidget();
    }, LIVE_WIDGET_TICK_MS);
  }

  function stopWidgetTimer() {
    if (!widgetTimer) return;
    clearInterval(widgetTimer);
    widgetTimer = undefined;
  }

  function captureUi(ctx?: ExtensionContext) {
    const next = (ctx as any)?.ui;
    if (!next) return;
    if (next !== uiCtx) {
      uiCtx = next;
      widgetRegistered = false;
      widgetTui = undefined;
    }
    updateLiveWidget();
  }

  function updateLiveWidget() {
    if (!uiCtx?.setWidget) return;
    const visible = visibleWidgetAgents();
    if (!visible.length) {
      if (widgetRegistered) uiCtx.setWidget(LIVE_WIDGET_KEY, undefined);
      widgetRegistered = false;
      widgetTui = undefined;
      stopWidgetTimer();
      return;
    }
    ensureWidgetTimer();
    if (!widgetRegistered) {
      uiCtx.setWidget(LIVE_WIDGET_KEY, (tui: any, theme: any) => {
        widgetTui = tui;
        return {
          render: () => {
            const rows = visibleWidgetAgents().flatMap((record) => renderWidgetLine(record, theme));
            return rows.length ? rows : [];
          },
          invalidate: () => {
            widgetRegistered = false;
            widgetTui = undefined;
          },
          dispose: () => {
            widgetRegistered = false;
            widgetTui = undefined;
          },
        };
      }, { placement: "aboveEditor" });
      widgetRegistered = true;
    } else {
      widgetTui?.requestRender?.();
    }
  }

  function bumpActivity() {
    activityVersion++;
    while (waiters.length) waiters.shift()?.();
    updateLiveWidget();
  }

  function findRecord(target: string): AgentRecord | undefined {
    if (agents.has(target)) return agents.get(target);
    if (target === "/root") return undefined;
    const normalized = target.startsWith("/root") ? target : `/root/${target.replace(/^\/+/, "")}`;
    return [...agents.values()].find((r) => r.path === normalized || r.taskName === target);
  }

  function startQueued() {
    while (running < Math.max(1, MAX_CONCURRENT - 1) && queue.length) {
      const id = queue.shift()!;
      const record = agents.get(id);
      if (!record || record.status !== "queued" || !currentCtx) continue;
      void runRecord(record, currentCtx);
    }
  }

  async function createSessionForRecord(record: AgentRecord, ctx: ExtensionContext, def: AgentDef, modelOverride?: string, thinking?: string) {
    const parentSystemPrompt = ctx.getSystemPrompt?.() ?? "";
    const systemPrompt = `${parentSystemPrompt}\n\n# Subagent identity\nYou are ${record.path}, a Codex-style Pi subagent.\nParent agent: ${record.parentPath}.\nWhen you finish, your final answer is delivered back to your parent.\n\n# Delegated role\n${def.systemPrompt}`;

    const loader = new DefaultResourceLoader({
      cwd: ctx.cwd,
      agentDir: getAgentDir(),
      noPromptTemplates: true,
      noThemes: true,
      noContextFiles: true,
      systemPromptOverride: () => systemPrompt,
      appendSystemPromptOverride: () => [],
    });
    await loader.reload();

    const settingsManager = SettingsManager.create(ctx.cwd, getAgentDir());
    const model = resolveModel(ctx, modelOverride ?? def.model, ctx.model);
    const opts: any = {
      cwd: ctx.cwd,
      agentDir: getAgentDir(),
      sessionManager: SessionManager.inMemory(ctx.cwd),
      settingsManager,
      modelRegistry: ctx.modelRegistry,
      model,
      resourceLoader: loader,
    };
    if (def.tools?.length) opts.tools = def.tools;
    if (thinking ?? def.thinking) opts.thinkingLevel = thinking ?? def.thinking;

    const { session } = await createAgentSession(opts);
    session.setSessionName?.(record.path);
    await session.bindExtensions?.({ onError: () => {} });
    record.session = session;

    session.subscribe((event: any) => {
      if (event.type === "tool_execution_start") {
        record.toolUses++;
        updateLiveWidget();
      }
      if (event.type === "turn_end") {
        record.turns++;
        updateLiveWidget();
      }
      if (event.type === "message_update") updateLiveWidget();
    });
    return session;
  }

  async function runRecord(record: AgentRecord, ctx: ExtensionContext, followup?: string) {
    const def = getAgentDef(ctx.cwd, record.type);
    record.status = "running";
    record.startedAt = Date.now();
    running++;
    bumpActivity();

    try {
      const session = record.session ?? await createSessionForRecord(record, ctx, def, record.modelOverride, record.thinkingOverride);
      const collector = collectResponseText(session);
      const queued = record.pendingMessages.splice(0);
      const basePrompt = followup && record.result
        ? `Previous result from this agent:\n${record.result}\n\nNew follow-up task:\n${followup}`
        : followup ?? record.prompt;
      const prompt = [basePrompt, ...queued.map((m) => `Message from parent:\n${m}`)].join("\n\n");
      const abort = () => session.abort?.();
      record.abortController.signal.addEventListener("abort", abort, { once: true });
      try {
        await session.prompt(prompt);
      } finally {
        record.abortController.signal.removeEventListener("abort", abort);
        collector.unsubscribe();
      }
      record.result = normalizeFinalAnswer(collector.getText() || lastAssistantText(session));
      record.status = "completed";
      record.completedAt = Date.now();

      const payload = truncate(record.result, NOTIFICATION_PREVIEW_CHARS);
      const note = `Message Type: FINAL_ANSWER\nTask name: ${record.parentPath}\nSender: ${record.path}\nPayload:\n${payload}`;
      pi.sendMessage?.({
        customType: SUBAGENT_NOTIFICATION_TYPE,
        content: note,
        display: true,
        details: {
          sender: record.path,
          recipient: record.parentPath,
          status: record.status,
          payload,
          turns: record.turns,
          tool_uses: record.toolUses,
          durationMs: record.completedAt && record.startedAt ? record.completedAt - record.startedAt : undefined,
        },
      }, { deliverAs: "followUp", triggerTurn: true });
    } catch (err: any) {
      record.error = err?.message ?? String(err);
      record.status = record.abortController.signal.aborted ? "interrupted" : "errored";
      record.completedAt = Date.now();
      const payload = `Agent failed: ${record.error}`;
      pi.sendMessage?.({
        customType: SUBAGENT_NOTIFICATION_TYPE,
        content: `Message Type: FINAL_ANSWER\nTask name: ${record.parentPath}\nSender: ${record.path}\nPayload:\n${payload}`,
        display: true,
        details: {
          sender: record.path,
          recipient: record.parentPath,
          status: record.status,
          payload,
          turns: record.turns,
          tool_uses: record.toolUses,
          durationMs: record.completedAt && record.startedAt ? record.completedAt - record.startedAt : undefined,
        },
      }, { deliverAs: "followUp", triggerTurn: true });
    } finally {
      // Completed child SDK sessions keep provider/resource handles alive. Dispose
      // them at terminal boundaries; a later followup_task will create a fresh
      // child session using the saved task/result context.
      try {
        record.session?.dispose?.();
      } catch {
        // ignore cleanup failures
      }
      record.session = undefined;
      running = Math.max(0, running - 1);
      bumpActivity();
      startQueued();
    }
  }

  function spawnRecord(ctx: ExtensionContext, params: any): AgentRecord {
    currentCtx = ctx;
    captureUi(ctx);
    const def = getAgentDef(ctx.cwd, params.agent_type ?? params.subagent_type);
    const taskName = params.task_name ?? params.description ?? def.name;
    const parentPath = "/root";
    const record: AgentRecord = {
      id: randomUUID().slice(0, 18),
      path: resolvePath(parentPath, taskName),
      taskName,
      parentPath,
      type: def.name,
      description: params.description ?? def.description,
      prompt: `${buildParentContext(ctx, params.fork_turns)}${params.message ?? params.prompt}`,
      modelOverride: params.model,
      thinkingOverride: params.thinking,
      status: "queued",
      createdAt: Date.now(),
      abortController: new AbortController(),
      pendingMessages: [],
      toolUses: 0,
      turns: 0,
    };
    agents.set(record.id, record);
    queue.push(record.id);
    startQueued();
    return record;
  }

  pi.on("session_start", async (_event, ctx) => {
    currentCtx = ctx;
    captureUi(ctx);
  });

  pi.on("before_agent_start", async (event) => ({
    systemPrompt: `${event.systemPrompt}\n\n# Codex-style subagents\nYou may collaborate with subagents using spawn_agent, send_message, followup_task, wait_agent, interrupt_agent, and list_agents. Use task names like \`research_auth\`. Subagents share the same filesystem and working directory. Their final answers are delivered back as follow-up messages in the form \`Message Type: FINAL_ANSWER\`.`,
  }));

  pi.registerMessageRenderer?.(SUBAGENT_NOTIFICATION_TYPE, (message, { expanded }, theme) => {
    const details = message.details ?? {};
    const sender = details.sender ?? "subagent";
    const recipient = details.recipient ?? "/root";
    const status = details.status ?? "completed";
    const payload = String(details.payload ?? message.content ?? "").trim();
    const isError = status === "errored" || status === "interrupted";
    const icon = isError ? theme.fg("error", "✗") : theme.fg("success", "✓");
    let text = `${icon} ${theme.bold(sender)} ${theme.fg(isError ? "error" : "dim", statusLabel(status))} ${theme.fg("dim", `→ ${recipient}`)}`;
    if (details.turns || details.tool_uses || details.durationMs) {
      const parts: string[] = [];
      if (details.turns) parts.push(`↻${details.turns}`);
      if (details.tool_uses) parts.push(`${details.tool_uses} tool use${details.tool_uses === 1 ? "" : "s"}`);
      if (details.durationMs) parts.push(age(Date.now() - details.durationMs, Date.now()) ?? `${details.durationMs}ms`);
      text += `\n  ${parts.map((p) => theme.fg("dim", p)).join(` ${theme.fg("dim", "·")} `)}`;
    }
    if (payload) {
      if (expanded) {
        for (const l of truncate(payload, 4000).split("\n").slice(0, 40)) text += `\n${theme.fg(isError ? "error" : "dim", `  ${l}`)}`;
      } else {
        text += `\n  ${theme.fg(isError ? "error" : "dim", `⎿  ${oneLine(payload, 100)}`)}`;
      }
    }
    if (!expanded && payload.length > 100) text += `\n  ${theme.fg("muted", "Ctrl+O to expand")}`;
    return new Text(text, 0, 0);
  });

  pi.registerTool(defineTool({
    name: "spawn_agent",
    label: "Spawn agent",
    description: "Spawn a Codex-style Pi subagent as a child task. Returns immediately by default; use wait_agent/list_agents or read follow-up final-answer messages for results.",
    parameters: Type.Object({
      task_name: Type.String({ description: "Lowercase-ish task name, e.g. research_auth or review_diff." }),
      message: Type.String({ description: "Task for the subagent." }),
      agent_type: Type.Optional(Type.String({ description: "Agent type/name. Defaults: general-purpose, Explore, Plan. Custom .pi/agents/*.md are supported." })),
      model: Type.Optional(Type.String({ description: "Optional model override, e.g. provider/model." })),
      thinking: Type.Optional(Type.String({ description: "Optional thinking level." })),
      fork_turns: Type.Optional(Type.String({ description: "Parent context to include: all, none, or a positive integer. Default all." })),
      run_in_background: Type.Optional(Type.Boolean({ description: "If false, wait for completion and return the final answer inline. Default true." })),
    }),
    renderCall(args, theme) {
      const path = `/root/${args.task_name ?? "agent"}`;
      const mode = args.run_in_background === false ? "foreground" : "background";
      const type = args.agent_type ?? "general-purpose";
      let text = `${theme.fg("toolTitle", theme.bold("spawn_agent "))}${theme.fg("accent", path)} ${theme.fg("muted", `[${type} · ${mode}]`)}`;
      const preview = extractTaskPreview(args);
      if (preview) text += `\n  ${theme.fg("dim", preview)}`;
      return new Text(text, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const records = extractRecordsFromResult(result);
      if (records.length) return renderRecords(records, theme, expanded);
      return renderPlainResult(result, theme);
    },
    async execute(_id, params, signal, _onUpdate, ctx) {
      const record = spawnRecord(ctx, params);
      if (signal) signal.addEventListener("abort", () => record.abortController.abort(), { once: true });
      const background = params.run_in_background !== false;
      if (background) {
        return textResult(JSON.stringify({ task_name: record.path, agent_id: record.id, status: record.status }), { record: summarizeRecord(record) });
      }
      while (!["completed", "errored", "interrupted"].includes(record.status)) {
        await new Promise((resolve) => setTimeout(resolve, 200));
      }
      return textResult(record.result ?? record.error ?? "", { record: summarizeRecord(record) });
    },
  }));

  pi.registerTool(defineTool({
    name: "followup_task",
    label: "Follow-up task",
    description: "Send a follow-up task to an existing non-root subagent and trigger a new turn if it is idle.",
    parameters: Type.Object({ target: Type.String(), message: Type.String() }),
    renderCall(args, theme) {
      let text = `${theme.fg("toolTitle", theme.bold("followup_task "))}${theme.fg("accent", extractTarget(args))}`;
      const preview = extractTaskPreview(args);
      if (preview) text += `\n  ${theme.fg("dim", preview)}`;
      return new Text(text, 0, 0);
    },
    renderResult(result, _options, theme) {
      return renderPlainResult(result, theme);
    },
    async execute(_id, params, _signal, _onUpdate, ctx) {
      captureUi(ctx);
      const record = findRecord(params.target);
      if (!record) return textResult(`No such agent: ${params.target}`);
      if (record.status === "running" || record.status === "queued") {
        record.pendingMessages.push(params.message);
        if (record.session?.followUp) await record.session.followUp(params.message);
      } else {
        record.abortController = new AbortController();
        void runRecord(record, ctx, params.message);
      }
      bumpActivity();
      return textResult("");
    },
  }));

  pi.registerTool(defineTool({
    name: "send_message",
    label: "Send message",
    description: "Send a message to an existing subagent. Running agents receive it as steering; idle agents keep it for the next followup_task.",
    parameters: Type.Object({ target: Type.String(), message: Type.String() }),
    renderCall(args, theme) {
      let text = `${theme.fg("toolTitle", theme.bold("send_message "))}${theme.fg("accent", extractTarget(args))}`;
      const preview = extractTaskPreview(args);
      if (preview) text += `\n  ${theme.fg("dim", preview)}`;
      return new Text(text, 0, 0);
    },
    renderResult(result, _options, theme) {
      return renderPlainResult(result, theme);
    },
    async execute(_id, params, _signal, _onUpdate, ctx) {
      captureUi(ctx);
      const record = findRecord(params.target);
      if (!record) return textResult(`No such agent: ${params.target}`);
      if (record.status === "running" && record.session?.steer) await record.session.steer(params.message);
      else record.pendingMessages.push(params.message);
      bumpActivity();
      return textResult("");
    },
  }));

  pi.registerTool(defineTool({
    name: "wait_agent",
    label: "Wait agent",
    description: "Wait for subagent activity or completion. Returns summaries; final answers also arrive as follow-up messages.",
    parameters: Type.Object({ timeout_ms: Type.Optional(Type.Number({ description: "Timeout in milliseconds." })) }),
    renderCall(args, theme) {
      const ms = args.timeout_ms ?? DEFAULT_WAIT_MS;
      return new Text(`${theme.fg("toolTitle", theme.bold("wait_agent "))}${theme.fg("muted", `${ms}ms`)}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const timedOut = (() => { try { return JSON.parse(firstText(result))?.timed_out; } catch { return false; } })();
      const records = extractRecordsFromResult(result);
      const head = timedOut ? theme.fg("warning", "Wait timed out") : theme.fg("success", "Wait completed");
      if (!records.length) return new Text(head, 0, 0);
      const body = records.map((record) => recordLine(record, theme, expanded)).join("\n");
      return new Text(`${head}\n${body}`, 0, 0);
    },
    async execute(_id, params, _signal, _onUpdate, ctx) {
      captureUi(ctx);
      const seen = activityVersion;
      const timeoutMs = Math.max(0, Math.min(3_600_000, params.timeout_ms ?? DEFAULT_WAIT_MS));
      const alreadyTerminal = [...agents.values()].some((r) => ["completed", "errored", "interrupted"].includes(r.status));
      if (!alreadyTerminal && activityVersion === seen) {
        await new Promise<void>((resolve) => {
          const timer = setTimeout(resolve, timeoutMs);
          waiters.push(() => { clearTimeout(timer); resolve(); });
        });
      }
      const timedOut = !alreadyTerminal && activityVersion === seen;
      const updates = [...agents.values()].map((r) => ({
        task_name: r.path,
        agent_id: r.id,
        type: r.type,
        status: r.status,
        turns: r.turns,
        tool_uses: r.toolUses,
        createdAt: r.createdAt,
        startedAt: r.startedAt,
        completedAt: r.completedAt,
        result_preview: r.result ? truncate(r.result) : undefined,
        error: r.error,
      }));
      return textResult(JSON.stringify({ message: timedOut ? "Wait timed out." : "Wait completed.", timed_out: timedOut, updates }, null, 2), { updates });
    },
  }));

  pi.registerTool(defineTool({
    name: "interrupt_agent",
    label: "Interrupt agent",
    description: "Abort a running subagent.",
    parameters: Type.Object({ target: Type.String() }),
    renderCall(args, theme) {
      return new Text(`${theme.fg("toolTitle", theme.bold("interrupt_agent "))}${theme.fg("accent", extractTarget(args))}`, 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const records = extractRecordsFromResult(result);
      if (records.length) return renderRecords(records, theme, expanded);
      return renderPlainResult(result, theme);
    },
    async execute(_id, params, _signal, _onUpdate, ctx) {
      captureUi(ctx);
      const record = findRecord(params.target);
      if (!record) return textResult(`No such agent: ${params.target}`);
      record.abortController.abort();
      await record.session?.abort?.();
      record.status = "interrupted";
      bumpActivity();
      return textResult(JSON.stringify({ task_name: record.path, status: record.status }), { record: summarizeRecord(record) });
    },
  }));

  pi.registerTool(defineTool({
    name: "list_agents",
    label: "List agents",
    description: "List known subagents and available agent types.",
    parameters: Type.Object({}),
    renderCall(_args, theme) {
      return new Text(theme.fg("toolTitle", theme.bold("list_agents")), 0, 0);
    },
    renderResult(result, { expanded }, theme) {
      const records = extractRecordsFromResult(result);
      const types = result.details?.available_agent_types ?? [];
      let text = records.length
        ? records.map((record) => recordLine(record, theme, expanded)).join("\n")
        : theme.fg("muted", "No subagents.");
      if (expanded && types.length) {
        text += `\n\n${theme.fg("muted", "Available types:")}`;
        for (const type of types) text += `\n  ${theme.fg("accent", type.name)} ${theme.fg("dim", oneLine(type.description, 90))}`;
      } else if (types.length) {
        text += `\n${theme.fg("dim", `${types.length} agent types available · Ctrl+O to expand`)}`;
      }
      return new Text(text, 0, 0);
    },
    async execute(_id, _params, _signal, _onUpdate, ctx) {
      captureUi(ctx);
      const records = [...agents.values()].map((r) => ({
        task_name: r.path,
        agent_id: r.id,
        type: r.type,
        status: r.status,
        turns: r.turns,
        tool_uses: r.toolUses,
        createdAt: r.createdAt,
        startedAt: r.startedAt,
        completedAt: r.completedAt,
        result_preview: r.result ? truncate(r.result) : undefined,
        error: r.error,
      }));
      const available_agent_types = listAgentDefs(ctx.cwd).map(({ name, description }) => ({ name, description }));
      return textResult(JSON.stringify({ agents: records, available_agent_types }, null, 2), { records, available_agent_types });
    },
  }));

  pi.registerCommand("agents", {
    description: "List Codex-style Pi subagents",
    handler: async (_args, ctx) => {
      const active = [...agents.values()].map((r) => `${r.status.padEnd(11)} ${r.path} ${r.result ? "✓" : ""}`).join("\n") || "No subagents yet.";
      const types = listAgentDefs(ctx.cwd).map((a) => `- ${a.name}: ${a.description}`).join("\n");
      ctx.ui.notify(`Subagents\n${active}\n\nTypes\n${types}`, "info");
    },
  });
}
