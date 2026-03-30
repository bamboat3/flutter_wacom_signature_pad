import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wacom_app/core/providers.dart';

class WacomConnectButton extends ConsumerWidget {
  const WacomConnectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(wacomDeviceDetectedProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: IconButton(
        icon: Icon(
          deviceState.when(
            data: (isDetected) => isDetected ? Icons.usb : Icons.usb_off,
            loading: () => Icons.usb,
            error: (error, stackTrace) => Icons.usb_off,
          ),
          color: deviceState.when(
            data: (isDetected) =>
                isDetected ? Colors.greenAccent : Colors.black,
            loading: () => Colors.orangeAccent,
            error: (error, stackTrace) => Colors.redAccent,
          ),
        ),
        tooltip: deviceState.when(
          data: (isDetected) =>
              isDetected ? "Wacom Detected" : "Wacom Not Found",
          loading: () => "Checking Wacom...",
          error: (error, stackTrace) => "Wacom Check Failed",
        ),
        onPressed: () {
          ref.invalidate(wacomDeviceDetectedProvider);
        },
      ),
    );
  }
}
