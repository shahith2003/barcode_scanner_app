// home_screen.dart
// Physical button support for Urovo DT50S:
//   - "onScanButtonPressed" → physical button was pressed → open camera scanner
//   - "onBarcodeScanned"   → decode result received → show on screen directly

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? scannedResult;
  String? barcodeType;
  bool isLoading = false;
  final List<Map<String, String>> scanHistory = [];

  // MethodChannel — must match MainActivity.kt exactly
  static const _scannerChannel = MethodChannel(
    'com.example.barcode_scanner_app/scanner',
  );

  @override
  void initState() {
    super.initState();
    _setupChannel();
  }

  // ── _setupChannel() ────────────────────────────────────────────────────
  // Listens for two events from Android:
  //   1. "onScanButtonPressed" → physical button pressed → open camera
  //   2. "onBarcodeScanned"   → decode result from device laser → show result
  void _setupChannel() {
    _scannerChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {

      // Physical scan button was pressed
      // → open the camera-based scanner (same as tapping the on-screen button)
        case 'onScanButtonPressed':
          if (!isLoading && mounted) {
            openScanner();
          }
          break;

      // The DT50S laser already scanned a barcode and is giving us the result
      // → show it directly on screen without opening the camera
        case 'onBarcodeScanned':
          final String value = call.arguments as String;
          if (mounted) {
            _handleResult(value, 'Hardware Scanner');
          }
          break;
      }
    });
  }

  // ── _handleResult() ──────────────────────────────────────────────────
  // Shared handler — called by both hardware scan and camera scan.
  void _handleResult(String value, String type) {
    if (value.isEmpty) return;
    setState(() {
      scannedResult = value;
      barcodeType = type;
      isLoading = false;

      scanHistory.insert(0, {
        'value': value,
        'type': type,
        'time': _getCurrentTime(),
      });
      if (scanHistory.length > 5) scanHistory.removeLast();
    });
  }

  // ── openScanner() ─────────────────────────────────────────────────────
  // Opens the camera-based scanner screen.
  // Called by both on-screen button tap and physical button press.
  Future<void> openScanner() async {
    setState(() => isLoading = true);

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (result != null && result['value'] != null) {
      _handleResult(result['value']!, result['type'] ?? 'Camera Scan');
    } else {
      setState(() => isLoading = false);
    }
  }

  void scanAgain() {
    setState(() {
      scannedResult = null;
      barcodeType = null;
    });
  }

  void copyToClipboard() {
    if (scannedResult == null) return;
    Clipboard.setData(ClipboardData(text: scannedResult!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Barcode Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.indigo),
            const SizedBox(height: 12),
            const Text(
              'Scan any barcode or QR code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Press the physical scan button — or tap below to use camera',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (scannedResult == null)
              _buildScanButton()
            else
              _buildResultSection(),

            const SizedBox(height: 30),
            if (scanHistory.isNotEmpty) _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return ElevatedButton.icon(
      onPressed: openScanner,
      icon: const Icon(Icons.camera_alt, size: 28),
      label: const Text(
        'Use Camera to Scan',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text('Scan Result',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ]),
                const Divider(height: 20),
                Text('Source: $barcodeType',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                SelectableText(
                  scannedResult!,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: copyToClipboard,
          icon: const Icon(Icons.copy),
          label: const Text('Copy to Clipboard'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Colors.indigo),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: scanAgain,
          icon: const Icon(Icons.refresh),
          label: const Text('Scan Again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Scans',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: scanHistory.length,
          itemBuilder: (context, index) {
            final item = scanHistory[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  item['type'] == 'Hardware Scanner'
                      ? Icons.barcode_reader
                      : Icons.camera_alt,
                  color: Colors.indigo,
                ),
                title: Text(item['value'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text('${item['type']} • ${item['time']}',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: item['value'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied from history!'),
                      duration: Duration(seconds: 1)));
                },
              ),
            );
          },
        ),
      ],
    );
  }
}