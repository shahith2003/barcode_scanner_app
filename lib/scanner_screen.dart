// ─────────────────────────────────────────────────────────────────────────────
// scanner_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// This screen handles:
//   1. Checking if camera permission is granted
//   2. Showing the live camera preview
//   3. Detecting barcodes and QR codes automatically
//   4. Returning the result back to HomeScreen
//   5. Preventing multiple scan triggers
//   6. Vibrating the phone on a successful scan
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // The scanner package
import 'package:permission_handler/permission_handler.dart'; // Camera permissions
import 'package:vibration/vibration.dart'; // Haptic feedback

// ─────────────────────────────────────────────────────────────────────────────
// ScannerScreen — StatefulWidget
// ─────────────────────────────────────────────────────────────────────────────
// We need StatefulWidget here because:
//   - We track whether permission is granted/denied
//   - We track whether a barcode has already been detected (to prevent repeats)
//   - We control the scanner camera lifecycle (start/stop)
// ─────────────────────────────────────────────────────────────────────────────
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // ── State Variables ──────────────────────────────────────────────────────

  // MobileScannerController manages the camera and scanning logic.
  // We create it once and reuse it throughout this screen.
  late MobileScannerController scannerController;

  // Tracks whether the user has granted camera permission
  bool hasPermission = false;

  // Tracks whether permission check is still in progress
  bool isCheckingPermission = true;

  // ⚠️ IMPORTANT: This flag prevents the scan from triggering multiple times.
  // Without it, the scanner could detect the same barcode 10+ times per second!
  bool hasScanned = false;

  // ── initState() ──────────────────────────────────────────────────────────
  // initState() runs ONCE when this screen first appears.
  // Use it to initialize things (like requesting permissions).
  @override
  void initState() {
    super.initState(); // Always call super.initState() first

    // Initialize the scanner controller
    // detectionSpeed: balanced = not too fast, not too slow
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back, // Use the back camera
    );

    // Request camera permission when this screen opens
    _checkAndRequestPermission();
  }

  // ── dispose() ────────────────────────────────────────────────────────────
  // dispose() runs when this screen is removed from the screen stack.
  // ALWAYS dispose controllers to free up memory and stop the camera.
  // If you forget this, the camera keeps running in the background!
  @override
  void dispose() {
    scannerController.dispose(); // Stop camera, free resources
    super.dispose(); // Always call super.dispose() last
  }

  // ── _checkAndRequestPermission() ─────────────────────────────────────────
  // Checks current permission status and requests it if not granted.
  //
  // Permission states:
  //   granted        → user said YES, we can use camera
  //   denied         → user said NO (can ask again)
  //   permanentlyDenied → user said NO and checked "Don't ask again"
  Future<void> _checkAndRequestPermission() async {
    // Check current permission status (without asking yet)
    final status = await Permission.camera.status;

    if (status.isGranted) {
      // Permission already granted — go straight to scanning
      setState(() {
        hasPermission = true;
        isCheckingPermission = false;
      });
    } else if (status.isPermanentlyDenied) {
      // User permanently denied — send them to system Settings
      setState(() {
        hasPermission = false;
        isCheckingPermission = false;
      });
    } else {
      // Permission not yet asked — request it now
      final result = await Permission.camera.request();

      setState(() {
        hasPermission = result.isGranted;
        isCheckingPermission = false;
      });
    }
  }

  // ── _onBarcodeDetected() ─────────────────────────────────────────────────
  // This function is called AUTOMATICALLY by MobileScanner
  // every time it finds a barcode in the camera frame.
  //
  // Parameters:
  //   capture — a BarcodeCapture object containing all detected barcodes
  void _onBarcodeDetected(BarcodeCapture capture) {
    // ⛔ Guard clause: if we already scanned, ignore this call
    // This is the "prevent multiple scans" feature
    if (hasScanned) return;

    // capture.barcodes is a list of all barcodes found in this frame
    final barcodes = capture.barcodes;

    // Make sure at least one barcode was found and it has a value
    if (barcodes.isEmpty) return;
    final barcode = barcodes.first;

    final rawValue = barcode.rawValue; // The actual text/number in the barcode
    if (rawValue == null || rawValue.isEmpty) return;

    // ✅ We found a valid barcode!
    // Set hasScanned = true IMMEDIATELY to block any future calls
    hasScanned = true;

    // Stop the camera (no need to keep scanning)
    scannerController.stop();

    // Vibrate the phone to give physical feedback
    _vibrate();

    // Get the barcode format as a readable string
    // e.g., BarcodeFormat.qrCode → "QR Code"
    final barcodeType = _getBarcodeTypeName(barcode.format);

    // Navigator.pop() goes back to the previous screen (HomeScreen).
    // We pass the result as a Map so HomeScreen can receive it.
    // This is how Flutter screens communicate their results.
    Navigator.pop(context, {
      'value': rawValue,
      'type': barcodeType,
    });
  }

  // ── _vibrate() ───────────────────────────────────────────────────────────
  // Makes the phone vibrate for 200 milliseconds.
  // hasVibrator() checks if the device supports vibration first.
  Future<void> _vibrate() async {
    final canVibrate = await Vibration.hasVibrator();
    if (canVibrate == true) {
      Vibration.vibrate(duration: 200); // 200 milliseconds
    }
  }

  // ── _getBarcodeTypeName() ─────────────────────────────────────────────────
  // Converts the BarcodeFormat enum into a human-readable string.
  // BarcodeFormat is an enum from the mobile_scanner package.
  String _getBarcodeTypeName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.ean13:
        return 'EAN-13'; // Standard product barcode (13 digits)
      case BarcodeFormat.ean8:
        return 'EAN-8'; // Short product barcode (8 digits)
      case BarcodeFormat.code128:
        return 'Code 128'; // Common 1D barcode used in shipping
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.upcA:
        return 'UPC-A'; // US product barcode
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.pdf417:
        return 'PDF417'; // Used in IDs and boarding passes
      case BarcodeFormat.aztec:
        return 'Aztec'; // Used in train/plane tickets
      default:
        return 'Barcode'; // Fallback for unknown types
    }
  }

  // ── build() ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── AppBar ─────────────────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          // Back button — closes scanner and returns to HomeScreen
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, null), // null = no result
        ),
      ),

      backgroundColor: Colors.black,

      // ── Body: show different content based on state ─────────────────────
      body: _buildBody(),
    );
  }

  // ── _buildBody() ─────────────────────────────────────────────────────────
  // Decides which screen content to show:
  //   • Loading spinner → while checking permission
  //   • Permission denied → error message + retry button
  //   • Camera view → when permission granted
  Widget _buildBody() {
    // Still checking permission — show a loading spinner
    if (isCheckingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Permission denied — explain why and show options
    if (!hasPermission) {
      return _buildPermissionDeniedView();
    }

    // Permission granted — show the camera scanner
    return _buildScannerView();
  }

  // ── _buildPermissionDeniedView() ─────────────────────────────────────────
  // Shows an error message when camera permission is denied.
  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center vertically
          children: [
            // Warning icon
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white54),
            const SizedBox(height: 20),

            // Error title
            const Text(
              'Camera Permission Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Error description
            const Text(
              'This app needs camera access to scan barcodes and QR codes.\n\n'
                  'Please grant camera permission to continue.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Button to open system Settings (for permanently denied case)
            ElevatedButton.icon(
              onPressed: () async {
                // openAppSettings() opens this app's page in system Settings
                await openAppSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            const SizedBox(height: 12),

            // Button to retry permission request (for denied but re-askable case)
            TextButton(
              onPressed: () {
                setState(() => isCheckingPermission = true);
                _checkAndRequestPermission();
              },
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white70),
              ),
            ),

            const SizedBox(height: 12),

            // Go back without scanning
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── _buildScannerView() ───────────────────────────────────────────────────
  // Shows the live camera feed with a scanning overlay.
  Widget _buildScannerView() {
    return Stack(
      // Stack layers widgets on top of each other
      children: [
        // ── Layer 1: The Camera Preview ────────────────────────────────
        // MobileScanner fills the full screen with the live camera feed.
        // onDetect is called whenever a barcode is found in the frame.
        MobileScanner(
          controller: scannerController,
          onDetect: _onBarcodeDetected, // Our scan handler
        ),

        // ── Layer 2: The Scanning Overlay ──────────────────────────────
        // This sits on top of the camera preview.
        // It shows a "viewfinder" and instructions.
        _buildScanOverlay(),
      ],
    );
  }

  // ── _buildScanOverlay() ───────────────────────────────────────────────────
  // The visual overlay on top of the camera:
  //   • Semi-transparent dark areas around the scan area
  //   • A bright square "viewfinder" in the center
  //   • Instruction text at the bottom
  Widget _buildScanOverlay() {
    return Column(
      children: [
        // Top dark area
        Expanded(
          flex: 1, // Takes 1 fraction of available space
          child: Container(color: Colors.black54),
        ),

        // Middle row: dark | viewfinder | dark
        Row(
          children: [
            // Left dark area
            Expanded(child: Container(color: Colors.black54)),

            // The viewfinder square — where the user should point the camera
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.indigo,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            // Right dark area
            Expanded(child: Container(color: Colors.black54)),
          ],
        ),

        // Bottom area: dark + instruction text
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white70, size: 32),
                  SizedBox(height: 10),
                  Text(
                    'Point camera at a barcode or QR code',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Scanning will happen automatically',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
