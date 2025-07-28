import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Defines the main accent and theme colors.
const Color kPrimaryColor = Color(0xFF2196F3);
const Color kSecondaryColor = Color(0xFF03A9F4);
const Color kAccentColor = Color(0xFFFF9800);

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => QrHistoryProvider(),
      child: const MyApp(),
    ),
  );
}

/// PUBLIC_INTERFACE
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Builds the main MaterialApp with the light, modern theme.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scanner',
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme(
          primary: kPrimaryColor,
          secondary: kSecondaryColor,
          surface: Colors.white,
          background: Colors.white,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: kAccentColor,
          foregroundColor: Colors.white,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.grey.shade50,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: kPrimaryColor,
          selectionColor: kSecondaryColor.withOpacity(0.5),
          selectionHandleColor: kPrimaryColor,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kSecondaryColor,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        buttonTheme: const ButtonThemeData(
          buttonColor: kAccentColor,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

/// Provider for QR code scan history — kept in memory.
class QrHistoryProvider with ChangeNotifier {
  final List<String> _history = [];

  List<String> get history => List.unmodifiable(_history);

  /// Adds a result to the history, preventing duplicates-in-row.
  void add(String result) {
    if (_history.isEmpty || _history.last != result) {
      _history.add(result);
      notifyListeners();
    }
  }

  void clear() {
    _history.clear();
    notifyListeners();
  }
}

/// Main screen housing camera, scan button, results, navigation drawer.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// Main screen state manages camera controller, result, etc.
class _MainScreenState extends State<MainScreen> {
  String? _scanResult;
  bool _processing = false;
  final MobileScannerController _cameraController = MobileScannerController();

  /// Opens a URL if valid, using url_launcher; shows error otherwise.
  Future<void> _launchUrl(String value) async {
    Uri? uri;
    try {
      uri = Uri.parse(value);
      // If no scheme, try to add https://
      if (uri.scheme.isEmpty && uri.host.isEmpty && value.contains('.')) {
        uri = Uri.parse('https://$value');
      }
      if (!await canLaunchUrl(uri)) {
        throw Exception('Cannot launch $uri');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnackBar("Could not open as URL", isError: true);
    }
  }

  /// Copies text to clipboard with feedback.
  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    _showSnackBar('Copied to clipboard!');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : kSecondaryColor,
      ),
    );
  }

  /// Handles the result from camera scanning.
  void _onDetect(BarcodeCapture barcode) {
    if (_processing) return;
    final value = barcode.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) {
      _showSnackBar("No QR code detected.", isError: true);
      return;
    }
    setState(() {
      _scanResult = value;
      _processing = true;
    });
    Provider.of<QrHistoryProvider>(context, listen: false).add(value);
    // Prevent scanning multiple times in row:
    Future.delayed(const Duration(seconds: 1)).then((_) {
      setState(() {
        _processing = false;
      });
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  /// Returns true if the string appears to be a URL.
  bool _looksLikeUrl(String s) =>
      s.startsWith('http://') ||
      s.startsWith('https://') ||
      (s.contains('.') && !s.contains(' '));

  @override
  Widget build(BuildContext context) {
    final historyProvider = Provider.of<QrHistoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        centerTitle: true,
      ),
      drawer: _AppDrawer(
        onSelectHistory: () => _openHistory(context, historyProvider.history),
        onClearHistory: () => historyProvider.clear(),
      ),
      body: Column(
        children: [
          /// Camera preview area
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: kSecondaryColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  color: Colors.grey[50]!,
                  child: MobileScanner(
                    controller: _cameraController,
                    allowDuplicates: false,
                    onDetect: _processing ? null : _onDetect,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          /// Scan Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: kAccentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
            ),
            onPressed: _processing
                ? null
                : () async {
                    setState(() => _processing = true);
                    try {
                      await _cameraController.start();
                    } catch (_) {}
                    setState(() => _processing = false);
                  },
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text(
              "Scan QR Code",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(height: 14),

          /// Scan result area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: _QrResultArea(
              result: _scanResult,
              onCopy: _scanResult == null ? null : () => _copyToClipboard(_scanResult!),
              onOpenUrl: (_scanResult != null && _looksLikeUrl(_scanResult!))
                  ? () => _launchUrl(_scanResult!)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the history screen as a modal.
  void _openHistory(BuildContext context, List<String> history) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(history: history)),
    );
  }
}

/// Drawer widget for navigation and options/history.
class _AppDrawer extends StatelessWidget {
  final VoidCallback onSelectHistory;
  final VoidCallback onClearHistory;

  const _AppDrawer({
    required this.onSelectHistory,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            DrawerHeader(
              padding: const EdgeInsets.all(0),
              margin: EdgeInsets.zero,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryColor, kSecondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    "QR Scanner",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: kPrimaryColor),
              title: const Text("History"),
              onTap: () {
                Navigator.of(context).pop(); // close drawer
                onSelectHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kAccentColor),
              title: const Text("Clear History"),
              onTap: () {
                Navigator.of(context).pop();
                onClearHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("History cleared")),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline, color: kSecondaryColor),
              title: const Text("About"),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "QR Scanner",
                  applicationVersion: "1.0.0",
                  applicationLegalese:
                      "© ${(DateTime.now().year)} Your Company. All rights reserved.",
                  children: [
                    const Text(
                        "A modern mobile app for scanning QR codes. Built with Flutter."),
                  ],
                );
                Navigator.of(context).pop();
              },
            )
          ],
        ),
      ),
    );
  }
}

/// Widget displaying QR scan result, with copy and open buttons.
class _QrResultArea extends StatelessWidget {
  final String? result;
  final VoidCallback? onCopy;
  final VoidCallback? onOpenUrl;

  const _QrResultArea({
    required this.result,
    this.onCopy,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const Card(
        elevation: 2,
        color: Color(0xFFF7F7F9),
        child: SizedBox(
          width: double.infinity,
          height: 70,
          child: Center(
            child: Text(
              "Scan a QR code to see the result here.",
              style: TextStyle(color: kPrimaryColor, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final isUrl = result!.startsWith('http://') ||
        result!.startsWith('https://') ||
        (result!.contains('.') && !result!.contains(' '));

    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Result",
              style: TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                result!,
                style: const TextStyle(fontSize: 16),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: kAccentColor),
                  label: const Text("Copy", style: TextStyle(color: kAccentColor)),
                  onPressed: onCopy,
                ),
                if (isUrl) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                    label: const Text("Open"),
                    onPressed: onOpenUrl,
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen displaying the list of previous scan results (in memory).
class HistoryScreen extends StatelessWidget {
  final List<String> history;

  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan History"),
        backgroundColor: kSecondaryColor,
      ),
      body: history.isEmpty
          ? const Center(
              child: Text(
                "No history yet.",
                style: TextStyle(fontSize: 16, color: kPrimaryColor),
              ),
            )
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => Divider(
                    color: Colors.grey.shade200, height: 1, thickness: 1),
              itemBuilder: (context, idx) {
                final value = history[idx];
                final isUrl = value.startsWith('http://') ||
                    value.startsWith('https://') ||
                    (value.contains('.') && !value.contains(' '));
                return ListTile(
                  leading: Icon(
                    isUrl ? Icons.link : Icons.text_snippet_outlined,
                    color: isUrl ? kPrimaryColor : kAccentColor,
                  ),
                  title: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: kAccentColor),
                        tooltip: "Copy",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Copied to clipboard")));
                        },
                      ),
                      if (isUrl)
                        IconButton(
                          icon: const Icon(Icons.open_in_browser_rounded,
                              color: kPrimaryColor),
                          tooltip: "Open",
                          onPressed: () async {
                            Uri? uri = Uri.tryParse(value);
                            if ((uri == null ||
                                (!uri.hasScheme &&
                                    value.contains('.') &&
                                    !value.contains(' ')))) {
                              uri = Uri.parse('https://$value');
                            }
                            if (await canLaunchUrl(uri!)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Could not open")));
                            }
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Helper for clipboard in a cross-platform way.
class Clipboard {
  /// PUBLIC_INTERFACE
  static Future<void> setData(ClipboardData data) async {
    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/platform',
      const StandardMethodCodec().encodeMethodCall(MethodCall(
        'Clipboard.setData',
        <String, dynamic>{'text': data.text},
      )),
      (_) {},
    );
  }
}

class ClipboardData {
  final String? text;
  ClipboardData({this.text});
}

// PUBLIC_INTERFACE
/// Helper function for firstOrNull.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
