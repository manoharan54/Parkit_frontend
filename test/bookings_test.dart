import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/main.dart';

// NOTE: pumpAndSettle is avoided throughout: the LIVE badge on the active
// card repeats forever, so only fixed pumps are used.
Future<void> _pumpBookings(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Bookings shows tabs with counts and active card',
      (tester) async {
    await _pumpBookings(tester);

    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Upcoming (1)'), findsOneWidget);
    expect(find.text('History (6)'), findsOneWidget);

    // Active booking card with live marker and end action.
    expect(find.text('Slot A-17'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('End session'), findsOneWidget);
  });

  testWidgets('Search filters bookings', (tester) async {
    await _pumpBookings(tester);
    await _openTab(tester, 'History (6)');
    expect(find.text('Slot C-22'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'library parking');
    await tester.pump();
    expect(find.text('Slot C-22'), findsNothing);
    expect(find.text('Slot L-14'), findsOneWidget);
  });

  testWidgets('Ending a session opens demo payment', (tester) async {
    await _pumpBookings(tester);

    await tester.tap(find.text('End session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('End parking session?'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('End session')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Demo checkout opens instead of an instant snackbar.
    expect(find.text('Payment'), findsOneWidget);
    expect(find.textContaining('Pay ₹'), findsOneWidget);
  });

  testWidgets('Paying completes the session into History', (tester) async {
    await _pumpBookings(tester);

    await tester.tap(find.text('End session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('End session')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Pay with the preselected demo method.
    await tester.scrollUntilVisible(
        find.textContaining('Pay ₹', skipOffstage: false), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.textContaining('Pay ₹'));
    await tester.pump();
    expect(find.text('Processing…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));

    // Success state with the animation widget and receipt actions.
    expect(find.text('Payment Successful'), findsWidgets);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Booking moved to History via onPaid.
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Active (0)'), findsOneWidget);
    expect(find.text('History (7)'), findsOneWidget);
  });

  testWidgets('Cancelling removes an upcoming reservation', (tester) async {
    await _pumpBookings(tester);
    await _openTab(tester, 'Upcoming (1)');
    expect(find.text('Slot V-08'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cancel reservation?'), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel booking')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reservation cancelled'), findsOneWidget);
    expect(find.text('Upcoming (0)'), findsOneWidget);
  });

  testWidgets('Filter sheet applies a status filter', (tester) async {
    await _pumpBookings(tester);

    await tester.tap(find.byTooltip('Filter bookings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Filter by status'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await _openTab(tester, 'History (6)');
    expect(find.text('Slot C-22'), findsOneWidget);
    expect(find.text('Slot B-108'), findsNothing);
  });

  testWidgets('Tapping a card opens session details', (tester) async {
    await _pumpBookings(tester);

    await tester.tap(find.text('Slot A-17'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Session details'), findsOneWidget);
  });
}
