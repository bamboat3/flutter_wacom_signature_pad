# flutter_wacom_signature_pad

[![pub package](https://img.shields.io/pub/v/flutter_wacom_signature_pad.svg)](https://pub.dev/packages/flutter_wacom_signature_pad)
[![pub points](https://img.shields.io/pub/points/flutter_wacom_signature_pad)](https://pub.dev/packages/flutter_wacom_signature_pad/score)
[![likes](https://img.shields.io/pub/likes/flutter_wacom_signature_pad)](https://pub.dev/packages/flutter_wacom_signature_pad)

A Flutter **Windows** package for Wacom STU tablet signature capture and PDF signing.

---

## Features

- **Download & display** a PDF from any URL in an interactive viewer
- **Place signature boxes** anywhere — tap to place or drag to draw a box
- **Capture handwritten signatures** from a Wacom STU pen tablet in real time
- **Embed signatures** into the PDF at the exact position chosen by the user
- **Upload the signed PDF** to your API as `multipart/form-data`
- **Custom branding** — show your logo and text on the Wacom tablet idle screen
- **SSL support** — works with both proper and self-signed SSL certificates
- **FlutterFlow compatible** — `WacomPdfSigner` wraps itself in its own `ProviderScope`

---

## Platform support

| Android | iOS | macOS | Windows | Linux | Web |
|:-------:|:---:|:-----:|:-------:|:-----:|:---:|
|    ❌   |  ❌  |  ❌   |    ✅   |  ❌   |  ❌ |

> Requires the [Wacom STU SDK](https://developer.wacom.com/developer-dashboard) installed
> at `C:/Program Files (x86)/Wacom STU SDK/cpp` on the target machine.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_wacom_signature_pad: ^1.0.0
```

```bash
flutter pub get
```

---

## Quick start

```dart
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';

WacomPdfSigner(
  pdfUrl:           'https://your-server.com/documents/contract.pdf',
  outputFileName:   'signed_contract.pdf',
  uploadUrl:        'https://your-server.com/api/upload-signed-pdf',
  token:            'your_auth_token',
  brandText:        'Your Company',
  onResult: (bool success) {
    if (success) {
      print('Document signed and uploaded');
    }
  },
)
```

That's it. The widget downloads the PDF, shows it in a viewer, lets the user drag
signature boxes onto any page, captures pen strokes from the Wacom STU tablet, embeds
the signature into the PDF, and uploads everything to your API.

---

## Widgets

### WacomPdfSigner

The primary drop-in widget. Handles the entire signing flow end-to-end.

```dart
WacomPdfSigner(
  // ── Required ──────────────────────────────────────────────────────────
  pdfUrl:         'https://your-server.com/pdf/contract.pdf',
  outputFileName: 'signed_contract.pdf',
  uploadUrl:      'https://your-server.com/api/upload-signed-pdf',
  token:          'your_auth_token_here',

  // ── Optional ──────────────────────────────────────────────────────────
  brandText:                  'HRMS E-Kiosk',
  logoAssetPath:              'assets/images/company_logo.png',
  trustSelfSignedCertificate: false,   // true for internal servers
  onResult: (bool success) { ... },
)
```

| Parameter | Type | Required | Default | Description |
|---|---|:---:|---|---|
| `pdfUrl` | `String` | ✅ | — | URL of the PDF to download and display |
| `outputFileName` | `String` | ✅ | — | Filename sent to your API |
| `uploadUrl` | `String` | ✅ | — | API endpoint that receives the signed PDF |
| `token` | `String` | ✅ | — | Auth token sent as the `token` multipart field |
| `onResult` | `void Function(bool)` | | `null` | Called with `true` on HTTP 2xx, `false` on failure |
| `logoAssetPath` | `String?` | | package logo | Asset path for the logo on the tablet idle screen |
| `brandText` | `String?` | | `'FlutterWacom'` | Text below the logo on the tablet idle screen |
| `trustSelfSignedCertificate` | `bool` | | `false` | `true` to accept self-signed SSL certificates |

#### What your API receives

```
POST https://your-server.com/api/upload-signed-pdf
Content-Type: multipart/form-data

token          → "your_auth_token_here"
outputfilename → "signed_contract.pdf"
filestream     → [signed PDF binary]
```

#### ASP.NET Core example

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

    string path = Path.Combine(_env.ContentRootPath, "pdf", outputfilename);
    System.IO.File.WriteAllBytes(path, bytes);
    return Ok();
}
```

---

### HomeScreen

A full document-management screen with a recent-documents list, URL/local file picker,
and a built-in Wacom connection button in the app bar.

```dart
// Use it directly as a full page
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const HomeScreen()),
);
```

No parameters — it is completely self-contained.

---

### PdfViewerScreen

The PDF viewer with signature-placement canvas. Use this when you already have a local
`File` and want to skip the download step.

```dart
import 'dart:io';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PdfViewerScreen(file: File('/path/to/document.pdf')),
  ),
);
```

| Parameter | Type | Required | Description |
|---|---|:---:|---|
| `file` | `File` | ✅ | The local PDF file to display and sign |

---

### SignatureDialog

A popup dialog that streams pen events from the Wacom STU tablet in real time.
Falls back to mouse/touch input if no tablet is connected.
Returns a `Uint8List` PNG on accept, or `null` on cancel.

```dart
import 'dart:typed_data';

final Uint8List? signature = await showDialog<Uint8List>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const SignatureDialog(
    brandText:     'Your Company',           // optional
    logoAssetPath: 'assets/images/logo.png', // optional
  ),
);

if (signature != null) {
  // Use the PNG bytes — embed, display, or upload
}
```

| Parameter | Type | Required | Description |
|---|---|:---:|---|
| `logoAssetPath` | `String?` | | Asset path for the tablet idle screen logo |
| `brandText` | `String?` | | Text below the logo on the tablet idle screen |

---

### SavedSignaturesDialog

A dialog for browsing previously captured signatures saved in local storage.
Returns the selected `Uint8List` PNG, or `null` if dismissed.

```dart
import 'dart:typed_data';

final Uint8List? selected = await showDialog<Uint8List>(
  context: context,
  builder: (_) => const SavedSignaturesDialog(),
);
```

No parameters.

---

### WacomConnectButton

A ready-made `IconButton` for use in an `AppBar`. Displays a USB icon — green when the
tablet is connected, black when disconnected. Tap to toggle.

```dart
AppBar(
  title: const Text('My App'),
  actions: const [WacomConnectButton()],
)
```

No parameters.

---

### SignatureBoxOverlay

A low-level widget that renders one interactive signature box on top of a canvas.
Supports drag-to-reposition, resize (bottom-right handle), delete (top-left ✕ button),
and tap-to-sign. Used internally by `PdfViewerScreen` — exported for custom signing UIs.

```dart
SignatureBoxOverlay(
  rect:           const Rect.fromLTWH(100, 200, 240, 80),
  signatureImage: myPngBytes,   // null → shows "Tap to Sign" placeholder
  onUpdate:  (Offset delta) { /* update position in state */ },
  onConfirm: ()             { /* open SignatureDialog */ },
  onDelete:  ()             { /* remove this box from state */ },
)
```

| Parameter | Type | Required | Description |
|---|---|:---:|---|
| `rect` | `Rect` | ✅ | Initial position and size of the signature box |
| `onUpdate` | `Function(Offset)` | ✅ | Called with drag delta while repositioning |
| `onConfirm` | `VoidCallback` | ✅ | Called when the user taps the box to sign |
| `onDelete` | `VoidCallback` | ✅ | Called when the user taps the ✕ button |
| `signatureImage` | `Uint8List?` | | PNG to display inside the box; `null` shows placeholder |

---

## SSL configuration

```dart
// Proper SSL (default — production servers)
WacomPdfSigner(
  trustSelfSignedCertificate: false,
  ...
)

// Self-signed SSL (internal corporate servers)
WacomPdfSigner(
  trustSelfSignedCertificate: true, // only use on trusted internal networks
  ...
)
```

---

## Custom branding on the tablet

```dart
WacomPdfSigner(
  logoAssetPath: 'assets/images/company_logo.png',
  brandText:     'HRMS E-Kiosk',
  ...
)
```

> The asset must be declared in **your app's** `pubspec.yaml`:
>
> ```yaml
> flutter:
>   assets:
>     - assets/images/company_logo.png
> ```

---

## Provider API

The package exposes its Riverpod providers so you can read tablet connection state
from your own widgets.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';

class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WacomConnectionState state = ref.watch(wacomConnectionProvider);

    return Column(
      children: [
        Text(state.isConnected ? 'Tablet connected' : 'Disconnected'),
        if (state.error != null)
          Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)),
        if (state.capabilities != null) ...[
          Text('Tablet max X: ${state.capabilities!['maxX']}'),
          Text('Tablet max Y: ${state.capabilities!['maxY']}'),
        ],
        ElevatedButton(
          onPressed: () => ref.read(wacomConnectionProvider.notifier).connect(),
          child: const Text('Connect'),
        ),
        OutlinedButton(
          onPressed: () => ref.read(wacomConnectionProvider.notifier).disconnect(),
          child: const Text('Disconnect'),
        ),
      ],
    );
  }
}
```

### WacomConnectionState

| Field | Type | Description |
|---|---|---|
| `isConnected` | `bool` | `true` after a successful `connect()` call |
| `error` | `String?` | Non-null when the last connect/disconnect threw |
| `capabilities` | `Map<String, dynamic>?` | `maxX`, `maxY`, `screenWidth`?, `screenHeight`? |

### recentFilesProvider

```dart
final AsyncValue<List<String>> files = ref.watch(recentFilesProvider);
```

Returns the list of recently opened PDF file paths from local storage.

---

## AppColors

All color constants used by the package's built-in UI — exported so your custom screens
can match the visual style.

| Constant | Hex | Usage |
|---|---|---|
| `AppColors.primary` | `#059669` | Primary buttons, icons |
| `AppColors.primaryDark` | `#047857` | Hover / pressed state |
| `AppColors.primaryLight` | `#34D399` | Accents |
| `AppColors.background` | `#F8FAFC` | Page background |
| `AppColors.surface` | `#FFFFFF` | Cards, dialogs |
| `AppColors.textPrimary` | `#0F172A` | Body text |
| `AppColors.textSecondary` | `#64748B` | Captions, labels |
| `AppColors.success` | `#10B981` | Success states |
| `AppColors.error` | `#EF4444` | Error states |
| `AppColors.border` | `#E2E8F0` | Card / input borders |

---

## FlutterFlow integration

`WacomPdfSigner` works in FlutterFlow out of the box because it creates its own
`ProviderScope` internally.

### Step 1 — Add the dependency

`Settings` → `Pubspec Dependencies` → add:

```
flutter_wacom_signature_pad: ^1.0.0
```

### Step 2 — Create a Custom Widget

`Custom Code` → `Custom Widgets` → `+ Add` → paste:

```dart
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';

class WacomSignerWidget extends StatelessWidget {
  const WacomSignerWidget({
    super.key,
    required this.width,
    required this.height,
    required this.pdfUrl,
    required this.outputFileName,
    required this.uploadUrl,
    required this.token,
    this.brandText,
    this.logoAssetPath,
    this.trustSelfSignedCertificate = false,
    this.onSuccess,
    this.onFailure,
  });

  final double width;
  final double height;
  final String pdfUrl;
  final String outputFileName;
  final String uploadUrl;
  final String token;
  final String? brandText;
  final String? logoAssetPath;
  final bool trustSelfSignedCertificate;
  final Future Function()? onSuccess;
  final Future Function()? onFailure;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: WacomPdfSigner(
        pdfUrl: pdfUrl,
        outputFileName: outputFileName,
        uploadUrl: uploadUrl,
        token: token,
        brandText: brandText,
        logoAssetPath: logoAssetPath,
        trustSelfSignedCertificate: trustSelfSignedCertificate,
        onResult: (success) {
          if (success) {
            onSuccess?.call();
          } else {
            onFailure?.call();
          }
        },
      ),
    );
  }
}
```

### Step 3 — Set parameters in FlutterFlow

| Parameter | Type | Notes |
|---|---|---|
| `pdfUrl` | String | URL of the PDF to sign |
| `outputFileName` | String | e.g. `signed_contract.pdf` |
| `uploadUrl` | String | Your API endpoint |
| `token` | String | Auth token |
| `brandText` | String | Optional — tablet idle screen text |
| `logoAssetPath` | String | Optional — tablet idle screen logo |
| `trustSelfSignedCertificate` | Boolean | `true` for internal servers |
| `onSuccess` | Action | Runs after successful upload |
| `onFailure` | Action | Runs after failed upload |

### Other widgets in FlutterFlow

| Widget | How to use | Parameters |
|---|---|---|
| `HomeScreen` | Custom Widget | width, height only |
| `WacomConnectButton` | Custom Widget | width, height only |
| `SignatureDialog` | Custom Action | `brandText`, `logoAssetPath` |
| `SavedSignaturesDialog` | Custom Action | none |

---

## Architecture

```
flutter_wacom_signature_pad
├── WacomPdfSigner           ← drop-in widget (own ProviderScope)
│   ├── PdfViewerScreen      ← SfPdfViewer + signature box canvas
│   │   └── SignatureBoxOverlay  ← drag / resize / delete / sign
│   ├── SignatureDialog      ← Wacom pen → Uint8List PNG
│   └── SavedSignaturesDialog
│
├── HomeScreen               ← standalone home UI
│   └── WacomConnectButton   ← app bar toggle
│
├── Services
│   ├── WacomService         ← MethodChannel / EventChannel bridge
│   ├── PdfService           ← PDF manipulation (syncfusion)
│   ├── FileService          ← file_picker wrapper
│   ├── RecentFilesService   ← SharedPreferences
│   └── SignatureStorageService ← local PNG storage
│
└── Riverpod Providers
    ├── wacomConnectionProvider   ← connect / disconnect / capabilities
    └── recentFilesProvider       ← recent PDF paths
```

The native layer (`wacom_stu_plugin`) communicates over two platform channels:

| Channel | Type | Methods / Events |
|---|---|---|
| `wacom_stu_channel` | MethodChannel | `connect`, `disconnect`, `clearScreen`, `setSignatureScreen` |
| `wacom_stu_events` | EventChannel | pen events: `x`, `y`, `pressure`, `sw` |

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

MIT — see [LICENSE](LICENSE).
