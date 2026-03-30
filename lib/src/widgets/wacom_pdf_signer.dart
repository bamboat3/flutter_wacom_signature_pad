import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import '../providers/providers.dart';
import '../constants/app_colors.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import 'signature_dialog.dart';
import 'saved_signatures_dialog.dart';
import 'signature_box_overlay.dart';
import 'pdf_viewer_screen.dart' show SignatureBoxModel;

/// A self-contained PDF signing widget for Wacom STU tablets.
///
/// Downloads the PDF from [pdfUrl], displays it with an interactive
/// signature placement canvas, then uploads the signed PDF to [uploadUrl]
/// as multipart/form-data. Your API receives the file bytes and filename
/// and handles saving to disk.
///
/// Multipart fields sent to your API:
///   - `file`     — the signed PDF binary
///   - `fileName` — the value of [outputFileName]
///
/// Example:
/// ```dart
/// WacomPdfSigner(
///   pdfUrl: 'http://hr.company.pk/pdf/contract.pdf',
///   outputFileName: 'signed_contract.pdf',
///   uploadUrl: 'http://hr.company.pk/api/upload-signed-pdf',
///   onResult: (success) {
///     if (success) updateDatabase();
///   },
/// )
/// ```
class WacomPdfSigner extends StatelessWidget {
  /// URL of the PDF to download and display.
  final String pdfUrl;

  /// Filename passed to your API as the `fileName` form field.
  /// Your API uses this to name the file when saving to disk.
  final String outputFileName;

  /// Your API endpoint that receives the signed PDF as multipart/form-data.
  /// e.g. 'http://hr.company.pk/api/upload-signed-pdf'
  final String uploadUrl;

  /// Called after upload completes. Receives [true] on success (HTTP 2xx),
  /// [false] on failure.
  final void Function(bool success)? onResult;

  /// Optional asset path for the logo displayed on the Wacom tablet idle screen.
  /// Must be declared in your app's pubspec.yaml assets section.
  /// e.g. 'assets/images/company_logo.png'
  /// Defaults to the package's built-in logo.
  final String? logoAssetPath;

  /// Text displayed below the logo on the Wacom tablet idle screen.
  /// e.g. 'HRMS E-Kiosk'
  /// Defaults to 'FlutterWacom'.
  final String? brandText;

  /// Set to [true] if your server uses a self-signed SSL certificate.
  /// Set to [false] (default) for servers with a proper SSL certificate.
  /// Warning: only enable this on trusted internal networks.
  final bool trustSelfSignedCertificate;

  /// Authentication token sent as the `token` field in the multipart POST.
  final String token;

  const WacomPdfSigner({
    super.key,
    required this.pdfUrl,
    required this.outputFileName,
    required this.uploadUrl,
    required this.token,
    this.onResult,
    this.logoAssetPath,
    this.brandText,
    this.trustSelfSignedCertificate = false,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _WacomPdfSignerBody(
        pdfUrl: pdfUrl,
        outputFileName: outputFileName,
        uploadUrl: uploadUrl,
        token: token,
        onResult: onResult,
        logoAssetPath: logoAssetPath,
        brandText: brandText,
        trustSelfSignedCertificate: trustSelfSignedCertificate,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal body — uses Riverpod
// ---------------------------------------------------------------------------

class _WacomPdfSignerBody extends ConsumerStatefulWidget {
  final String pdfUrl;
  final String outputFileName;
  final String uploadUrl;
  final String token;
  final void Function(bool success)? onResult;
  final String? logoAssetPath;
  final String? brandText;
  final bool trustSelfSignedCertificate;

  const _WacomPdfSignerBody({
    required this.pdfUrl,
    required this.outputFileName,
    required this.uploadUrl,
    required this.token,
    this.onResult,
    this.logoAssetPath,
    this.brandText,
    this.trustSelfSignedCertificate = false,
  });

  @override
  ConsumerState<_WacomPdfSignerBody> createState() =>
      _WacomPdfSignerBodyState();
}

class _WacomPdfSignerBodyState extends ConsumerState<_WacomPdfSignerBody> {
  // ── Loading ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _loadError;
  File? _pdfFile;

  // ── PDF viewer ───────────────────────────────────────────────────────────
  final PdfViewerController _pdfController = PdfViewerController();
  PdfDocument? _document;
  List<Size>? _pageSizes;
  bool _isDocumentLoaded = false;
  Size? _viewportSize;
  Timer? _scrollPoller;

  static const double _pageSpacing = 8.0;

  // ── Drawing mode ─────────────────────────────────────────────────────────
  bool _isDrawingMode = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _dragPageIndex;

  // ── Signatures ───────────────────────────────────────────────────────────
  final List<SignatureBoxModel> _signatures = [];

  // ── Save ─────────────────────────────────────────────────────────────────
  bool _isSaving = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _downloadPdf();
    _scrollPoller = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (_isDocumentLoaded && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollPoller?.cancel();
    _document?.dispose();
    super.dispose();
  }

  // ── SSL-aware HTTP clients ────────────────────────────────────────────────

  /// Returns a dart:io HttpClient that optionally trusts self-signed certs.
  /// Used for the PDF download.
  HttpClient _buildDartHttpClient() {
    final client = HttpClient();
    if (widget.trustSelfSignedCertificate) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }

  /// Returns an http.Client that optionally trusts self-signed certs.
  /// Used for the multipart upload.
  http.Client _buildHttpClient() {
    if (widget.trustSelfSignedCertificate) {
      final ioClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(ioClient);
    }
    return http.Client();
  }

  // ── PDF download & metadata ───────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    try {
      final file = await _downloadPdfWithClient(widget.pdfUrl);
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final sizes = <Size>[
        for (int i = 0; i < doc.pages.count; i++)
          doc.pages[i].getClientSize(),
      ];

      if (!mounted) return;
      setState(() {
        _pdfFile = file;
        _document = doc;
        _pageSizes = sizes;
        _isLoading = false;
      });

      // Auto-connect Wacom on load
      final wacomState = ref.read(wacomConnectionProvider);
      if (!wacomState.isConnected) {
        ref.read(wacomConnectionProvider.notifier).connect();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_viewportSize != null && sizes.isNotEmpty) {
          double maxW = sizes.fold(0.0, (m, s) => s.width > m ? s.width : m);
          if (maxW > 0 && maxW > _viewportSize!.width) {
            _pdfController.zoomLevel =
                (_viewportSize!.width - 32) / maxW;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Downloads the PDF using the SSL-aware dart:io HttpClient.
  Future<File> _downloadPdfWithClient(String url) async {
    final uri = Uri.parse(url.trim());
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Please enter a valid PDF URL.');
    }
    final client = _buildDartHttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download PDF (${response.statusCode}).',
          uri: uri,
        );
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}\\document_$timestamp.pdf');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  // ── Coordinate helpers ────────────────────────────────────────────────────

  double get _internalScale {
    if (_viewportSize == null || _pageSizes == null || _pageSizes!.isEmpty) {
      return 1.0;
    }
    final maxW = _pageSizes!.fold(0.0, (m, s) => s.width > m ? s.width : m);
    return maxW == 0 ? 1.0 : _viewportSize!.width / maxW;
  }

  Rect _getScreenRect(SignatureBoxModel model) {
    if (_pageSizes == null || !_isDocumentLoaded) return Rect.zero;
    final zoom = _pdfController.zoomLevel * _internalScale;
    final scroll = _pdfController.scrollOffset;

    double pageTop = 0;
    for (int i = 0; i < model.pageIndex; i++) {
      pageTop += _pageSizes![i].height * zoom + _pageSpacing;
    }

    double marginLeft = 0;
    if (_viewportSize != null) {
      final pageW = _pageSizes![model.pageIndex].width * zoom;
      if (pageW < _viewportSize!.width) {
        marginLeft = (_viewportSize!.width - pageW) / 2;
      }
    }

    return Rect.fromLTWH(
      model.pdfRect.left * zoom + marginLeft - scroll.dx,
      model.pdfRect.top * zoom + pageTop - scroll.dy,
      model.pdfRect.width * zoom,
      model.pdfRect.height * zoom,
    );
  }

  // ── Drawing mode ──────────────────────────────────────────────────────────

  void _toggleDrawingMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
      if (!_isDrawingMode) {
        _dragStart = null;
        _dragCurrent = null;
        _dragPageIndex = null;
      }
    });
  }

  // ── Signature interaction ─────────────────────────────────────────────────

  void _onPdfTap(PdfGestureDetails details) {
    final model = SignatureBoxModel(
      id: const Uuid().v4(),
      pdfRect: Rect.fromLTWH(
        details.pagePosition.dx,
        details.pagePosition.dy,
        200,
        100,
      ),
      pageIndex: details.pageNumber - 1,
    );
    setState(() => _signatures.add(model));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openSignatureOptions(model);
    });
  }

  void _openSignatureOptions(SignatureBoxModel model) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.draw_rounded),
              title: const Text("Create New Signature"),
              onTap: () {
                Navigator.pop(ctx);
                _openSignatureDialog(model);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Select Saved Signature"),
              onTap: () {
                Navigator.pop(ctx);
                _openSavedSignaturesDialog(model);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSignatureDialog(SignatureBoxModel model) async {
    final wacomState = ref.read(wacomConnectionProvider);
    if (!wacomState.isConnected) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Device Not Connected"),
          content: const Text("Please connect the Wacom device first."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }
    final Uint8List? result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SignatureDialog(
        logoAssetPath: widget.logoAssetPath,
        brandText: widget.brandText,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => model.image = result);
  }

  void _openSavedSignaturesDialog(SignatureBoxModel model) async {
    final Uint8List? result = await showDialog(
      context: context,
      builder: (ctx) => const SavedSignaturesDialog(),
    );
    if (!mounted || result == null) return;
    setState(() => model.image = result);
  }

  void _handleSignatureDrag(SignatureBoxModel model, Offset delta) {
    if (_pageSizes == null || _pageSizes!.isEmpty) return;
    final zoom = _pdfController.zoomLevel * _internalScale;
    setState(() {
      model.pdfRect = Rect.fromLTWH(
        model.pdfRect.left + delta.dx / zoom,
        model.pdfRect.top + delta.dy / zoom,
        model.pdfRect.width,
        model.pdfRect.height,
      );
      final pageH = _pageSizes![model.pageIndex].height;
      if (model.pdfRect.top > pageH &&
          model.pageIndex < _pageSizes!.length - 1) {
        model.pageIndex++;
        model.pdfRect = Rect.fromLTWH(
          model.pdfRect.left,
          model.pdfRect.top - pageH,
          model.pdfRect.width,
          model.pdfRect.height,
        );
      } else if (model.pdfRect.top < 0 && model.pageIndex > 0) {
        model.pageIndex--;
        model.pdfRect = Rect.fromLTWH(
          model.pdfRect.left,
          _pageSizes![model.pageIndex].height + model.pdfRect.top,
          model.pdfRect.width,
          model.pdfRect.height,
        );
      }
    });
  }

  // ── Upload signed PDF to API as multipart/form-data ──────────────────────

  Future<void> _saveDocument() async {
    final signed = _signatures.where((s) => s.image != null).toList();
    if (signed.isEmpty) {
      _showSnack("Please sign at least one signature box.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Embed signatures into PDF bytes
      final pdfBytes = await PdfService().embedSignatures(
        pdfFile: _pdfFile!,
        signatures: signed
            .map((s) => {
                  'image': s.image!,
                  'x': s.pdfRect.left,
                  'y': s.pdfRect.top,
                  'width': s.pdfRect.width,
                  'height': s.pdfRect.height,
                  'pageIndex': s.pageIndex + 1,
                })
            .toList(),
      );

      // Build multipart/form-data request
      final uri = Uri.parse(widget.uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      // `token` field — auth token
      request.fields['token'] = widget.token;

      // `outputfilename` field — your API uses this for Path.Combine(...)
      request.fields['outputfilename'] = widget.outputFileName;

      // `filestream` field — signed PDF binary
      request.files.add(
        http.MultipartFile.fromBytes(
          'filestream',
          pdfBytes,
          filename: widget.outputFileName,
        ),
      );

      final client = _buildHttpClient();
      final streamedResponse = await client.send(request);
      client.close();
      final statusCode = streamedResponse.statusCode;

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (statusCode >= 200 && statusCode < 300) {
        _showSnack("Document uploaded successfully.");
        widget.onResult?.call(true);
      } else {
        _showSnack("Upload failed — server returned $statusCode.");
        widget.onResult?.call(false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack("Upload failed: $e");
      widget.onResult?.call(false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_loadError != null) return _buildError();
    return _buildSigner();
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              "Loading document…",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              "Failed to load document",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = null;
                });
                _downloadPdf();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSigner() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ── Left: PDF viewer ─────────────────────────────────────────────
          Expanded(child: _buildPdfViewer()),

          // ── Right: Control panel ─────────────────────────────────────────
          _buildControlPanel(),
        ],
      ),
    );
  }

  // ── PDF viewer area ───────────────────────────────────────────────────────

  Widget _buildPdfViewer() {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        setState(() {});
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = constraints.biggest;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SfPdfViewer.file(
                _pdfFile!,
                controller: _pdfController,
                pageSpacing: _pageSpacing,
                enableDoubleTapZooming: false,
                onDocumentLoaded: (_) => setState(() => _isDocumentLoaded = true),
                onTap: _isDrawingMode ? null : _onPdfTap,
                onPageChanged: (_) => setState(() {}),
                onZoomLevelChanged: (_) => setState(() {}),
              ),

              // Signature box overlays
              if (_isDocumentLoaded)
                ..._signatures.map((model) {
                  return SignatureBoxOverlay(
                    rect: _getScreenRect(model),
                    signatureImage: model.image,
                    onUpdate: (delta) => _handleSignatureDrag(model, delta),
                    onConfirm: () => _openSignatureOptions(model),
                    onDelete: () =>
                        setState(() => _signatures.remove(model)),
                  );
                }),

              // Draw-mode gesture layer
              if (_isDrawingMode) _buildDrawLayer(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawLayer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => setState(() {
          _dragStart = d.localPosition;
          _dragCurrent = d.localPosition;
          _dragPageIndex = _pdfController.pageNumber > 0
              ? _pdfController.pageNumber - 1
              : 0;
        }),
        onPanUpdate: (d) => setState(() => _dragCurrent = d.localPosition),
        onPanEnd: (_) {
          if (_dragStart == null ||
              _dragCurrent == null ||
              _dragPageIndex == null ||
              _pageSizes == null) return;

          final l = _dragStart!.dx < _dragCurrent!.dx
              ? _dragStart!.dx
              : _dragCurrent!.dx;
          final t = _dragStart!.dy < _dragCurrent!.dy
              ? _dragStart!.dy
              : _dragCurrent!.dy;
          final r = _dragStart!.dx > _dragCurrent!.dx
              ? _dragStart!.dx
              : _dragCurrent!.dx;
          final b = _dragStart!.dy > _dragCurrent!.dy
              ? _dragStart!.dy
              : _dragCurrent!.dy;

          final screenRect = Rect.fromLTRB(l, t, r, b);

          if (screenRect.width > 30 && screenRect.height > 20) {
            final zoom = _pdfController.zoomLevel * _internalScale;
            final scroll = _pdfController.scrollOffset;

            double pageTop = 0;
            for (int i = 0; i < _dragPageIndex!; i++) {
              pageTop += _pageSizes![i].height * zoom + _pageSpacing * zoom;
            }

            double marginLeft = 0;
            if (_viewportSize != null) {
              final pageW = _pageSizes![_dragPageIndex!].width * zoom;
              if (pageW < _viewportSize!.width) {
                marginLeft = (_viewportSize!.width - pageW) / 2;
              }
            }

            final model = SignatureBoxModel(
              id: const Uuid().v4(),
              pdfRect: Rect.fromLTWH(
                (screenRect.left + scroll.dx - marginLeft) / zoom,
                (screenRect.top + scroll.dy - pageTop) / zoom,
                screenRect.width / zoom,
                screenRect.height / zoom,
              ),
              pageIndex: _dragPageIndex!,
            );

            setState(() {
              _signatures.add(model);
              _isDrawingMode = false;
              _dragStart = null;
              _dragCurrent = null;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openSignatureOptions(model);
            });
          } else {
            setState(() {
              _dragStart = null;
              _dragCurrent = null;
            });
          }
        },
        child: Stack(
          children: [
            // Draw selection rect preview
            if (_dragStart != null && _dragCurrent != null)
              Positioned(
                left: _dragStart!.dx < _dragCurrent!.dx
                    ? _dragStart!.dx
                    : _dragCurrent!.dx,
                top: _dragStart!.dy < _dragCurrent!.dy
                    ? _dragStart!.dy
                    : _dragCurrent!.dy,
                width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
                height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Right control panel ───────────────────────────────────────────────────

  Widget _buildControlPanel() {
    final wacomState = ref.watch(wacomConnectionProvider);
    final signedCount = _signatures.where((s) => s.image != null).length;
    final totalCount = _signatures.length;

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceHover,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                Icon(Icons.draw_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Text(
                  "Signature Controls",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Wacom status ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DEVICE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: wacomState.isConnected
                        ? AppColors.success.withValues(alpha: 0.08)
                        : AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: wacomState.isConnected
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: wacomState.isConnected
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wacomState.isConnected
                              ? "Wacom Connected"
                              : "Not Connected",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: wacomState.isConnected
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (wacomState.isConnected) {
                            ref
                                .read(wacomConnectionProvider.notifier)
                                .disconnect();
                          } else {
                            ref
                                .read(wacomConnectionProvider.notifier)
                                .connect();
                          }
                        },
                        child: Icon(
                          wacomState.isConnected ? Icons.usb_off : Icons.usb,
                          size: 18,
                          color: wacomState.isConnected
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // ── Signature count ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SIGNATURES",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statChip(
                      label: "Placed",
                      value: "$totalCount",
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _statChip(
                      label: "Signed",
                      value: "$signedCount",
                      color: signedCount == totalCount && totalCount > 0
                          ? AppColors.success
                          : AppColors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // ── Actions ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "ACTIONS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Draw signature box toggle
                OutlinedButton.icon(
                  onPressed:
                      _isDocumentLoaded ? _toggleDrawingMode : null,
                  icon: Icon(
                    _isDrawingMode ? Icons.close : Icons.crop_free_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isDrawingMode ? "Cancel Drawing" : "Draw Signature Box",
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDrawingMode
                        ? AppColors.error
                        : AppColors.primary,
                    side: BorderSide(
                      color: _isDrawingMode
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Instructions ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "HOW TO SIGN",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._instructions.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Save button ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: FilledButton.icon(
              onPressed: (_isSaving || signedCount == 0)
                  ? null
                  : _saveDocument,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                _isSaving ? "Saving…" : "Save Document",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _instructions = [
    ("1", "Tap anywhere on the PDF to place a signature box."),
    ("2", "Or use 'Draw Signature Box' to drag a custom-sized box."),
    ("3", "Tap the box and sign using your Wacom pen."),
    ("4", "Press 'Save Document' when done."),
  ];
}
