import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'styles.dart';

/// Guided QR scanning interface (Google Lens style).
///
/// The camera feed fills almost the full screen width at an exact 4:3
/// ratio, with a corner-marker guide frame, scan instructions, a single
/// flashlight action, vibrate + success animation on detection, then
/// automatic navigation via [onScanned].
class QRScannerView extends StatefulWidget {
  const QRScannerView({required this.onScanned, super.key});
  final ValueChanged<String> onScanned;

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  static const _background = Color(0xFF0B1512);

  late final MobileScannerController _controller;
  bool _hasScanned = false;
  bool _navigated = false;
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

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return; // Prevent multiple callbacks.
    final Barcode? barcode =
        capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final String? raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;
    HapticFeedback.mediumImpact(); // Vibrate on successful scan.
    setState(() => _hasScanned = true);
    _controller.stop();
    // Brief success animation, then navigate automatically.
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _navigated) return;
      _navigated = true;
      widget.onScanned(raw);
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchEnabled = !_torchEnabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Flashlight is not available on this device')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = AppResponsive.getMaxContentWidth(context);
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        // MOD: one LayoutBuilder drives the whole layout so the camera can
        // be sized from the real viewport instead of nested shrink factors.
        child: LayoutBuilder(
          builder: (context, viewport) {
            final vw = viewport.maxWidth;
            final vh = viewport.hasBoundedHeight
                ? viewport.maxHeight
                : 800.0;
            final contentW =
                contentWidth > vw ? vw : contentWidth;
            // MOD (portrait): height-led sizing. The scanner takes up to
            // 75% of the viewport height while never exceeding the screen
            // width (~60-75% tall on typical phones). The camera texture
            // cover-fills the box, so any portrait aspect stays free of
            // stretching and black bars.
            // MOD: short screens keep extra air so nothing overflows.
            final reserve = vh < 650 ? 310.0 : 282.0;
            var camH = (vh - reserve).clamp(200.0, vh * 0.75);
            var camW = vw - 16 < camH * 4 / 3 ? vw - 16 : camH * 4 / 3;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Top: back, title, helper ----
                Center(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: contentW),
                    child: const Padding(
                      padding:
                          EdgeInsets.fromLTRB(12, 4, 20, 0),
                      child: Row(children: [
                        _BackButton(),
                        SizedBox(width: 4),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Scan QR Code',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                SizedBox(height: 2),
                                Text(
                                    'Align the QR code within the frame',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12)),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // ---- Camera preview container (4:3, clipped) ----
                Center(
                  child: SizedBox(
                    width: camW,
                    height: camH,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        // MOD: larger guide box proportional to the taller
                        // preview (up to 280px), detection window matches.
                        final box = (size.height - 48)
                            .clamp(180.0, 280.0);
                        final boxSize = box
                            .clamp(0.0, size.width - 32)
                            .toDouble();
                        final window = Rect.fromCenter(
                            center: size.center(Offset.zero),
                            width: boxSize,
                            height: boxSize);
                        return ClipRRect(
                          borderRadius:
                              BorderRadius.circular(24),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MobileScanner(
                                controller: _controller,
                                scanWindow: window,
                                onDetect: (capture) =>
                                    _handleBarcode(capture),
                                errorBuilder: (context,
                                        error,
                                        child) =>
                                    const _CameraError(),
                              ),
                              CustomPaint(
                                painter: _ScanOverlayPainter(
                                    boxSize: boxSize),
                              ),
                              if (_hasScanned)
                                const _SuccessOverlay(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Spacer(),
                // ---- Scan instructions ----
                Center(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: contentW),
                    child: const Padding(
                      padding:
                          EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: _ScanTips(),
                    ),
                  ),
                ),
                    const SizedBox(height: 10),
                    // ---- Bottom: single flashlight action ----
                    Center(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: contentW),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              24, 0, 24, 20),
                      child: SizedBox(
                        height: AppSpacing.buttonHeight,
                        child: _flashlightButton(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _flashlightButton() => FilledButton.icon(
        onPressed: _toggleTorch,
        icon: Icon(
            _torchEnabled
                ? Icons.flashlight_on_rounded
                : Icons.flashlight_off_rounded,
            size: 20),
        label: Text(_torchEnabled ? 'Flashlight · On' : 'Flashlight · Off',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

/// Extracted so the build method stays readable; needs no state.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    );
  }
}

/// Extracted instructions block; needs no state.
class _ScanTips extends StatelessWidget {
  const _ScanTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScanTip(
            icon: Icons.center_focus_strong_rounded,
            text: 'Align the QR inside the frame',
          ),
          SizedBox(height: 6),
          _ScanTip(
            icon: Icons.timer_outlined,
            text: 'Hold steady — scanning is automatic',
          ),
          SizedBox(height: 6),
          _ScanTip(
            icon: Icons.swap_vert_rounded,
            text: 'Same code works for entry and exit',
          ),
        ],
      ),
    );
  }
}

/// Single instruction row shown under the camera preview.
class _ScanTip extends StatelessWidget {
  const _ScanTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.accent, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12.5)),
      ),
    ]);
  }
}

/// Corner-marker guide frame with a dimmed outside area.
class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({required this.boxSize});

  final double boxSize;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: boxSize,
        height: boxSize);

    // Dim everything outside the scan box.
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(
            box, const Radius.circular(16)))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Corner markers only.
    const marker = 30.0;
    const width = 5.0;
    const radius = Radius.circular(10);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Path corner(Offset origin, bool mirrorX, bool mirrorY) {
      final dx = mirrorX ? -1.0 : 1.0;
      final dy = mirrorY ? -1.0 : 1.0;
      return Path()
        ..moveTo(origin.dx + marker * dx, origin.dy)
        ..lineTo(origin.dx + radius.x * dx, origin.dy)
        ..arcToPoint(Offset(origin.dx, origin.dy + radius.y * dy),
            radius: radius)
        ..lineTo(origin.dx, origin.dy + marker * dy);
    }

    canvas.drawPath(
        corner(box.topLeft, false, false), paint);
    canvas.drawPath(
        corner(box.topRight, true, false), paint);
    canvas.drawPath(
        corner(box.bottomLeft, false, true), paint);
    canvas.drawPath(
        corner(box.bottomRight, true, true), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.boxSize != boxSize;
}

/// One-shot success animation shown before auto-navigation.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B9E6B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 46),
              ),
              const SizedBox(height: 12),
              const Text('Code detected',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Themed camera-error placeholder (permissions, missing camera).
class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF13252C),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.videocam_off_outlined,
                color: Colors.white54, size: 44),
            SizedBox(height: 12),
            Text('Camera unavailable',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Allow camera access to scan parking codes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
