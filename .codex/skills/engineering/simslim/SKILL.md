---
name: simslim
description: Always use SimSlim when working with an iOS simulator on macOS, including app development, debugging, tests, screenshots, recordings, and simulator lifecycle management. Applies across all repositories; not to Android emulators or physical devices.
---

# SimSlim for iOS simulators

Kylian's global preference: always use `simslim` for iOS simulator work. This applies even when the task also uses Detox, Xcode, Expo, or another test runner.

## Before running the app or tests

1. Check `command -v simslim`, then `simslim help` for the installed version's commands. The CLI is named `simslim`, not `slimsim`.
2. Use `simslim list` to identify the exact device and its existing profile. Reuse the task's dedicated simulator. Do not reconfigure or reboot a device used by another task.
3. Keep the services required by the scenario. Read `simslim doctor --list` and `simslim profiles` when selecting exceptions. Reuse an applicable project profile; otherwise select `--except` categories or `--keep` labels for the actual tested features. Do not disable services under test, such as push, StoreKit, universal links, or iCloud Keychain.
4. Apply slimming with `simslim on <udid>` and the selected profile or exceptions. This command reboots the simulator: finish or stop the task's own test and recording first. If the device already matches the intended profile, skip reapplication.
5. Verify using `simslim verify <udid>` with the same profile or exceptions. Run `simslim doctor <udid> --requires <feature-ids>` for required features. Start tests only after those checks pass.

## During the task

- Prefer `simslim boot`, `shutdown`, `list`, and `status` for device lifecycle and inspection. Recheck the profile after a harness recreates or erases the simulator.
- Keep using the appropriate automation tool for app installation, UI interaction, assertions, screenshots, and video. `xcrun simctl` remains appropriate for operations SimSlim does not provide.
- Use `simslim measure <udid>` when reporting memory usage; do not claim savings without a measurement.
- Restore a required service through the selected exceptions and verify again if slimming breaks the tested flow. Do not silently fall back to a stock simulator.
- If SimSlim is unavailable or cannot apply a compatible profile, report the concrete blocker instead of claiming it was used. Continue independent work that does not require running the simulator.
- This skill does not authorize deleting or erasing devices, cleaning disks, changing shared runtimes, stopping another task's processes, or overriding an explicit user instruction.
