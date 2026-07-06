// Colorized Pi footer + current/last agent run duration.
// Reload Pi with /reload after editing this file.

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { homedir } from "node:os";

function shortCwd(cwd: string): string {
  const home = homedir();
  return cwd.startsWith(home) ? `~${cwd.slice(home.length) || ""}` : cwd;
}

function fmt(n: number): string {
  if (!Number.isFinite(n)) return "0";
  if (Math.abs(n) < 1000) return `${Math.round(n)}`;
  return `${(n / 1000).toFixed(1)}k`;
}

function money(n: number): string {
  if (!Number.isFinite(n)) return "$0.000";
  return `$${n.toFixed(3)}`;
}

function elapsed(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const seconds = totalSeconds % 60;
  const minutes = Math.floor(totalSeconds / 60) % 60;
  const hours = Math.floor(totalSeconds / 3600);

  if (hours > 0) return `${hours}h${minutes.toString().padStart(2, "0")}`;
  if (minutes > 0) return `${minutes}m${seconds.toString().padStart(2, "0")}`;
  return `${seconds}s`;
}

function padBetween(left: string, right: string, width: number): string {
  const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
  return truncateToWidth(left + pad + right, width, "");
}

function progressBar(percent: number, width: number, theme: any): string {
  const clamped = Math.max(0, Math.min(1, Number.isFinite(percent) ? percent : 0));
  const filled = Math.round(clamped * width);
  return theme.fg("accent", "━".repeat(filled)) + theme.fg("dim", "━".repeat(Math.max(0, width - filled)));
}

function footerUsage(ctx: ExtensionContext): {
  input: number;
  output: number;
  reasoning: number;
  cacheRead: number;
  cost: number;
} {
  const totals = { input: 0, output: 0, reasoning: 0, cacheRead: 0, cost: 0 };

  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "assistant") continue;
    const usage = (entry.message as any).usage;
    if (!usage) continue;

    totals.input += usage.input ?? 0;
    totals.output += usage.output ?? 0;
    totals.reasoning += usage.reasoning ?? 0;
    totals.cacheRead += usage.cacheRead ?? 0;
    totals.cost += usage.cost?.total ?? 0;
  }

  return totals;
}

export default function (pi: ExtensionAPI) {
  let workingTimer: ReturnType<typeof setInterval> | undefined;
  let agentStartedAt: number | undefined;
  let lastWorkingMs: number | undefined;
  let requestFooterRender: (() => void) | undefined;

  function getWorkDuration(): { ms: number; active: boolean } | undefined {
    if (agentStartedAt !== undefined) return { ms: Date.now() - agentStartedAt, active: true };
    if (lastWorkingMs !== undefined) return { ms: lastWorkingMs, active: false };
    return undefined;
  }

  function renderFooterSoon(): void {
    requestFooterRender?.();
  }

  function stopWorkingTimer(): void {
    if (workingTimer) clearInterval(workingTimer);
    workingTimer = undefined;
  }

  function startWorkingTimer(): void {
    stopWorkingTimer();
    workingTimer = setInterval(renderFooterSoon, 1000);
    workingTimer.unref?.();
  }

  function installFooter(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      requestFooterRender = () => tui.requestRender();
      const unsub = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose: unsub,
        invalidate() {},
        render(width: number): string[] {
          const branch = footerData.getGitBranch?.();
          const statusMap = footerData.getExtensionStatuses?.();
          const statuses = statusMap ? (Array.from(statusMap.values()) as string[]) : [];
          const linearStatus = statuses.find((status) => status.includes("Linear"));

          const usage = footerUsage(ctx);
          const context = ctx.getContextUsage?.();
          const contextWindow = (ctx.model as any)?.contextWindow;
          const contextPercent = context && contextWindow ? context.tokens / contextWindow : 0;
          const contextLabel = context && contextWindow ? `${(contextPercent * 100).toFixed(1)}% used` : `${fmt(usage.input + usage.output)} tokens`;
          const cacheText = usage.cacheRead > 0 ? ` CH${((usage.cacheRead / Math.max(1, usage.cacheRead + usage.input)) * 100).toFixed(1)}%` : "";

          const workDuration = getWorkDuration();
          const workText = workDuration
            ? theme.fg(workDuration.active ? "warning" : "success", `Work for ${elapsed(workDuration.ms)}`)
            : theme.fg("dim", "Idle");

          const branchText = branch ? ` (${branch})` : "";
          const where = `${shortCwd(ctx.cwd)}${branchText}`;
          const location = theme.fg("accent", theme.bold(where));
          const usageText =
            theme.fg("success", `↑${fmt(usage.input)}`) +
            " " +
            theme.fg("accent", `↓${fmt(usage.output)}`) +
            (usage.reasoning ? " " + theme.fg("warning", `R${fmt(usage.reasoning)}`) : "") +
            theme.fg("dim", cacheText) +
            " " +
            theme.fg("success", money(usage.cost));

          const model = ctx.model as any;
          const provider = model?.provider ?? "no-provider";
          const modelId = model?.id ?? "no-model";
          const thinking = pi.getThinkingLevel?.() ?? "";
          const modelText =
            theme.fg("dim", "Model: ") +
            theme.fg("accent", provider) +
            theme.fg("dim", "/") +
            theme.fg("text", modelId) +
            (thinking ? theme.fg("dim", " • ") + theme.fg("warning", thinking) : "");

          const sep = theme.fg("dim", " │ ");
          const barWidth = Math.max(8, Math.min(28, Math.floor(width * 0.24)));
          const contextSegment =
            theme.fg("dim", "Context ") +
            progressBar(contextPercent, barWidth, theme) +
            theme.fg("dim", ` ${contextLabel}`);
          const left = [
            workText,
            location,
            contextSegment,
            usageText,
            linearStatus,
          ]
            .filter(Boolean)
            .join(sep);

          const right = modelText;
          const rightWidth = visibleWidth(right);
          const availableLeft = Math.max(0, width - rightWidth - 1);
          const safeLeft = truncateToWidth(left, availableLeft, "");
          const gap = " ".repeat(Math.max(1, width - visibleWidth(safeLeft) - rightWidth));
          const line = safeLeft + gap + right;

          const border = theme.fg("borderMuted", "─".repeat(Math.max(0, width)));
          return [border, truncateToWidth(line, width, ""), border];
        },
      };
    });
  }

  pi.on("session_start", async (_event, ctx) => {
    lastWorkingMs = undefined;
    installFooter(ctx);
  });

  pi.on("agent_start", async () => {
    agentStartedAt = Date.now();
    lastWorkingMs = undefined;
    startWorkingTimer();
    renderFooterSoon();
  });

  pi.on("agent_end", async () => {
    if (agentStartedAt !== undefined) {
      lastWorkingMs = Date.now() - agentStartedAt;
    }
    agentStartedAt = undefined;
    stopWorkingTimer();
    renderFooterSoon();
  });

  pi.on("model_select", async (_event, ctx) => installFooter(ctx));
  pi.on("thinking_level_select", async (_event, ctx) => installFooter(ctx));

  pi.on("session_shutdown", async (_event, ctx) => {
    stopWorkingTimer();
    agentStartedAt = undefined;
    lastWorkingMs = undefined;
    requestFooterRender = undefined;
    ctx.ui.setFooter(undefined);
  });
}
