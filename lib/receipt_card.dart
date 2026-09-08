import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'styles.dart';

/// Data shown on the branded ParkIt receipt (PNG share + PDF download).
class ReceiptData {
  const ReceiptData({
    required this.receiptId,
    required this.vehicle,
    required this.facility,
    required this.slot,
    required this.entryLabel,
    required this.durationLabel,
    required this.amountLabel,
    required this.parkingFee,
    required this.tax,
    required this.total,
    required this.generatedLabel,
  });

  final String receiptId;
  final String vehicle;
  final String facility;
  final String slot;
  final String entryLabel;
  final String durationLabel;
  final String amountLabel;
  final String parkingFee;
  final String tax;
  final String total;
  final String generatedLabel;
}

/// Deterministic mock QR badge used across the app and the receipt.
class ReceiptQr extends StatelessWidget {
  const ReceiptQr({required this.size, required this.seed, super.key});

  final double size;
  final String seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: CustomPaint(painter: _ReceiptQrPainter(seed: seed)),
    );
  }
}

class _ReceiptQrPainter extends CustomPainter {
  _ReceiptQrPainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = AppColors.ink;
    const modules = 21;
    final cell = size.width / modules;
    final rand = math.Random(seed.hashCode);
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        final inFinder = (x < 7 && y < 7) ||
            (x >= modules - 7 && y < 7) ||
            (x < 7 && y >= modules - 7);
        if (inFinder) continue;
        if (rand.nextBool()) {
          canvas.drawRect(
              Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
        }
      }
    }
    void finder(double ox, double oy) {
      canvas.drawRect(Rect.fromLTWH(ox, oy, cell * 7, cell * 7), dark);
      canvas.drawRect(
          Rect.fromLTWH(ox + cell, oy + cell, cell * 5, cell * 5),
          Paint()..color = Colors.white);
      canvas.drawRect(
          Rect.fromLTWH(ox + cell * 2, oy + cell * 2, cell * 3, cell * 3),
          dark);
    }

    finder(0, 0);
    finder(size.width - cell * 7, 0);
    finder(0, size.height - cell * 7);
  }

  @override
  bool shouldRepaint(covariant _ReceiptQrPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

/// Branded ParkIt parking receipt card.
///
/// Rendered inside a [Screenshot] capture area when sharing as PNG, so it
/// uses a fixed-width layout with the official logo asset, generous padding
/// and no elements that can clip.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({required this.data, super.key});

  final ReceiptData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      color: Colors.white,
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/parkit_logo.png',
              width: 64, height: 64, fit: BoxFit.contain),
          const SizedBox(height: 10),
          const Text('PARKIT SMART PARKING',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          const Text('Parking Receipt',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink)),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 14),
          _row('Receipt ID', data.receiptId, bold: true),
          _row('Vehicle Number', data.vehicle, bold: true),
          _row('Facility', data.facility),
          _row('Parking Slot', data.slot, bold: true),
          _row('Entry Time', data.entryLabel),
          _row('Duration', data.durationLabel),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(data.amountLabel,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ReceiptQr(size: 140, seed: data.receiptId),
          const SizedBox(height: 8),
          const Text('QR VERIFICATION CODE',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.secondaryText)),
          const SizedBox(height: 12),
          Text('Generated · ${data.generatedLabel}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.secondaryText)),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),
          const Text(
              'Generated by ParkIt Smart Parking Allocation & Management System',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.secondaryText)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight:
                        bold ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}
