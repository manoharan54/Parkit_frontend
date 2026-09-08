import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _user() => const AppUser(
      name: 'Manoharan K',
      email: '230701177@rajalakshmi.edu.in',
      phone: '+919000000000',
      vehicle: 'TN07AB1234',
      password: 'oldpass123',
    );

Future<void> _pumpProfile(WidgetTester tester,
    {VoidCallback? onUpdated, VoidCallback? onLogout}) async {
  await tester.pumpWidget(MaterialApp(
    home: ProfileScreen(
      user: _user(),
      onUpdated: onUpdated ?? () {},
      onLogout: onLogout ?? () {},
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
      find.text(text, skipOffstage: false), 400,
      scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'name': 'Manoharan K',
      'email': '230701177@rajalakshmi.edu.in',
      'phone': '+919000000000',
      'vehicle': 'TN07AB1234',
      'password': 'oldpass123',
    });
  });

  testWidgets('Profile renders minimal parking structure', (tester) async {
    await _pumpProfile(tester);

    expect(find.text('Manoharan K'), findsOneWidget);
    expect(find.text('230701177@rajalakshmi.edu.in'), findsOneWidget);
    expect(find.text('Edit Profile'), findsWidgets);
    expect(find.text('TN07AB1234'), findsWidgets);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('118h'), findsOneWidget);
    expect(find.text('₹1850'), findsOneWidget);

    await _scrollTo(tester, 'View Project Info');
    expect(find.text('ParkIt'), findsWidgets);
  });

  testWidgets('Vehicle CRUD: add, set default, delete', (tester) async {
    var updated = false;
    await _pumpProfile(tester, onUpdated: () => updated = true);

    // Open the manager; seeded vehicle is listed and active.
    await tester.tap(find.text('Manage Vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Manage vehicles'), findsOneWidget);

    // Add a second vehicle (chip-selected type).
    await tester.tap(find.text('Add Vehicle'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'TN09CD5678');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bike'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), 'R15 V4');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('TN07AB1234'), findsWidgets);
    expect(find.text('TN09CD5678'), findsWidgets);

    // Make the second vehicle the default.
    await tester.tap(find.widgetWithText(ListTile, 'TN09CD5678'));
    await tester.pump();
    expect(updated, isTrue);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Bike · R15 V4'), findsOneWidget);

    // Delete the first vehicle (with confirmation).
    await tester.tap(find.text('Manage Vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete vehicle').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('TN07AB1234'), findsNothing);
    expect(find.text('TN09CD5678'), findsWidgets);
  });

  testWidgets('Vehicle form rejects duplicates and bad numbers',
      (tester) async {
    await _pumpProfile(tester);
    await tester.tap(find.text('Manage Vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Vehicle'));
    await tester.pumpAndSettle();

    // Duplicate of the seeded vehicle.
    await tester.enterText(
        find.byType(TextFormField).at(0), 'TN07AB1234');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Car'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), 'i20');
    await tester.pump();
    // Autocomplete suggests the catalog match; selecting it fills the field.
    expect(find.text('Hyundai i20'), findsOneWidget);
    await tester.tap(find.text('Hyundai i20'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(find.text('This vehicle is already added'), findsOneWidget);

    // Invalid format.
    await tester.enterText(find.byType(TextFormField).at(0), '!!');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    expect(find.text('Enter a valid vehicle number'), findsOneWidget);
  });

  testWidgets('Vehicle form shows live plate preview and custom type',
      (tester) async {
    await _pumpProfile(tester);
    await tester.tap(find.text('Manage Vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Vehicle'));
    await tester.pumpAndSettle();

    // Placeholder plate before typing (plus the seeded list entry behind).
    expect(find.text('TN07AB1234'), findsWidgets);

    // Live preview uppercases while typing.
    await tester.enterText(
        find.byType(TextFormField).at(0), 'tn99zz0001');
    await tester.pump();
    expect(find.text('TN99ZZ0001'), findsOneWidget);
    // Seeded entries behind the dialog (profile card + manager list).
    expect(find.text('TN07AB1234'), findsWidgets);
  });

  testWidgets('Model autocomplete resolves brand + model queries',
      (tester) async {
    await _pumpProfile(tester);
    await tester.tap(find.text('Manage Vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Vehicle'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'TN11XY2222');

    // Prefix query resolves the catalog entry with segment + EV tags.
    await tester.enterText(find.byType(TextFormField).at(1), 'Bre');
    await tester.pump();
    expect(find.text('Maruti Suzuki Brezza'), findsOneWidget);
    expect(find.text('Compact SUV'), findsWidgets);
    await tester.tap(find.text('Maruti Suzuki Brezza'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('TN11XY2222'), findsWidgets);
    expect(find.text('Car · Maruti Suzuki Brezza'), findsOneWidget);
  });

  testWidgets('Scooty autocomplete resolves model numbers', (tester) async {
    await _pumpProfile(tester);
    await tester.tap(find.text('Manage Vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Vehicle'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Scooty'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(1), '450');
    await tester.pump();
    expect(find.text('Ather 450X'), findsOneWidget);
  });

  testWidgets('Change password verifies current and saves', (tester) async {
    await _pumpProfile(tester);
    await _scrollTo(tester, 'Change Password');
    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();

    // Wrong current password is rejected.
    await tester.enterText(find.byType(TextFormField).at(0), 'nope123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
    await tester.tap(find.widgetWithText(FilledButton, 'Update'));
    await tester.pumpAndSettle();
    expect(find.text('Current password is incorrect'), findsOneWidget);

    // Correct current password saves.
    await tester.enterText(
        find.byType(TextFormField).at(0), 'oldpass123');
    await tester.tap(find.widgetWithText(FilledButton, 'Update'));
    await tester.pumpAndSettle();
    expect(find.text('Password updated successfully'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('password'), 'newpass123');
  });

  testWidgets('Notifications sheet and project info open', (tester) async {
    await _pumpProfile(tester);

    await _scrollTo(tester, 'Notifications');
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Parking alerts'), findsOneWidget);
    await tester.tap(find.byType(Switch).at(0));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await _scrollTo(tester, 'View Project Info');
    await tester.tap(find.text('View Project Info'));
    await tester.pumpAndSettle();
    expect(
        find.text('Smart Parking Allocation & Management System'),
        findsWidgets);
    expect(find.text('© 2026 ParkIt · Academic project demo'),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('Logout asks for confirmation', (tester) async {
    var loggedOut = false;
    await _pumpProfile(tester, onLogout: () => loggedOut = true);

    // Header Logout is visible without scrolling.
    await tester.tap(find.text('Logout').first);
    await tester.pumpAndSettle();
    expect(find.text('Logout?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(loggedOut, isFalse);

    await tester.tap(find.text('Logout').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });
}
