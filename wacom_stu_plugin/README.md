# wacom_stu_plugin

A Flutter **Windows** plugin for Wacom STU signature tablet communication.

Provides `MethodChannel` and `EventChannel` interfaces to connect, disconnect,
control the display, and stream real-time pen input from Wacom STU USB devices.

> **Platform:** Windows only. Requires [Wacom STU SDK](https://developer.wacom.com/developer-dashboard)
> installed at `C:/Program Files (x86)/Wacom STU SDK/cpp`.

---

## This plugin is used by

[flutter_wacom_signature_pad](https://pub.dev/packages/flutter_wacom_signature_pad) —
a higher-level package that provides ready-made PDF signing widgets built on top of this plugin.

---

## Channels

### MethodChannel — `wacom_stu_channel`

| Method | Returns | Description |
|---|---|---|
| `connect` | `Map` (status, maxX, maxY, screenWidth, screenHeight) | Connects to the first available Wacom STU USB device |
| `disconnect` | `String` | Disconnects the device |
| `clearScreen` | `void` | Clears the tablet display |
| `setSignatureScreen` | `void` | Renders an RGB image onto the tablet display |

### EventChannel — `wacom_stu_events`

Streams pen input events as `Map<String, int>`:

| Field | Description |
|---|---|
| `x` | Pen X coordinate (raw tablet units) |
| `y` | Pen Y coordinate (raw tablet units) |
| `pressure` | Pen pressure |
| `sw` | Switch state (button pressed) |

---

## Usage

```dart
import 'package:wacom_stu_plugin/wacom_stu_plugin.dart';

const methodChannel = MethodChannel('wacom_stu_channel');
const eventChannel  = EventChannel('wacom_stu_events');

// Connect
final caps = await methodChannel.invokeMethod('connect');

// Stream pen events
eventChannel.receiveBroadcastStream().listen((event) {
  final x        = event['x'];
  final y        = event['y'];
  final pressure = event['pressure'];
});

// Disconnect
await methodChannel.invokeMethod('disconnect');
```

---

## Requirements

- Wacom STU SDK installed at `C:/Program Files (x86)/Wacom STU SDK/cpp`
- Windows 10 or later
- USB connection to a Wacom STU device

---

## License

MIT — see [LICENSE](LICENSE)
