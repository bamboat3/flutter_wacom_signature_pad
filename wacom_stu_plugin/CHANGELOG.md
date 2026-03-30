# Changelog

## 0.0.1

* Initial release.
* `MethodChannel` (`wacom_stu_channel`) — connect, disconnect, clearScreen, setSignatureScreen.
* `EventChannel` (`wacom_stu_events`) — real-time pen input streaming (x, y, pressure, switch).
* Windows-only native implementation using Wacom STU SDK C++ (USB interface).
* Background thread for non-blocking pen event polling.
* Thread-safe event queue with Windows message handling.
