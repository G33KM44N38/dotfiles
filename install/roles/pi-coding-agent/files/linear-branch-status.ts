// Shows whether the current git branch looks linked to a Linear issue.
// Reload Pi with /reload after editing this file.

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { basename } from "node:path";

const STATUS_KEY = "linear-branch";
const POLL_MS = Number.parseInt(process.env.PI_LINEAR_STATUS_POLL_MS ?? "10000", 10);
const ISSUE_CACHE_MS = Number.parseInt(process.env.PI_LINEAR_STATUS_CACHE_MS ?? "300000", 10);
const MAX_TITLE = 42;
const DEFAULT_LINEAR_PROJECTS = ["babacoiffure", "dorali"];

type GitState =
  | { kind: "none" }
  | { kind: "branch"; branch: string; identifier?: string };

type IssueLookup =
  | { kind: "unverified" }
  | { kind: "found"; title?: string; url?: string }
  | { kind: "missing" }
  | { kind: "error" };

type CacheEntry = {
  at: number;
  result: IssueLookup;
};

const issueCache = new Map<string, CacheEntry>();

function normalizePollMs(value: number): number {
  if (!Number.isFinite(value) || value < 1000) return 10000;
  return value;
}

function configuredTeams(): Set<string> | undefined {
  const raw = process.env.PI_LINEAR_TEAMS;
  if (!raw) return undefined;

  const teams = raw
    .split(",")
    .map((part) => part.trim().toUpperCase())
    .filter(Boolean);

  return teams.length > 0 ? new Set(teams) : undefined;
}

const allowedTeams = configuredTeams();

function configuredLinearProjects(): string[] {
  const raw = process.env.PI_LINEAR_PROJECTS;
  const values = raw ? raw.split(",") : DEFAULT_LINEAR_PROJECTS;
  return values.map((value) => value.trim().toLowerCase()).filter(Boolean);
}

const linearProjects = configuredLinearProjects();

function extractLinearIdentifier(branch: string): string | undefined {
  // Supports common branch names:
  // - feat-baba-1020-posthog
  // - fix/BABA-1020-campaign-attribution
  // - chore_BABA_1020_cleanup
  const pattern = /(^|[^A-Za-z0-9])([A-Za-z][A-Za-z0-9]{1,9})[-_](\d{1,8})(?=$|[^A-Za-z0-9])/g;

  for (const match of branch.matchAll(pattern)) {
    const team = match[2]?.toUpperCase();
    const number = match[3];
    if (!team || !number) continue;
    if (allowedTeams && !allowedTeams.has(team)) continue;
    return `${team}-${number}`;
  }

  return undefined;
}

function truncate(value: string, max = MAX_TITLE): string {
  if (value.length <= max) return value;
  return `${value.slice(0, Math.max(0, max - 1))}…`;
}

function shortBranch(branch: string): string {
  return truncate(branch, 28);
}

function linearToken(): string | undefined {
  return process.env.LINEAR_API_KEY || process.env.LINEAR_API_TOKEN;
}

async function withTimeout<T>(ms: number, fn: (signal: AbortSignal) => Promise<T>): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  timer.unref?.();

  try {
    return await fn(controller.signal);
  } finally {
    clearTimeout(timer);
  }
}

async function isLinearProject(pi: ExtensionAPI, cwd: string): Promise<boolean> {
  if (linearProjects.length === 0) return false;

  const rootResult = await pi.exec("git", ["-C", cwd, "rev-parse", "--show-toplevel"], {
    timeout: 1000,
  });
  if (rootResult.code !== 0) return false;

  const root = rootResult.stdout.trim();
  const remoteResult = await pi.exec("git", ["-C", cwd, "remote", "-v"], {
    timeout: 1000,
  });

  const haystack = `${root} ${basename(root)} ${remoteResult.stdout}`.toLowerCase();
  return linearProjects.some((project) => haystack.includes(project));
}

async function currentGitState(pi: ExtensionAPI, cwd: string): Promise<GitState> {
  const inside = await pi.exec("git", ["-C", cwd, "rev-parse", "--is-inside-work-tree"], {
    timeout: 1000,
  });

  if (inside.code !== 0 || inside.stdout.trim() !== "true") {
    return { kind: "none" };
  }

  const branchResult = await pi.exec("git", ["-C", cwd, "branch", "--show-current"], {
    timeout: 1000,
  });

  const branch = branchResult.stdout.trim();
  if (!branch) {
    const shaResult = await pi.exec("git", ["-C", cwd, "rev-parse", "--short", "HEAD"], {
      timeout: 1000,
    });
    const sha = shaResult.stdout.trim();
    return { kind: "branch", branch: sha ? `detached@${sha}` : "detached" };
  }

  return { kind: "branch", branch, identifier: extractLinearIdentifier(branch) };
}

async function lookupLinearIssue(identifier: string): Promise<IssueLookup> {
  const token = linearToken();
  if (!token) return { kind: "unverified" };

  const cached = issueCache.get(identifier);
  if (cached && Date.now() - cached.at < ISSUE_CACHE_MS) {
    return cached.result;
  }

  const result = await withTimeout(3000, async (signal) => {
    const response = await fetch("https://api.linear.app/graphql", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: token,
      },
      body: JSON.stringify({
        query: `query PiLinearBranchStatus($id: String!) {
          issue(id: $id) { identifier title url }
        }`,
        variables: { id: identifier },
      }),
      signal,
    });

    if (!response.ok) return { kind: "error" } as IssueLookup;

    const json = (await response.json()) as {
      data?: { issue?: { title?: string; url?: string } | null };
      errors?: unknown[];
    };

    if (json.data?.issue) {
      return {
        kind: "found",
        title: json.data.issue.title,
        url: json.data.issue.url,
      } as IssueLookup;
    }

    return json.errors ? ({ kind: "error" } as IssueLookup) : ({ kind: "missing" } as IssueLookup);
  }).catch(() => ({ kind: "error" }) as IssueLookup);

  issueCache.set(identifier, { at: Date.now(), result });
  return result;
}

function renderStatus(ctx: ExtensionContext, git: GitState, issue?: IssueLookup): void {
  const theme = ctx.ui.theme;
  const label = theme.fg("accent", "Linear");
  const separator = theme.fg("dim", ": ");

  if (git.kind === "none") {
    ctx.ui.setStatus(STATUS_KEY, undefined);
    return;
  }

  if (!git.identifier) {
    ctx.ui.setStatus(STATUS_KEY, undefined);
    return;
  }

  if (!issue || issue.kind === "unverified") {
    ctx.ui.setStatus(
      STATUS_KEY,
      theme.fg("accent", "◆ ") + label + separator + theme.fg("accent", git.identifier) + theme.fg("dim", " unverified"),
    );
    return;
  }

  if (issue.kind === "found") {
    const title = issue.title ? theme.fg("muted", ` ${truncate(issue.title)}`) : "";
    ctx.ui.setStatus(STATUS_KEY, theme.fg("success", "● ") + label + separator + theme.fg("success", git.identifier) + title);
    return;
  }

  if (issue.kind === "missing") {
    ctx.ui.setStatus(
      STATUS_KEY,
      theme.fg("warning", "● ") + label + separator + theme.fg("warning", `${git.identifier}?`) + theme.fg("dim", " not found"),
    );
    return;
  }

  ctx.ui.setStatus(
    STATUS_KEY,
    theme.fg("error", "● ") + label + separator + theme.fg("warning", git.identifier) + theme.fg("dim", " check failed"),
  );
}

export default function (pi: ExtensionAPI) {
  let timer: ReturnType<typeof setInterval> | undefined;
  let lastRenderedKey: string | undefined;

  async function refresh(ctx: ExtensionContext, force = false): Promise<void> {
    if (!ctx.hasUI) return;

    const git = await currentGitState(pi, ctx.cwd).catch(() => ({ kind: "none" }) as GitState);
    const linkedProject = git.kind === "branch" ? await isLinearProject(pi, ctx.cwd).catch(() => false) : false;
    const key = git.kind === "branch" ? `${git.branch}:${git.identifier ?? ""}:${linkedProject}` : git.kind;
    if (!force && key === lastRenderedKey) return;
    lastRenderedKey = key;

    if (!linkedProject || git.kind !== "branch" || !git.identifier) {
      ctx.ui.setStatus(STATUS_KEY, undefined);
      return;
    }

    const issue = await lookupLinearIssue(git.identifier);
    renderStatus(ctx, git, issue);
  }

  function stopPolling() {
    if (timer) clearInterval(timer);
    timer = undefined;
  }

  pi.on("session_start", async (_event, ctx) => {
    stopPolling();
    lastRenderedKey = undefined;
    await refresh(ctx, true);

    if (ctx.hasUI) {
      timer = setInterval(() => void refresh(ctx), normalizePollMs(POLL_MS));
      timer.unref?.();
    }
  });

  pi.on("agent_start", async (_event, ctx) => {
    await refresh(ctx, true);
  });

  pi.registerCommand("linear-branch", {
    description: "Refresh Linear issue status for the current git branch",
    handler: async (_args, ctx) => {
      await refresh(ctx, true);
      ctx.ui.notify("Linear branch status refreshed", "info");
    },
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    stopPolling();
    ctx.ui.setStatus(STATUS_KEY, undefined);
  });
}
