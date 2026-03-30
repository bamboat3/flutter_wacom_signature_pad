# flutter_wacom_signature_pad

A Flutter **Windows** package for Wacom STU tablet signature capture and PDF signing.

- Download a PDF from a URL and display it in an interactive viewer
- Place signature boxes anywhere on the PDF (tap or drag-to-draw)
- Capture handwritten signatures using a Wacom STU pen tablet
- Upload the signed PDF to your API as `multipart/form-data`
- Custom logo and brand text on the Wacom tablet idle screen
- Supports proper SSL and self-signed SSL certificates

> **Platform:** Windows only (requires Wacom STU SDK)

---

## Requirements

- Flutter ≥ 3.38.5
- Dart ≥ 3.10.0
- Windows desktop
- [Wacom STU SDK](https://developer.wacom.com/developer-dashboard) installed at `C:/Program Files (x86)/Wacom STU SDK/cpp`

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_wacom_signature_pad: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## Usage

### WacomPdfSigner — Drop-in signing widget

The primary widget. Pass a PDF URL and your API endpoint — the widget handles everything else.

```dart
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';

WacomPdfSigner(
  pdfUrl: 'https://your-server.com/pdf/contract.pdf',
  outputFileName: 'signed_contract.pdf',
  uploadUrl: 'https://your-server.com/api/upload-signed-pdf',
  token: 'your_auth_token_here',
  logoAssetPath: 'assets/images/your_logo.png',
  brandText: 'Your App Name',
  trustSelfSignedCertificate: false,
  onResult: (bool success) {
    if (success) {
      // Document uploaded — update your database
    } else {
      // Upload failed — handle error
    }
  },
)
```

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `pdfUrl` | `String` | ✅ | URL of the PDF to download and display |
| `outputFileName` | `String` | ✅ | Filename passed to your API (e.g. `signed_contract.pdf`) |
| `uploadUrl` | `String` | ✅ | Your API endpoint that receives the signed PDF |
| `token` | `String` | ✅ | Auth token sent as the `token` field in the POST |
| `onResult` | `void Function(bool)` | | Called with `true` on success, `false` on failure |
| `logoAssetPath` | `String?` | | Asset path for logo on Wacom tablet idle screen |
| `brandText` | `String?` | | Text below logo on tablet idle screen (default: `FlutterWacom`) |
| `trustSelfSignedCertificate` | `bool` | | `true` for self-signed SSL, `false` for proper SSL (default: `false`) |

### What your API receives

```
POST https://your-server.com/api/upload-signed-pdf
Content-Type: multipart/form-data

token          → "your_auth_token_here"
outputfilename → "signed_contract.pdf"
filestream     → [signed PDF binary]
```

### ASP.NET Core example

```csharp
[HttpPost("upload-signed-pdf")]
public async Task<IActionResult> UploadSignedPdf(
    [FromForm] string token,
    [FromForm] string outputfilename,
    IFormFile filestream)
{
    // validate token...

    using var ms = new MemoryStream();
    await filestream.CopyToAsync(ms);
    var bytes = ms.ToArray();

    string fullPath = Path.Combine(_env.ContentRootPath, "pdf", outputfilename);
    if (System.IO.File.Exists(fullPath))
        System.IO.File.Delete(fullPath);

    System.IO.File.WriteAllBytes(fullPath, bytes);
    return Ok();
}
```

---

## SSL Configuration

```dart
// Proper SSL certificate (default)
WacomPdfSigner(
  trustSelfSignedCertificate: false, // can omit — this is the default
  ...
)

// Self-signed SSL certificate (internal corporate servers)
WacomPdfSigner(
  trustSelfSignedCertificate: true,
  ...
)
```

---

## Custom Branding on Wacom Tablet

The Wacom STU tablet displays an idle screen when not signing. You can customise it:

```dart
WacomPdfSigner(
  logoAssetPath: 'assets/images/company_logo.png', // declared in your pubspec.yaml
  brandText: 'HRMS E-Kiosk',
  ...
)
```

> The asset must be declared in your **app's** `pubspec.yaml`, not the package's.

---

## Individual Widgets

You can also use individual widgets directly:

```dart
// Full home screen with recent documents
HomeScreen()

// PDF viewer with signature placement
PdfViewerScreen(file: myFile)

// Signature capture dialog
showDialog(
  context: context,
  builder: (_) => SignatureDialog(
    logoAssetPath: 'assets/images/logo.png',
    brandText: 'My App',
  ),
)

// Browse saved signatures
showDialog(
  context: context,
  builder: (_) => SavedSignaturesDialog(),
)
```

---

## Riverpod

This package uses [Riverpod](https://riverpod.dev) for state management. `WacomPdfSigner` wraps itself in its own `ProviderScope` so it works standalone in FlutterFlow or any app without any setup.

---

## License

MIT — see [LICENSE](LICENSE)
