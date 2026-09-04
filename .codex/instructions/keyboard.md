# Keyboard

One job: preserve shared ergonomic intent and device-specific wiring.

## Source of truth

- Keep shared ergonomic intent in `/Users/boss/.dotfiles/keyboard-layout`.
- Treat QMK, ZMK, and Karabiner as target adapters.
- Keep device timing, physical input mapping, scope, and wiring compensation in device profiles.
- Do not copy shared behavior across targets.

## Corne thumb roles

- The canonical middle left-thumb position taps Backspace or Delete and holds System.
- The canonical inner left-thumb position taps Enter and holds Numbers.
- Compensate for reversed physical inputs only in the other Corne's device profile.
- Never change the canonical finger roles to compensate for device wiring.

## Flashing

- Announce the keyboard flash immediately before it can occur.
- Get explicit user confirmation before flashing.

The user can be working in another worktree during a flash.
