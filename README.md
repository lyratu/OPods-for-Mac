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

## Notes

Pair the earbuds in macOS Bluetooth settings before connecting from the app. The underlying OPPO protocol is reverse-engineered and model support depends on the same metadata assumptions as the Windows reference project.

The bundled protocol-derived code and device metadata are treated as GPL-3.0-derived material from the reference project.
