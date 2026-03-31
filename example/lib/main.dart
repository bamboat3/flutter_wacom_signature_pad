import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });

  runApp(const ProviderScope(child: ExampleApp()));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_wacom_signature_pad — Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const ExampleMenuScreen(),
      routes: {
        '/wacom-pdf-signer': (_) => const WacomPdfSignerDemo(),
        '/home-screen': (_) => const HomeScreenDemo(),
        '/connection': (_) => const ConnectionDemo(),
        '/signature-dialog': (_) => const SignatureDialogDemo(),
        '/self-signed-ssl': (_) => const SelfSignedSslDemo(),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Menu
// ---------------------------------------------------------------------------

class ExampleMenuScreen extends StatelessWidget {
  const ExampleMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = [
      _Demo(
        title: 'WacomPdfSigner',
        subtitle: 'Drop-in widget: download PDF, place signatures, upload',
        route: '/wacom-pdf-signer',
        icon: Icons.draw_outlined,
      ),
      _Demo(
        title: 'HomeScreen',
        subtitle: 'Built-in home screen with recent documents list',
        route: '/home-screen',
        icon: Icons.home_outlined,
      ),
      _Demo(
        title: 'Connection Management',
        subtitle: 'WacomConnectButton + wacomConnectionProvider',
        route: '/connection',
        icon: Icons.usb_outlined,
      ),
      _Demo(
        title: 'SignatureDialog',
        subtitle: 'Standalone signature capture dialog',
        route: '/signature-dialog',
        icon: Icons.edit_outlined,
      ),
      _Demo(
        title: 'Self-Signed SSL',
        subtitle: 'trustSelfSignedCertificate: true for internal servers',
        route: '/self-signed-ssl',
        icon: Icons.lock_outline,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_wacom_signature_pad — Examples'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: demos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final demo = demos[i];
          return Card(
            child: ListTile(
              leading: Icon(demo.icon, color: AppColors.primary),
              title: Text(demo.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(demo.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, demo.route),
            ),
          );
        },
      ),
    );
  }
}

class _Demo {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  const _Demo(
      {required this.title,
      required this.subtitle,
      required this.route,
      required this.icon});
}

// ---------------------------------------------------------------------------
// Demo 1: WacomPdfSigner
// ---------------------------------------------------------------------------

/// The primary use-case: embed WacomPdfSigner anywhere in your app.
///
/// It downloads the PDF, shows it in a viewer, lets the user drag
/// signature boxes onto any page, captures pen input from the Wacom STU
/// tablet, embeds the signature into the PDF, and uploads the result to
/// your API endpoint.
class WacomPdfSignerDemo extends StatefulWidget {
  const WacomPdfSignerDemo({super.key});

  @override
  State<WacomPdfSignerDemo> createState() => _WacomPdfSignerDemoState();
}

class _WacomPdfSignerDemoState extends State<WacomPdfSignerDemo> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WacomPdfSigner Demo')),
      body: Column(
        children: [
          if (_result != null)
            MaterialBanner(
              content: Text(_result!),
              leading: Icon(
                _result == 'Upload succeeded'
                    ? Icons.check_circle
                    : Icons.error,
                color: _result == 'Upload succeeded'
                    ? AppColors.success
                    : AppColors.error,
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _result = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: WacomPdfSigner(
              // The PDF to sign — replace with your own URL
              pdfUrl: 'https://www.w3.org/WAI/WCAG21/wcag-2.1.pdf',

              // Filename your API uses when saving the file to disk
              outputFileName: 'signed_document.pdf',

              // Your API endpoint that receives the signed PDF
              uploadUrl: 'https://your-server.com/api/upload-signed-pdf',

              // Auth token sent as the `token` multipart field
              token: 'your_auth_token_here',

              // Optional — logo shown on the Wacom tablet idle screen
              // Must also be declared in YOUR app's pubspec.yaml assets
              // logoAssetPath: 'assets/images/your_logo.png',

              // Optional — text below the logo on the tablet idle screen
              brandText: 'Example App',

              // true = trust self-signed SSL certs (internal servers only)
              trustSelfSignedCertificate: false,

              onResult: (bool success) {
                setState(() {
                  _result = success ? 'Upload succeeded' : 'Upload failed';
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 2: HomeScreen (built-in)
// ---------------------------------------------------------------------------

/// HomeScreen is a full document-management UI included in the package.
/// It shows a recent-documents list, lets users open local or URL-based
/// PDFs, and has a WacomConnectButton in the app bar.
///
/// It wraps itself with ProviderScope, so no extra setup is needed.
class HomeScreenDemo extends StatelessWidget {
  const HomeScreenDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HomeScreen Demo')),
      body: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 3: Manual connection management
// ---------------------------------------------------------------------------

/// Shows how to read Wacom connection state and drive connect/disconnect
/// manually — useful when you want to show connection status in your own UI.
class ConnectionDemo extends ConsumerWidget {
  const ConnectionDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wacomConnectionProvider);
    final notifier = ref.read(wacomConnectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Management'),
        // WacomConnectButton is a ready-made icon button for the app bar.
        // It shows a USB icon, green when connected and black when not.
        actions: const [WacomConnectButton()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.isConnected ? Icons.usb : Icons.usb_off,
              size: 64,
              color: state.isConnected ? AppColors.success : AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              state.isConnected ? 'Connected' : 'Disconnected',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
            if (state.capabilities != null) ...[
              const SizedBox(height: 16),
              Text('Max X: ${state.capabilities!['maxX']}'),
              Text('Max Y: ${state.capabilities!['maxY']}'),
              if (state.capabilities!['screenWidth'] != null)
                Text('Screen: ${state.capabilities!['screenWidth']} × '
                    '${state.capabilities!['screenHeight']}'),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      state.isConnected ? null : () => notifier.connect(),
                  icon: const Icon(Icons.usb),
                  label: const Text('Connect'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed:
                      state.isConnected ? () => notifier.disconnect() : null,
                  icon: const Icon(Icons.usb_off),
                  label: const Text('Disconnect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 4: Standalone SignatureDialog
// ---------------------------------------------------------------------------

/// SignatureDialog is a popup that streams pen data from the Wacom STU
/// tablet. When the user accepts, it returns a Uint8List PNG image.
/// Falls back to mouse/touch input if the tablet is not connected.
class SignatureDialogDemo extends StatefulWidget {
  const SignatureDialogDemo({super.key});

  @override
  State<SignatureDialogDemo> createState() => _SignatureDialogDemoState();
}

class _SignatureDialogDemoState extends State<SignatureDialogDemo> {
  // ignore: unused_field
  dynamic _capturedSignature; // Uint8List in real usage

  Future<void> _openSignatureDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SignatureDialog(
        // Optional — logo shown on the Wacom tablet idle screen.
        // logoAssetPath: 'assets/images/company_logo.png',
        brandText: 'Example App',
      ),
    );
    if (result != null && mounted) {
      setState(() => _capturedSignature = result);
    }
  }

  Future<void> _openSavedSignatures() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const SavedSignaturesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SignatureDialog Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Open a dialog to capture a signature from the\n'
              'Wacom STU tablet (or mouse/touch as fallback).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openSignatureDialog,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Capture Signature'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openSavedSignatures,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Browse Saved Signatures'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 5: Self-signed SSL
// ---------------------------------------------------------------------------

/// For internal corporate servers that use a self-signed SSL certificate,
/// set trustSelfSignedCertificate: true.
///
/// Warning: only use this on trusted internal networks.
class SelfSignedSslDemo extends StatelessWidget {
  const SelfSignedSslDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Self-Signed SSL Demo')),
      body: WacomPdfSigner(
        pdfUrl: 'https://internal.company.local/pdf/contract.pdf',
        outputFileName: 'signed_contract.pdf',
        uploadUrl: 'https://internal.company.local/api/upload-signed-pdf',
        token: 'your_auth_token_here',
        brandText: 'Internal HRMS',

        // ← This is the only difference from the default setup.
        // Allows the HTTP client to accept self-signed certificates.
        trustSelfSignedCertificate: true,

        onResult: (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(success ? 'Upload succeeded' : 'Upload failed'),
              backgroundColor:
                  success ? AppColors.success : AppColors.error,
            ),
          );
        },
      ),
    );
  }
}
