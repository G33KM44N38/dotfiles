// Ctrl+F toggles a lightweight "fast mode" by switching thinking off/on.
// @ts-nocheck

const FAST_LEVEL = "off";
const NORMAL_LEVEL = "low";

let previousNonFastLevel = NORMAL_LEVEL;

export default function (pi) {
  pi.registerShortcut("ctrl+f", {
    description: "Toggle fast mode",
    handler: async (ctx) => {
      const current = pi.getThinkingLevel?.() ?? NORMAL_LEVEL;

      if (current === FAST_LEVEL) {
        pi.setThinkingLevel(previousNonFastLevel || NORMAL_LEVEL);
        ctx?.ui?.notify?.(`Fast mode off · thinking: ${previousNonFastLevel || NORMAL_LEVEL}`, "info");
        return;
      }

      previousNonFastLevel = current;
      pi.setThinkingLevel(FAST_LEVEL);
      ctx?.ui?.notify?.("Fast mode on · thinking: off", "info");
    },
  });
}
