// Adds Shift+Up / Shift+Down shortcuts for changing Pi thinking level.
// @ts-nocheck

const levels = ["off", "minimal", "low", "medium", "high", "xhigh"];

function moveThinking(pi: any, ctx: any, delta: number) {
  const current = pi.getThinkingLevel?.() ?? "off";
  const index = Math.max(0, levels.indexOf(current));
  const next = levels[Math.max(0, Math.min(levels.length - 1, index + delta))];

  pi.setThinkingLevel(next);
  ctx?.ui?.notify?.(`Thinking: ${next}`, "info");
}

export default function (pi) {
  pi.registerShortcut("shift+up", {
    description: "Increase thinking level",
    handler: async (ctx) => moveThinking(pi, ctx, 1),
  });

  pi.registerShortcut("shift+down", {
    description: "Decrease thinking level",
    handler: async (ctx) => moveThinking(pi, ctx, -1),
  });
}
