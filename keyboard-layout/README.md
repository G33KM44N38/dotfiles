# Shared keyboard layout

This package is the neutral source of truth for the ergonomic behavior shared
by the wired QMK Corne, the wireless ZMK Corne, and the MacBook built-in
keyboard managed by Karabiner.

The canonical model describes what each finger position means. Device profiles
own physical input mapping, deliberate timing differences, hardware quirks,
and target capabilities. QMK, ZMK, and Karabiner syntax is generated from that
model.

## Ownership

| Concern | Owner |
| --- | --- |
| Shared positions, layers, keys, and system intentions | `src/family.ts` |
| Timing and wiring compensation | Device profiles in `src/family.ts` |
| QMK rendering | `src/render-firmware.ts` |
| ZMK rendering | `src/render-firmware.ts` |
| Karabiner rendering and host bridges | `src/render-karabiner.ts` |
| Firmware-only gaming, Bluetooth, and private macro slots | Target adapter |
| Flashing, Git commits, pushes, and pull requests | Outside this package |

The compiler exposes only two domain operations:

```ts
compileFamily(definition)
verifyFamily(compiled, toolchainPort)
```

Compilation is deterministic and pure from the caller's perspective. The CLI
is the filesystem adapter that writes explicitly owned generated files.

## Cross-repository workflow

Set the two target worktrees once in your shell, or pass the equivalent flags:

```sh
export KEYBOARD_QMK_REPO=/path/to/crkdb_split
export KEYBOARD_ZMK_REPO=/path/to/crkdb-zmk
```

From the dotfiles root:

```sh
./bin/keyboard-layout check
./bin/keyboard-layout sync --check
./bin/keyboard-layout sync --write
```

`sync --check` fails when a generated artifact has drifted. `sync --write`
changes only the generated target and manifest files. It cannot flash, commit,
push, or open a pull request.

After a semantic edit:

1. Run `./bin/keyboard-layout check`.
2. Run `./bin/keyboard-layout sync --write` against the QMK and ZMK worktrees.
3. Build Karabiner with `npm --prefix .config/karabiner run build`.
4. Build QMK and both ZMK halves; each firmware repository also builds in CI.
5. Review the same layout digest in all three manifests.
6. Commit each repository independently.
7. Flash only as a separate, explicitly confirmed operation.

The QMK repository uses the official external-userspace structure and publishes
firmware from `main`. The ZMK repository keeps its existing user-config build.
Karabiner remains local to dotfiles. This lets the repositories stay separate
without duplicating ergonomic decisions.

## Generated boundaries

- dotfiles: `.config/karabiner/generated/`
- QMK: `keyboards/crkbd/keymaps/g33km44n38/keymap.c` and `.keyboard-layout.json`
- ZMK: `config/generated/shared-layout.dtsi` and `.keyboard-layout.json`

ZMK keeps device-local macros in `config/corne.keymap`; the generated include
overrides only the effective layer bindings. Generated artifacts never contain
secret values.

## Thumb contract

- left middle: Backspace when tapped, System when held
- left inner: Enter when tapped, Numbers when held

The wireless Corne has those two physical inputs reversed. Its profile swaps
the inputs while preserving this canonical finger contract.

## macOS host bridges

Firmware sends host-only system intentions through reserved keys that
Karabiner consumes:

- F14: Home
- F15: toggle appearance
- F16: Control Center
- F17: Notification Center

Native media, volume, brightness, mute, and lock actions stay native whenever
the firmware supports them.
