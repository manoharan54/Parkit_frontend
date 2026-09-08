import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'styles.dart';
import 'widgets.dart';

import 'receipt_card.dart';

/// Official ParkIt logo, embedded in both PDF and PNG outputs.
Future<Uint8List> loadParkitLogoBytes() async {
  final bundle = await rootBundle.load('assets/images/parkit_logo.png');
  return bundle.buffer.asUint8List();
}

/// Builds a clean, printable A4 parking receipt PDF.
///
/// [base] / [bold] should be full-Unicode fonts (e.g. Roboto via
/// [PdfGoogleFonts]) so the ₹ symbol renders correctly. They default to
/// Helvetica for offline/test use.
Future<Uint8List> buildReceiptPdf(
    ReceiptData data, Uint8List logoBytes,
    {pw.Font? base, pw.Font? bold}) async {
  const primary = PdfColor.fromInt(0xFF1E7767);
  const ink = PdfColor.fromInt(0xFF13252C);
  const grey = PdfColor.fromInt(0xFF667671);
  const divider = PdfColor.fromInt(0xFFE2E9E5);
  final baseFont = base ?? pw.Font.helvetica();
  final boldFont = bold ?? pw.Font.helveticaBold();

  pw.TextStyle st(double size, PdfColor color, {bool b = false}) =>
      pw.TextStyle(font: b ? boldFont : baseFont, fontSize: size, color: color);
  pw.TextStyle heading() => pw.TextStyle(
      font: boldFont,
      fontSize: 10,
      letterSpacing: 1.2,
      color: primary);

  pw.Widget kv(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
              child: pw.Text(label, style: st(11, grey))),
          pw.SizedBox(width: 12),
          pw.Text(value,
              textAlign: pw.TextAlign.right,
              style: st(11.5, ink, b: bold)),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Image(pw.MemoryImage(logoBytes),
                width: 72, height: 72),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text('PARKIT SMART PARKING SYSTEM',
                style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 11,
                    letterSpacing: 2.0,
                    color: primary)),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child:
                pw.Text('Parking Receipt', style: st(22, ink, b: true)),
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: divider, thickness: 1),
          pw.SizedBox(height: 12),
          pw.Text('RECEIPT INFORMATION', style: heading()),
          pw.SizedBox(height: 8),
          kv('Receipt ID', data.receiptId, bold: true),
          kv('Generated', data.generatedLabel),
          pw.SizedBox(height: 10),
          pw.Text('SESSION DETAILS', style: heading()),
          pw.SizedBox(height: 8),
          kv('Vehicle Number', data.vehicle, bold: true),
          kv('Parking Facility', data.facility),
          kv('Allocated Slot', data.slot, bold: true),
          kv('Entry Time', data.entryLabel),
          kv('Duration', data.durationLabel),
          pw.SizedBox(height: 10),
          pw.Text('CHARGES', style: heading()),
          pw.SizedBox(height: 8),
          kv('Parking Fee', data.parkingFee),
          kv('Tax (GST)', data.tax),
          pw.Divider(color: divider, thickness: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Amount', style: st(14, ink, b: true)),
              pw.Text(data.total, style: st(18, primary, b: true)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: data.receiptId,
              width: 130,
              height: 130,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text('QR VERIFICATION CODE · ${data.receiptId}',
                style: st(9, grey)),
          ),
          pw.Spacer(),
          pw.Divider(color: divider, thickness: 1),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
                'Generated by ParkIt Smart Parking Allocation & Management System',
                textAlign: pw.TextAlign.center,
                style: st(9, grey)),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Bundled Roboto TTFs shipped under assets/fonts (full ₹ support,
/// works fully offline). Falls back to downloaded Google Fonts, then
/// Helvetica as a last resort.
Future<pw.Font> _bundledPdfFont(String asset) async {
  final data = await rootBundle.load(asset);
  return pw.Font.ttf(data);
}

/// Roboto for production PDFs: bundled assets first, Google Fonts
/// download second, Helvetica fallback last.
Future<(pw.Font, pw.Font)> _pdfFonts() async {
  try {
    return (
      await _bundledPdfFont('assets/fonts/Roboto-Regular.ttf'),
      await _bundledPdfFont('assets/fonts/Roboto-Bold.ttf')
    );
  } catch (_) {
    try {
      return (
        await PdfGoogleFonts.robotoRegular(),
        await PdfGoogleFonts.robotoBold()
      );
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }
}

/// File name convention: `<VehicleNumber>_Receipt.pdf` (no timestamps).
String receiptPdfName(String vehicle) => '${vehicle}_Receipt.pdf';

/// Generates the PDF receipt and stores it in the app documents directory.
/// Returns the saved file.
/// Human-readable location shown after a successful save.
String receiptsLocationLabel() =>
    Platform.isAndroid ? 'Downloads/ParkIt' : 'Documents/ParkIt';

/// Storage permission is only required on Android below API 30, where files
/// are written directly. API 30+ uses MediaStore (no permission needed).
Future<bool> _ensureLegacyWritePermission() async {
  if (!Platform.isAndroid) return true;
  try {
    final android = await DeviceInfoPlugin().androidInfo;
    if (android.version.sdkInt > 29) return true;
    return (await Permission.storage.request()).isGranted;
  } catch (_) {
    return true;
  }
}

/// Deterministic public path: `/storage/emulated/0/Download/ParkIt/<name>`.
String _androidPublicPath(String fileName) =>
    // ignore: avoid_hardcoded_paths (Android shared-storage convention)
    '${DirType.download.fullPath(relativePath: 'ParkIt', dirName: DirName.download)}/$fileName';

/// Saves bytes permanently on the device:
/// - Android → Downloads/ParkIt/ via MediaStore (API 30+, permission-free)
///   or direct file write with permission below API 30.
/// - iOS/desktop → Documents/ParkIt/.
///
/// Returns an absolute path that can be opened/shared afterwards.
Future<String> saveReceiptToDevice({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'ParkIt';
    if (!await _ensureLegacyWritePermission()) {
      throw StateError('Storage permission denied');
    }
    final tempDir = await getTemporaryDirectory();
    final temp = File('${tempDir.path}/$fileName');
    await temp.writeAsBytes(bytes, flush: true);
    final info = await MediaStore().saveFile(
      tempFilePath: temp.path,
      dirType: DirType.download,
      dirName: DirName.download,
      // relativePath defaults to MediaStore.appFolder ("ParkIt").
    );
    if (info == null) throw StateError('Could not save to Downloads');
    // Prefer the deterministic public path for opening the file.
    final direct = _androidPublicPath(info.name);
    if (await File(direct).exists()) return direct;
    final viaUri = await MediaStore()
        .getFilePathFromUri(uriString: info.uri.toString());
    if (viaUri != null && await File(viaUri).exists()) return viaUri;
    return direct;
  }
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/ParkIt');
  await dir.create(recursive: true);
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Builds the PDF receipt and stores it as `<Vehicle>_Receipt.pdf`.
/// Returns the openable file path.
Future<String> saveReceiptPdfToDevice(ReceiptData data) async {
  final logo = await loadParkitLogoBytes();
  final fonts = await _pdfFonts();
  final bytes =
      await buildReceiptPdf(data, logo, base: fonts.$1, bold: fonts.$2);
  return saveReceiptToDevice(
      fileName: receiptPdfName(data.vehicle), bytes: bytes);
}

/// Stores a receipt-card PNG as `<Vehicle>_Receipt.png`.
/// Returns the openable file path.
Future<String> saveReceiptPngToDevice({
  required Uint8List pngBytes,
  required String vehicle,
}) {
  return saveReceiptToDevice(
      fileName: receiptPngName(vehicle), bytes: pngBytes);
}

/// Opens a previously saved receipt with the system's file viewer.
Future<OpenResult> openReceiptFile(String path) => OpenFilex.open(path);

/// File name convention: `<VehicleNumber>_Receipt.png`.
String receiptPngName(String vehicle) => '${vehicle}_Receipt.png';

/// Shares a receipt-card PNG (never a full-screen screenshot).
Future<void> shareReceiptPng(Uint8List pngBytes, ReceiptData data) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${receiptPngName(data.vehicle)}');
  await file.writeAsBytes(pngBytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(file.path,
            name: receiptPngName(data.vehicle), mimeType: 'image/png')
      ],
      subject: 'ParkIt Parking Receipt ${data.receiptId}',
      text:
          'My ParkIt parking receipt · ${data.vehicle} · Slot ${data.slot} · ${data.amountLabel}',
    ),
  );
}

/// Timestamp label used on generated assets.
String receiptTimestamp() =>
    DateFormat('dd MMM yyyy · hh:mm a').format(DateTime.now());

/// Renders the branded receipt card off-screen and captures it as a PNG.
/// Only the receipt card is captured, never the application screen.
/// Returns null when capture is impossible.
Future<Uint8List?> captureReceiptCard(
    BuildContext context, ReceiptData data) async {
  final controller = ScreenshotController();
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      top: 0,
      child: Transform.translate(
        offset: const Offset(-2000, -2000),
        child: Screenshot(
          controller: controller,
          child: ReceiptCard(data: data),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    return await controller.capture(pixelRatio: 3.0);
  } catch (_) {
    return null;
  } finally {
    entry.remove();
  }
}

/// Branded receipt preview dialog with a Share PNG action.
/// Shared by the session screen and the payment success screen.
Future<void> showReceiptPreview(
    BuildContext context, ReceiptData data) {
  final controller = ScreenshotController();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Parking receipt',
                style:
                    TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Preview before sharing',
                style: TextStyle(
                    fontSize: 13, color: AppColors.secondaryText)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Screenshot(
                controller: controller,
                child: ReceiptCard(data: data),
              ),
            ),
            const SizedBox(height: 16),
            _PreviewActions(
              onShare: (setBusy) async {
                final navigator = Navigator.of(dialogContext);
                setBusy(true);
                try {
                  final image = await controller.capture(
                      pixelRatio: 3.0);
                  if (image == null) {
                    throw StateError('empty capture');
                  }
                  await shareReceiptPng(image, data);
                  if (context.mounted) {
                    navigator.pop();
                    showParkitSnack(
                        context, 'Receipt shared successfully',
                        icon: Icons.ios_share_outlined);
                  }
                } catch (_) {
                  setBusy(false);
                  if (context.mounted) {
                    showParkitSnack(context,
                        'Could not create the receipt image — try again',
                        icon: Icons.error_outline_rounded);
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Preview-dialog actions with a loading state for the PNG capture.
class _PreviewActions extends StatefulWidget {
  const _PreviewActions({required this.onShare});

  final void Function(void Function(bool busy)) onShare;

  @override
  State<_PreviewActions> createState() => _PreviewActionsState();
}

class _PreviewActionsState extends State<_PreviewActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : () => widget.onShare((busy) {
                      if (mounted) setState(() => _busy = busy);
                    }),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.ios_share_outlined, size: 18),
            label: Text(_busy ? 'Working…' : 'Share PNG'),
          ),
        ),
      ],
    );
  }
}
