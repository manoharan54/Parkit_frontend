import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/payment_screen.dart';
import 'package:parkit_flutter/widgets/payment_success_animation.dart';

const _payment = ParkingPayment(
  receiptId: 'PKT-2026-1045',
  slot: 'A-17',
  vehicle: 'TN07AB1234',
  facility: 'REC Main Parking',
  entryLabel: '08 Sep · 09:15 AM',
  durationLabel: '2h 27m',
  fee: 40,
  tax: 2,
);

Future<void> _pumpPayment(WidgetTester tester,
    {VoidCallback? onPaid}) async {
  await tester.pumpWidget(MaterialApp(
    home: PaymentScreen(payment: _payment, onPaid: onPaid),
  ));
  await tester.pump();
}

Finder _scrollable(WidgetTester tester) =>
    find.byType(Scrollable).first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 400,
      scrollable: _scrollable(tester));
  await tester.pump();
}

Future<void> _payAndSucceed(WidgetTester tester) async {
  await _scrollTo(tester, find.text('Pay ₹42', skipOffstage: false));
  await tester.tap(find.text('Pay ₹42'));
  await tester.pump();
  expect(find.text('Processing…'), findsOneWidget);
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Payment details show amount, methods and demo note',
      (tester) async {
    await _pumpPayment(tester);

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('₹42'), findsWidgets);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Demo mode — no real money moves.'),
        findsOneWidget);
    expect(find.text('Pay ₹42'), findsOneWidget);
  });

  testWidgets('Method selection switches the group', (tester) async {
    await _pumpPayment(tester);

    await _scrollTo(tester, find.text('Card', skipOffstage: false));
    await tester.tap(find.widgetWithText(RadioListTile<String>, 'Card'));
    await tester.pump();
    await _scrollTo(tester, find.text('Pay ₹42', skipOffstage: false));
    await tester.tap(find.text('Pay ₹42'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    // Success keeps the scrolled offset: bring the transaction card on
    // stage; the selected method is recorded there.
    await _scrollTo(tester, find.text('Card · Demo', skipOffstage: false));
    expect(find.text('Card · Demo'), findsOneWidget);
    expect(find.text('Parking Session Completed'), findsOneWidget);
  });

  testWidgets('Success shows video widget once with receipt actions',
      (tester) async {
    var paid = false;
    await _pumpPayment(tester, onPaid: () => paid = true);
    await _payAndSucceed(tester);

    expect(paid, isTrue);
    expect(find.text('Payment Successful'), findsWidgets);
    // Reusable animation widget (falls back gracefully in tests).
    expect(find.byType(PaymentSuccessAnimation), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('View Receipt opens branded preview', (tester) async {
    await _pumpPayment(tester);
    await _payAndSucceed(tester);

    await _scrollTo(tester, find.text('Receipt', skipOffstage: false));
    await tester.tap(find.text('Receipt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Parking receipt'), findsOneWidget);
    expect(find.text('Share PNG'), findsOneWidget);
  });

  testWidgets('PaymentSuccessAnimation completes without layout shift',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PaymentSuccessAnimation())));
    await tester.pump();
    // Fixed stage (180 on phones) with clipped composed animation.
    expect(find.byType(PaymentSuccessAnimation), findsOneWidget);
    expect(find.byType(ClipRect), findsWidgets);
    expect(
        find.descendant(
            of: find.byType(PaymentSuccessAnimation),
            matching: find.byType(CustomPaint)),
        findsOneWidget);
    // Run past the full 1400ms timeline: single pass, then stable.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PaymentSuccessAnimation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
