# wacom_stu_plugin

[![pub package](https://img.shields.io/pub/v/wacom_stu_plugin.svg)](https://pub.dev/packages/wacom_stu_plugin)
[![pub points](https://img.shields.io/pub/points/wacom_stu_plugin)](https://pub.dev/packages/wacom_stu_plugin/score)
[![likes](https://img.shields.io/pub/likes/wacom_stu_plugin)](https://pub.dev/packages/wacom_stu_plugin)

A Flutter **Windows** plugin for Wacom STU signature tablet communication.

Provides `MethodChannel` and `EventChannel` interfaces to connect, disconnect,
control the display, and stream real-time pen input from Wacom STU USB devices.

> **Platform:** Windows only. Requires the
> [Wacom STU SDK](https://developer.wacom.com/developer-dashboard)
> installed at `C:/Program Files (x86)/Wacom STU SDK/cpp`.

---

## Used by

[flutter_wacom_signature_pad](https://pub.dev/packages/flutter_wacom_signature_pad) —
a higher-level package providing ready-made PDF signing widgets built on top of this plugin.
Use that package if you want drag-to-place signature boxes, PDF embedding, and upload support
without writing low-level channel code.

---

## Platform support

| Android | iOS | macOS | Windows | Linux | Web |
|:-------:|:---:|:-----:|:-------:|:-----:|:---:|
|    ❌   |  ❌  |  ❌   |    ✅   |  ❌   |  ❌ |

---

## Installation

```yaml
dependencies:
  wacom_stu_plugin: ^1.0.1
```

```bash
flutter pub get
```

---

## Channels

### MethodChannel — `wacom_stu_channel`

| Method | Returns | Description |
|---|---|---|
| `connect` | `Map` | Connects to the first available Wacom STU USB device. Returns `status`, `maxX`, `maxY`, `screenWidth`, `screenHeight` |
| `disconnect` | `String` | Disconnects the device |
| `clearScreen` | `void` | Clears the tablet display |
| `setSignatureScreen` | `void` | Renders an RGB image onto the tablet display |

### EventChannel — `wacom_stu_events`

Streams real-time pen input events as `Map<String, int>`:

| Field | Type | Description |
|---|---|---|
| `x` | `int` | Pen X coordinate in raw tablet units |
| `y` | `int` | Pen Y coordinate in raw tablet units |
| `pressure` | `int` | Pen pressure value |
| `sw` | `int` | Switch state — `1` when pen button is pressed |

---

## Usage

### Connect and disconnect

```dart
import 'package:flutter/services.dart';

const _channel = MethodChannel('wacom_stu_channel');

// Connect — returns tablet capabilities
final Map result = await _channel.invokeMethod('connect');
final double maxX         = (result['maxX'] as int).toDouble();
final double maxY         = (result['maxY'] as int).toDouble();
final double screenWidth  = (result['screenWidth'] as int).toDouble();
final double screenHeight = (result['screenHeight'] as int).toDouble();

// Disconnect
await _channel.invokeMethod('disconnect');
```

### Stream pen events

```dart
import 'package:flutter/services.dart';

const _events = EventChannel('wacom_stu_events');

final subscription = _events.receiveBroadcastStream().listen((event) {
  final int x        = event['x'];
  final int y        = event['y'];
  final int pressure = event['pressure'];
  final int sw       = event['sw']; // 1 = pen button pressed

  // Convert raw tablet coords to canvas coords:
  // canvasX = (x / maxX) * canvasWidth
  // canvasY = (y / maxY) * canvasHeight
});

// Cancel when done
await subscription.cancel();
```

### Display an image on the tablet screen

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

const _channel = MethodChannel('wacom_stu_channel');

// rgbBytes — raw RGB bytes (width × height × 3)
// mode     — display mode integer (device-specific)
await _channel.invokeMethod('setSignatureScreen', {
  'data': rgbBytes,
  'mode': mode,
});
```

### Clear the tablet screen

```dart
await _channel.invokeMethod('clearScreen');
```

---

## Full example — capture a signature

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WacomSignatureCapture extends StatefulWidget {
  const WacomSignatureCapture({super.key});

  @override
  State<WacomSignatureCapture> createState() => _WacomSignatureCaptureState();
}

class _WacomSignatureCaptureState extends State<WacomSignatureCapture> {
  static const _channel = MethodChannel('wacom_stu_channel');
  static const _events  = EventChannel('wacom_stu_events');

  StreamSubscription? _sub;
  final List<Offset> _points = [];
  double _maxX = 1.0, _maxY = 1.0;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    final result = await _channel.invokeMethod('connect');
    setState(() {
      _maxX = (result['maxX'] as int).toDouble();
      _maxY = (result['maxY'] as int).toDouble();
      _connected = true;
    });

    _sub = _events.receiveBroadcastStream().listen((event) {
      final double px = (event['x'] as int) / _maxX;
      final double py = (event['y'] as int) / _maxY;
      setState(() => _points.add(Offset(px, py)));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel.invokeMethod('disconnect');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_connected ? 'Tablet connected' : 'Connecting...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _points.clear()),
          ),
        ],
      ),
      body: CustomPaint(
        painter: _SignaturePainter(_points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(
        Offset(points[i].dx * size.width, points[i].dy * size.height),
        Offset(points[i + 1].dx * size.width, points[i + 1].dy * size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.points != points;
}
```

---

## Requirements

- Wacom STU SDK installed at `C:/Program Files (x86)/Wacom STU SDK/cpp`
- Windows 10 or later
- Wacom STU device connected via USB

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

MIT — see [LICENSE](LICENSE).
