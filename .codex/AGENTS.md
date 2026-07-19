# Global Codex Instructions

- Answer simply. Usually give one direct answer; one answer is more than enough unless the user asks for options.
- When making Playwright proof videos, prefer MP4 output. If Playwright only emits WebM, convert the final proof video to MP4 before handing it off.
- Never commit or push generated proof videos, screenshots, or test artifacts to product repositories. Keep them local/ignored; attach them manually to GitHub when needed.
- Herdr rule: keep `Alt-o` as a fast worktree picker that includes existing worktrees, local branches, and remote branches; do not replace it with Herdr's native `open_worktree` action, which omits remote branches.
- Linear scope rule: before any Linear mutation, identify the repository in scope and read its applicable repo-local `AGENTS.md`. Create or update a Linear issue only when those repo-local instructions explicitly authorize or require it. If no repository is in scope, or its instructions do not authorize Linear, do not mutate Linear; a global skill or generic RFC workflow is never sufficient authorization.
- Keyboard layout source-of-truth rule: keep shared ergonomic intent in `/Users/boss/.dotfiles/keyboard-layout`; QMK, ZMK, and Karabiner are target adapters. Keep per-device timing, physical input mapping, scope, and wiring compensation in device profiles rather than duplicating shared behavior across targets.
- Corne thumb rule: the canonical middle left-thumb position is Backspace/Delete when tapped and System when held; the canonical inner left-thumb position is Enter when tapped and Numbers when held. Compensate for the other Corne's reversed physical inputs only in its device profile; never change the canonical finger roles.
- Keyboard flash rule: never flash a keyboard without announcing it immediately beforehand and receiving explicit confirmation, because the user may be working in another worktree.
