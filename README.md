# OPods for Mac

Native macOS SwiftUI adaptation of the OPPO / OnePlus / realme earbuds controller from `Zhaoyi-ya/OPPO-Pods-For-Windows`.

The app keeps the reverse-engineered OPPO RFCOMM protocol shape and device capability matrix, while replacing the Windows WPF/tray implementation with macOS-native pieces:

- SwiftUI main window with sidebar, controls, settings, and paired-device list
- Menu bar extra with quick battery status and connect/disconnect actions
- IOBluetooth RFCOMM transport for the OPPO SPP UUID
- Device capability detection from `DeviceModels.json`
- Battery, wear detection, ANC, spatial sound/audio, game mode, dual-device, EQ, and multi-device packet parsing

## Build and Run

```bash
./script/build_and_run.sh
```

Use `./script/build_and_run.sh --verify` to build, launch, and check that the app process is running.

The script stages the runnable app bundle at `dist/OPodsMac.app`. This repository intentionally allows `dist/` to be tracked so GitHub pushes can include the latest local build artifact alongside source changes.

## Upstream Sync

The protocol-heavy files keep names close to `Zhaoyi-ya/OPPO-Pods-For-Windows`:

- `OppoProtocol.swift` mirrors `OppoProtocol.cs` command names, feature IDs, prebuilt packets, and payload helpers.
- `DeviceCapabilities.swift` keeps `Detect`, `ForceModel`, and `GetModelNames` entry points for easier comparison with `DeviceCapabilities.cs`.
- `RfcommService.swift` is the macOS transport counterpart to upstream `RfcommService.cs`; Windows socket and registry code are replaced with IOBluetooth, while packet order and polling behavior stay aligned.
- `OppoFrameParser.swift` and `OppoFrameReducer.swift` contain the platform-neutral parsing split out of `RfcommService` so protocol constants can be updated independently.

## Notes

Pair the earbuds in macOS Bluetooth settings before connecting from the app. The underlying OPPO protocol is reverse-engineered and model support depends on the same metadata assumptions as the Windows reference project.

The bundled protocol-derived code and device metadata are treated as GPL-3.0-derived material from the reference project.
