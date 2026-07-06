// Mirrors the Codex hook state updates for Pi so existing tmux/thread-picker
// status UI keeps working while sessions run under pi.
// @ts-nocheck

import { spawn } from "node:child_process";

const hook = "/Users/boss/.dotfiles/bin/codex-tmux-state-hook";

function sessionId(ctx: any): string | undefined {
  try {
    const id = ctx?.sessionManager?.getSessionId?.();
    return typeof id === "string" && id.length > 0 ? id : undefined;
  } catch {
    return undefined;
  }
}

function sessionFile(ctx: any): string | undefined {
  try {
    const file = ctx?.sessionManager?.getSessionFile?.();
    return typeof file === "string" && file.length > 0 ? file : undefined;
  } catch {
    return undefined;
  }
}

function runHook(event: string, ctx: any, extra: Record<string, unknown> = {}) {
  const payload = JSON.stringify({
    source: "pi",
    event,
    cwd: ctx?.cwd ?? process.cwd(),
    session_id: sessionId(ctx),
    session_file: sessionFile(ctx),
    ...extra,
  });

  const child = spawn(hook, ["--event", event], {
    stdio: ["pipe", "ignore", "ignore"],
    detached: false,
  });

  const timer = setTimeout(() => child.kill("SIGTERM"), 2000);
  timer.unref?.();
  child.on("close", () => clearTimeout(timer));
  child.on("error", () => clearTimeout(timer));
  child.stdin.end(payload);
}

export default function (pi) {
  pi.on("session_start", (event, ctx) => {
    runHook("SessionStart", ctx, { reason: event?.reason });
  });

  pi.on("before_agent_start", (event, ctx) => {
    runHook("UserPromptSubmit", ctx, { prompt: event?.prompt });
  });

  pi.on("tool_execution_end", (event, ctx) => {
    runHook("PostToolUse", ctx, {
      toolName: event?.toolName,
      isError: event?.isError,
    });
  });

  pi.on("agent_end", (_event, ctx) => {
    runHook("Stop", ctx);
  });

  pi.on("session_shutdown", (event, ctx) => {
    runHook("Stop", ctx, { reason: event?.reason });
  });
}
