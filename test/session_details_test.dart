import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/receipt_card.dart';
import 'package:parkit_flutter/receipt_service.dart';
import 'package:parkit_flutter/session_details_screen.dart';
import 'package:pdf/widgets.dart' as pw;

/// Scrolls the dashboard's scrollable until [text] is visible, then asserts.
Future<void> _expectSection(
    WidgetTester tester, String text) async {
  final finder = find.text(text, skipOffstage: false);
  await tester.scrollUntilVisible(finder, 400,
      scrollable: find.byType(Scrollable).first);
  await tester.pump();
  expect(find.text(text), findsOneWidget);
}

void main() {
  testWidgets('Active session renders all core sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(
        status: 'Active',
        slot: 'A-17',
        zone: 'Visitor Parking',
        vehicleNumber: 'TN07AB1234',
        facility: 'REC Main Parking',
        ownerName: 'Test User',
      ),
    ));
    await tester.pump();

    // Above the fold: status hero (with live duration) + live analytics.
    expect(find.text('Session details'), findsOneWidget);
    expect(find.text('Slot A-17'), findsWidgets);
    expect(find.text('LIVE PARKING ANALYTICS'), findsOneWidget);
    expect(find.text('CURRENT DURATION'), findsOneWidget);

    // Scroll through every core section like a real user.
    for (final section in [
      'Parking location',
      'Cost breakdown',
      'QR access pass',
      'Session records',
    ]) {
      await _expectSection(tester, section);
    }

    // Removed admin sections must NOT be present.
    expect(find.text('Occupancy'), findsNothing);
    expect(find.text('Smart insights'), findsNothing);
    expect(find.text('Security & monitoring'), findsNothing);

    // Fixed bottom action bar: Extend + End session (no Navigate).
    expect(find.text('Navigate'), findsNothing);
    expect(find.text('Extend'), findsOneWidget);
    expect(find.text('End session'), findsOneWidget);

    // Dispose to cancel the live ticker.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Completed session shows receipt actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(status: 'Completed'),
    ));
    await tester.pump();

    expect(find.text('COMPLETED'), findsOneWidget);

    for (final action in ['Receipt', 'Rebook']) {
      await _expectSection(tester, action);
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Expired session shows red status', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(status: 'Expired'),
    ));
    await tester.pump();

    expect(find.text('EXPIRED'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('No overflow across phone and tablet sizes',
      (WidgetTester tester) async {
    const sizes = [
      Size(360, 740), // Android phone
      Size(390, 844), // iPhone
      Size(768, 1024), // iPad portrait / Android tablet
      Size(1024, 768), // Tablet landscape
    ];
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(const MaterialApp(
        home: ParkingSessionDetailsScreen(status: 'Active'),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Scroll end-to-end like a user would.
      await tester.scrollUntilVisible(
          find.text('Session records', skipOffstage: false), 500,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Navigate'), findsNothing);
      expect(find.text('Extend'), findsOneWidget);
      expect(find.text('End session'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('Status facts show complete values without truncation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(
        status: 'Active',
        slot: 'A-17',
        zone: 'Visitor Parking Zone',
        vehicleNumber: 'TN07AB1234',
        facility: 'REC Main Parking Facility',
      ),
    ));
    await tester.pump();

    // Full values must be present (never cut to "TN07AB..." style).
    expect(find.text('VEHICLE NUMBER'), findsOneWidget);
    expect(find.text('TN07AB1234'), findsWidgets);
    expect(find.text('REC Main Parking Facility'), findsWidgets);
    expect(find.text('Visitor Parking Zone'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Share opens branded receipt preview',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(status: 'Active'),
    ));
    await tester.pump();

    await tester.scrollUntilVisible(
        find.byTooltip('Share receipt', skipOffstage: false), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.byTooltip('Share receipt'));
    await tester.pump();

    expect(find.text('Parking Receipt'), findsWidgets);
    expect(find.text('Share PNG'), findsOneWidget);
    expect(find.text('PKT-2026-1045'), findsWidgets);
    expect(find.text('PARKIT SMART PARKING'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  test('Receipt PDF builds with branding and naming convention', () async {
    const data = ReceiptData(
      receiptId: 'PKT-2026-1045',
      vehicle: 'TN07AB1234',
      facility: 'REC Main Parking',
      slot: 'A-17',
      entryLabel: '08 Sep · 09:15 AM',
      durationLabel: '2h 27m',
      amountLabel: '₹32',
      parkingFee: '₹30',
      tax: '₹2',
      total: '₹32',
      generatedLabel: '08 Sep 2026 · 11:42 AM',
    );

    // Strict file naming: <VehicleNumber>_Receipt.pdf / .png
    expect(receiptPdfName('TN07AB1234'), 'TN07AB1234_Receipt.pdf');
    expect(receiptPngName('TN07AB1234'), 'TN07AB1234_Receipt.png');

    // Real project logo asset loads correctly.
    final logo = await rootBundle.load('assets/images/parkit_logo.png');
    final logoBytes = logo.buffer.asUint8List();
    expect(logoBytes, isNotEmpty);

    // Generated PDF is a valid, non-trivial document.
    final pdf = await buildReceiptPdf(data, logoBytes);
    expect(pdf.lengthInBytes, greaterThan(2000));
    expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
  });

  test('Receipt PDF uses bundled Roboto for rupee glyph', () async {
    {
      final base = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final bold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      const data = ReceiptData(
        receiptId: 'PKT-2026-1045',
        vehicle: 'TN07AB1234',
        facility: 'REC Main Parking',
        slot: 'A-17',
        entryLabel: '08 Sep · 09:15 AM',
        durationLabel: '2h 27m',
        amountLabel: '₹32',
        parkingFee: '₹30',
        tax: '₹2',
        total: '₹32',
        generatedLabel: '08 Sep 2026 · 11:42 AM',
      );
      final logo =
          (await rootBundle.load('assets/images/parkit_logo.png'))
              .buffer
              .asUint8List();
      final pdf = await buildReceiptPdf(data, logo, base: base, bold: bold);
      expect(String.fromCharCodes(pdf.sublist(0, 4)), '%PDF');
      expect(pdf.lengthInBytes, greaterThan(5000));
    }
  });

  testWidgets('More menu offers receipt actions, QR buttons are icon-only',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(status: 'Active'),
    ));
    await tester.pump();

    // No clipboard share action anymore — a More menu instead.
    expect(find.byTooltip('Share session'), findsNothing);
    expect(find.byTooltip('Support'), findsNothing);
    expect(find.byTooltip('More options'), findsOneWidget);
    await tester.tap(find.byTooltip('More options'));
    await tester.pump();
    expect(find.text('View Receipt'), findsOneWidget);
    expect(find.text('Share Receipt'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.text('Save PNG'), findsOneWidget);
    // Dismiss the menu.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    // QR actions are icon-only with proper tooltips.
    await tester.scrollUntilVisible(
        find.byTooltip('Enlarge QR', skipOffstage: false), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(find.byTooltip('Enlarge QR'), findsOneWidget);
    expect(find.byTooltip('Share receipt'), findsOneWidget);
    expect(find.byTooltip('Download receipt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('QR buttons stay in one horizontal row on a 320px phone',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(
      home: ParkingSessionDetailsScreen(status: 'Active'),
    ));
    await tester.pump();

    // No overflow errors on a 320px-wide phone.
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
        find.text('QR access pass', skipOffstage: false), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // All three action icons share the same vertical center: one row.
    final enlargeY =
        tester.getCenter(find.byIcon(Icons.zoom_out_map_rounded)).dy;
    final shareY =
        tester.getCenter(find.byIcon(Icons.ios_share_outlined)).dy;
    final downloadY =
        tester.getCenter(find.byIcon(Icons.download_outlined)).dy;
    expect((shareY - enlargeY).abs(), lessThan(1.0));
    expect((downloadY - enlargeY).abs(), lessThan(1.0));

    await tester.pumpWidget(const SizedBox());
  });
}
