# Changelog

## 1.0.1

* Complete README — badges, channel reference, connect/disconnect/stream/display examples, full signature capture example.
* Fix: shorten package description to comply with pub.dev 180-character limit.

## 0.0.1

* Initial release.
* `MethodChannel` (`wacom_stu_channel`) — connect, disconnect, clearScreen, setSignatureScreen.
* `EventChannel` (`wacom_stu_events`) — real-time pen input streaming (x, y, pressure, switch).
* Windows-only native implementation using Wacom STU SDK C++ (USB interface).
* Background thread for non-blocking pen event polling.
* Thread-safe event queue with Windows message handling.
