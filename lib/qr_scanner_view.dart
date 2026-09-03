import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'styles.dart';

/// A full‑screen QR scanner widget.
///
/// Handles camera permissions, shows loading/error states, and emits a single
/// scan result before pausing the camera and navigating back.
class QRScannerView extends StatefulWidget {
  const QRScannerView({required this.onScanned, super.key});
  final ValueChanged<String> onScanned;

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;
  bool _torchEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Updated to match the `BarcodeCapture` signature from the latest mobile_scanner package.
  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return; // Prevent multiple callbacks.
    // Use the first detected barcode.
    final Barcode? barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null) return;
    final String? raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;
    setState(() => _hasScanned = true);
    _controller.stop();
    widget.onScanned(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan parking QR', style: AppText.screenTitle),
        actions: [
          IconButton(
            tooltip: _torchEnabled ? 'Turn off flashlight' : 'Turn on flashlight',
            icon: Icon(_torchEnabled ? Icons.flashlight_off : Icons.flashlight_on),
            onPressed: () {
              setState(() => _torchEnabled = !_torchEnabled);
              _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        // `allowDuplicates` is no longer a valid parameter in recent versions of mobile_scanner.
        // The scanner will emit a capture containing one or more barcodes.
            onDetect: (BarcodeCapture capture) => _handleBarcode(capture),
        // Show loading or permission errors automatically handled by the package.
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.horizontal, 8, AppSpacing.horizontal, 8),
          child: Row(
            children: [
              // Flashlight toggle button (handled in AppBar, but keep here for UI parity)
              OutlinedIconButton(icon: Icons.flashlight_on_outlined, label: 'Flashlight', onPressed: () {
                setState(() => _torchEnabled = !_torchEnabled);
                _controller.toggleTorch();
              }),
              const SizedBox(width: 12),
                  // Removed Gallery button as its functionality (openGallery) is not available.
                  // OutlinedIconButton(icon: Icons.photo_library_outlined, label: 'Gallery', onPressed: () async {
                  //     // Open gallery picker – mobile_scanner provides a method.
                  //     await _controller.openGallery();
                  // }),
            ],
          ),
        ),
      ),
    );
  }
}
