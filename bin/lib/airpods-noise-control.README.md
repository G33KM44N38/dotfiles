# AirPods noise control

Three Raycast commands set the mode without opening a menu:

- `transparency airpods`
- `noise cancellation airpods`
- `adaptative airpods`

They call `../airpods-noise-control`, which compiles `airpods-noise-control.m`
with Apple's command line tools on first use and after source changes. The
executable is stored in `~/.local/lib/airpods-noise-control/airpods-noise-control`.
Runtime uses only macOS frameworks. No paid dependency or restricted entitlement.

AirPods must be the default audio output and their name must contain `AirPods`.
Allow Bluetooth access for Raycast if macOS asks. Adaptive mode requires
compatible AirPods and firmware.

The implementation uses private CBClassicManager API after normal CoreBluetooth
permission. Its separate client-side approval flag is synchronized only after
the public central reaches poweredOn; system permissions are not modified.

Each change is verified in a fresh process to avoid reading a locally cached
value. The helper times out after eight seconds. This private API may need
adjustment after macOS updates.

Validated on macOS 26.4 with AirPods Pro: transparency, ANC and adaptive mode.
The user confirmed an audible change without a menu opening.

Implementation reference:
https://github.com/dchersey/air-defense/blob/main/macos/ControlPanel/Sources/ADBluetooth/ADListeningMode.m
