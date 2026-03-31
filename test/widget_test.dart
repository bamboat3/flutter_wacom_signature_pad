import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';

void main() {
  test('AppColors constants are defined', () {
    expect(AppColors.primary.value, isNonZero);
    expect(AppColors.error.value, isNonZero);
    expect(AppColors.success.value, isNonZero);
  });

  test('WacomConnectionState defaults', () {
    final state = WacomConnectionState();
    expect(state.isConnected, isFalse);
    expect(state.error, isNull);
    expect(state.capabilities, isNull);
  });
}
