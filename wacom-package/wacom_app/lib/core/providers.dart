import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wacom_app/core/services/file_service.dart';
import 'package:wacom_app/core/services/pdf_service.dart';
import 'package:wacom_app/core/services/recent_files_service.dart';
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';
import 'package:wacom_app/core/services/signature_storage_service.dart';

final fileServiceProvider = Provider<FileService>((ref) => FileService());
final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());
final signatureStorageServiceProvider = Provider<SignatureStorageService>(
  (ref) => SignatureStorageService(),
);
final recentFilesServiceProvider = Provider<RecentFilesService>(
  (ref) => RecentFilesService(),
);

final recentFilesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(recentFilesServiceProvider);
  return service.getRecentFiles();
});

final wacomPadControllerProvider = Provider<WacomSignaturePadController>(
  (ref) => WacomSignaturePadController(),
);

final wacomDeviceDetectedProvider = FutureProvider<bool>((ref) async {
  final controller = ref.watch(wacomPadControllerProvider);
  return controller.detectDevice();
});
