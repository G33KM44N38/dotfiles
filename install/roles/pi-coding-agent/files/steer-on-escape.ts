// While Pi is working, Escape sends the editor text as a steering message immediately.
// If the editor is empty, Escape keeps Pi's normal interrupt behavior.
// Reload Pi with /reload after editing this file.

import { CustomEditor, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { EditorOptions, EditorTheme, TUI } from "@earendil-works/pi-tui";
import type { KeybindingsManager } from "@earendil-works/pi-coding-agent";

class SteerOnEscapeEditor extends CustomEditor {
  constructor(
    tui: TUI,
    theme: EditorTheme,
    keybindings: KeybindingsManager,
    private readonly ctx: ExtensionContext,
    private readonly pi: ExtensionAPI,
    options?: EditorOptions,
  ) {
    super(tui, theme, keybindings, options);

    this.onEscape = () => {
      const text = this.getText().trim();

      if (!this.ctx.isIdle() && text) {
        this.setText("");
        this.addToHistory?.(text);

        // Queue the steering message, then abort the current generation so Pi
        // can process it right away instead of waiting for the current turn.
        this.pi.sendUserMessage(text, { deliverAs: "steer" });
        this.ctx.abort();
        return;
      }

      // No draft to send: preserve Pi's normal Escape behavior.
      this.actionHandlers.get("app.interrupt")?.();
    };
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setEditorComponent((tui, theme, keybindings) => new SteerOnEscapeEditor(tui, theme, keybindings, ctx, pi));
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    ctx.ui.setEditorComponent(undefined);
  });
}
