import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE: the Home session card ticks every second, so only fixed pumps are
// used here; the tree is replaced at the end to cancel the ticker.
Future<void> _pumpHome(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'name': 'Manoharan K',
    'email': '230701177@rajalakshmi.edu.in',
    'phone': '+919000000000',
    'vehicle': 'TN07AB1234',
    'password': 'pass1234',
    'logged_in': true,
  });
  await tester.pumpWidget(MaterialApp(
    home: MainShell(onLogout: () {}),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('Home shows live session, rates and wired actions',
      (tester) async {
    await _pumpHome(tester);

    expect(find.text('Welcome, Manoharan'), findsOneWidget);
    expect(find.text('Slot A-17'), findsOneWidget);
    // Live tariff fee is rendered next to the ticking duration.
    expect(find.textContaining('current fee'), findsOneWidget);

    // Transparent community tariff card.
    expect(find.text('Parking rates'), findsOneWidget);
    expect(find.text('First hour'), findsOneWidget);
    expect(find.text('Every 30 min after'), findsOneWidget);
    expect(find.text('Daily maximum'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Dock shows live booking badge and center Scan action',
      (tester) async {
    await _pumpHome(tester);

    // One active demo session → badge "1" on the Bookings tab.
    expect(find.text('1'), findsOneWidget);
    // Scan is a uniform tab like the others.
    expect(find.text('Scan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Dock items are spaced with no overlap on a 360px phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await _pumpHome(tester);

    // Left-to-right order in four equal slots.
    final homeX =
        tester.getCenter(find.byIcon(Icons.home_rounded)).dx;
    final scanX =
        tester.getCenter(find.byIcon(Icons.qr_code_scanner_outlined)).dx;
    final bookingsX =
        tester.getCenter(find.byIcon(Icons.receipt_long_outlined)).dx;
    final profileX =
        tester.getCenter(find.byIcon(Icons.person_outline_rounded)).dx;
    expect(homeX, lessThan(scanX));
    expect(scanX, lessThan(bookingsX));
    expect(bookingsX, lessThan(profileX));
    expect(scanX - homeX, greaterThan(60));
    expect(bookingsX - scanX, greaterThan(60));
    expect(profileX - bookingsX, greaterThan(60));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Bottom nav dock switches tabs with haptics', (tester) async {
    await _pumpHome(tester);

    // Destination labels are matched by icon; tapping switches the tab.
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Active (1)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('My profile'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}

