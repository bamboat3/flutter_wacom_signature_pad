# Changelog

## 1.0.1

* Complete README rewrite — full API reference, FlutterFlow guide, architecture diagram, AppColors table, SSL and branding sections.
* Fix: correct multipart field names in `WacomPdfSigner` docstring (`filestream`, `outputfilename`).
* Improved example app — five runnable demos covering every exported widget and provider.

## 1.0.0

* Initial release.
* `WacomPdfSigner` widget — downloads PDF from URL, displays interactive PDF viewer with signature placement.
* Drag-to-draw or tap-to-place signature boxes on any page.
* Wacom STU tablet integration — captures handwritten signatures via pen input.
* Saves signatures to the tablet idle screen with custom logo and brand text.
* Uploads signed PDF to your API as `multipart/form-data` with `token`, `outputfilename`, and `filestream` fields.
* Supports both proper SSL certificates and self-signed certificates via `trustSelfSignedCertificate` parameter.
* Right-side control panel with live Wacom connection status, signature counter, and save button.
* `HomeScreen` — full home screen with recent documents list and Wacom connection toggle.
* `PdfViewerScreen` — standalone PDF viewer screen with signature placement.
* `SignatureDialog` — signature capture dialog with Wacom pen and touch/mouse fallback.
* `SavedSignaturesDialog` — browse and reuse previously saved signatures.
* Windows-only platform support (Wacom STU SDK).
