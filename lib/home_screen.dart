// home_screen.dart
// Now includes: HTTP POST to Flask API when a barcode is scanned

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; // ← HTTP package for API calls
import 'dart:convert'; // ← For jsonEncode / jsonDecode
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
  bool isSaving = false; // True while sending to Flask API
  String? saveStatus;    // "saved" | "error" | null — shown below result

  final List<Map<String, String>> scanHistory = [];

  // ── Flask API URL ──────────────────────────────────────────────────────
  // Replace 192.168.1.105 with YOUR computer's actual IPv4 address.
  // Run "ipconfig" in Command Prompt to find it.
  // Port 5000 is where Flask runs by default.
  static const String _apiUrl = 'http://172.16.2.236:5000/save-barcode';

  // ── MethodChannel — talks to MainActivity.kt ───────────────────────────
  static const _scannerChannel = MethodChannel(
    'com.example.barcode_scanner_app/scanner',
  );

  @override
  void initState() {
    super.initState();
    _setupChannel();
  }

  // ── _setupChannel() ───────────────────────────────────────────────────
  void _setupChannel() {
    _scannerChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onScanButtonPressed':
          if (!isLoading && mounted) openScanner();
          break;
        case 'onBarcodeScanned':
          final String value = call.arguments as String;
          if (mounted) _handleResult(value, 'Hardware Scanner');
          break;
      }
    });
  }

  // ── _handleResult() ───────────────────────────────────────────────────
  // Called after every successful scan (hardware or camera).
  // Shows the result on screen then immediately saves to SQL Server via Flask.
  void _handleResult(String value, String type) {
    if (value.isEmpty) return;

    setState(() {
      scannedResult = value;
      barcodeType = type;
      isLoading = false;
      saveStatus = null; // reset status from previous scan

      scanHistory.insert(0, {
        'value': value,
        'type': type,
        'time': _getCurrentTime(),
      });
      if (scanHistory.length > 5) scanHistory.removeLast();
    });

    // Save to SQL Server via Flask immediately after scan
    _saveToDatabase(value);
  }

  // ── _saveToDatabase() ─────────────────────────────────────────────────
  // Sends the scanned barcode to the Flask API via HTTP POST.
  // Flask then inserts it into SQL Server.
  //
  // Flow:
  //   Flutter → POST /save-barcode → Flask (Python) → SQL Server
  Future<void> _saveToDatabase(String barcode) async {
    setState(() => isSaving = true);

    try {
      // http.post() sends an HTTP POST request to the Flask server
      final response = await http.post(
        Uri.parse(_apiUrl),

        // Tell Flask we are sending JSON data
        headers: {'Content-Type': 'application/json'},

        // jsonEncode converts the Dart Map into a JSON string:
        // {'barcode': '12345678'} → '{"barcode":"12345678"}'
        body: jsonEncode({'barcode': barcode}),
      ).timeout(
        // If no response in 10 seconds, throw a timeout error
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out'),
      );

      if (response.statusCode == 200) {
        // ✅ Flask returned 200 OK — barcode was saved to SQL Server
        setState(() => saveStatus = 'saved');
      } else {
        // Flask returned an error status code
        setState(() => saveStatus = 'error');
        debugPrint('Server error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Network error, timeout, or Flask not running
      setState(() => saveStatus = 'error');
      debugPrint('Save failed: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ── openScanner() ─────────────────────────────────────────────────────
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
      saveStatus = null;
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
        // ── Scanned Value Card ────────────────────────────────────────
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

        const SizedBox(height: 10),

        // ── Database Save Status ──────────────────────────────────────
        // Shows a small indicator: saving spinner, saved ✅, or error ❌
        if (isSaving)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Saving to database...',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )
        else if (saveStatus == 'saved')
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_done, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text('Saved to SQL Server',
                  style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          )
        else if (saveStatus == 'error')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                const Text('Could not save to database ❌',
                    style: TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(width: 8),
                // Retry button — tries to save again without rescanning
                GestureDetector(
                  onTap: () => _saveToDatabase(scannedResult!),
                  child: const Text('Retry',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),

        const SizedBox(height: 12),

        // ── Action Buttons ────────────────────────────────────────────
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Scans',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  scanHistory.clear();
                });
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text(
                'Clear All',
                style: TextStyle(fontSize: 13, color: Colors.black38),
              ),
            ),
          ],
        ),
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
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
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