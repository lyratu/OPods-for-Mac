# Upstream Sync Notes

Reference upstream: `Zhaoyi-ya/OPPO-Pods-For-Windows`

Last compared local reference: `/private/tmp/OPPO-Pods-For-Windows`, commit `75b806e`.

## Design Review

The first macOS pass worked, but it over-customized the core protocol surface:

- `OppoProtocol.swift` mixed protocol constants, frame parsing, and state reduction in one file.
- Command names were translated into a Swift-only nested `Command` enum, making upstream C# diffs less mechanical.
- The Bluetooth service was named after the Mac platform instead of the upstream role, even though it is the same conceptual layer as `RfcommService.cs`.
- `DeviceCapabilities` parsing was moved behind `DeviceCatalog` only, which obscured the upstream `Detect` / `ForceModel` / `GetModelNames` entry points.
- `dist/` was ignored, which conflicted with the requirement to publish build artifacts together with later pushes.

## Current Mapping

| Upstream file | macOS file | Sync rule |
| --- | --- | --- |
| `OppoProtocol.cs` | `Sources/OPodsMac/Services/OppoProtocol.swift` | Keep command, feature, packet, and helper names aligned as closely as Swift allows. |
| `RfcommService.cs` | `Sources/OPodsMac/Services/RfcommService.swift` | Keep startup packet order, send methods, and polling cadence aligned; only device discovery and socket transport should be Mac-specific. |
| `DeviceCapabilities.cs` | `Sources/OPodsMac/Models/DeviceCapabilities.swift` | Keep JSON derivation logic and public entry point names aligned; Swift data models can stay typed. |
| `PodState.cs` | `Sources/OPodsMac/Models/PodModels.swift` | Keep state fields conceptually aligned, while using Swift enums for UI safety. |

## Intentional Mac Differences

- Windows registry scanning is replaced by `IOBluetoothDevice.pairedDevices()`.
- Winsock RFCOMM sockets are replaced by `IOBluetoothRFCOMMChannel`.
- WPF tray UI is replaced by SwiftUI plus `MenuBarExtra`.
- App packaging is handled by `script/build_and_run.sh`, producing `dist/OPodsMac.app`.

When upstream changes protocol constants, feature IDs, packet payloads, or parse logic, port those changes into the matching Swift file before touching UI code.
