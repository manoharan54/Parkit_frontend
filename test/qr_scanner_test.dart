import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:parkit_flutter/qr_scanner_view.dart';
import 'package:parkit_flutter/main.dart';
import 'package:parkit_flutter/styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QRScannerView Widget Tests', () {
    Future<void> pumpScanner(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: QRScannerView(
          onScanned: (_) {},
        ),
      ));
      await tester.pump();
    }

    testWidgets('Guided header renders with back, title and helper',
      (WidgetTester tester) async {
        await pumpScanner(tester);

        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expect(find.text('Scan QR Code'), findsOneWidget);
        expect(find.text('Align the QR code within the frame'),
            findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        // Instruction block between preview and flashlight button.
        expect(find.text('Align the QR inside the frame'),
            findsOneWidget);
        expect(find.text('Hold steady — scanning is automatic'),
            findsOneWidget);
        expect(find.text('Same code works for entry and exit'),
            findsOneWidget);
      }
    );

    testWidgets('Camera is tall and overflow-free across phone sizes',
      (WidgetTester tester) async {
        const sizes = [
          Size(360, 800),
          Size(360, 740),
          Size(390, 844),
          Size(320, 568),
        ];
        for (final size in sizes) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          await pumpScanner(tester);

          final preview =
              tester.getSize(find.byType(MobileScanner));
          // Never wider than the screen, never overflowing.
          expect(preview.width,
              lessThanOrEqualTo(size.width));
          expect(tester.takeException(), isNull);
          // Regular phones: tall portrait box (~60%+ of height).
          if (size.height >= 700) {
            expect(preview.height, greaterThan(preview.width));
            expect(preview.height,
                greaterThan(size.height * 0.55));
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
        addTearDown(tester.view.resetPhysicalSize);
      }
    );

    testWidgets('Only action is the flashlight toggle with state',
      (WidgetTester tester) async {
        await pumpScanner(tester);

        expect(find.byIcon(Icons.flashlight_off_rounded), findsOneWidget);
        expect(find.text('Flashlight · Off'), findsOneWidget);

        // No gallery, history or settings actions.
        expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
        expect(find.byIcon(Icons.history_rounded), findsNothing);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);

        // Toggle flips the visible state.
        await tester.tap(find.text('Flashlight · Off'));
        await tester.pump();
        expect(find.text('Flashlight · On'), findsOneWidget);
        expect(find.byIcon(Icons.flashlight_on_rounded), findsOneWidget);
      }
    );

    testWidgets('QRScannerView scaffold has correct structure',
      (WidgetTester tester) async {
        await pumpScanner(tester);

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(SafeArea), findsWidgets);
        expect(find.byType(FilledButton), findsOneWidget);
      }
    );
  });

  group('ProfileScreen Widget Tests', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pumpProfile(WidgetTester tester, AppUser user) async {
      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(
          user: user,
          onUpdated: () {},
          onLogout: () {},
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
          find.text(text, skipOffstage: false), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.pump();
    }

    AppUser testUser() => AppUser(
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '+9876543210',
          vehicle: 'XYZ789',
          password: 'secure123',
        );

    testWidgets('ProfileScreen displays user information',
      (WidgetTester tester) async {
        await pumpProfile(tester, testUser());

        expect(find.text('My profile'), findsOneWidget);
        expect(find.text('Jane Smith'), findsOneWidget);
        expect(find.text('jane@example.com'), findsOneWidget);
        expect(find.text('XYZ789'), findsWidgets);
      }
    );

    testWidgets('ProfileScreen shows minimal parking sections',
      (WidgetTester tester) async {
        await pumpProfile(tester, testUser());

        // Core sections, scrolled into view like a real user.
        for (final section in [
          'My Vehicle',
          'Manage Vehicle',
          'Parking Statistics',
          'Total Visits',
          'Hours Parked',
          'Total Spent',
          'Account Settings',
          'Change Password',
          'Notifications',
          'Version 1.0.0',
          'View Project Info',
        ]) {
          await scrollTo(tester, section);
          expect(find.text(section), findsWidgets);
        }

        // Removed settings-jungle entries must stay gone.
        expect(find.text('Privacy settings'), findsNothing);
        expect(find.text('Security settings'), findsNothing);
        expect(find.text('Achievements'), findsNothing);
        expect(find.text('Payment methods'), findsNothing);
      }
    );
  });

  group('Design System Tests', () {
    testWidgets('AppColors are applied correctly in theme',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: Text('Test Color Theme'),
            ),
          ),
        ));
        
        expect(find.text('Test Color Theme'), findsOneWidget);
      }
    );

    testWidgets('AppSpacing constants are used consistently',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.horizontal),
                  child: Text('Consistent Spacing'),
                ),
              ),
            ),
          ),
        );
        
        expect(find.text('Consistent Spacing'), findsOneWidget);
      }
    );

    testWidgets('AppText typography is applied to widgets',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Screen Title', style: AppText.screenTitle),
                    Text('Section Title', style: AppText.sectionTitle),
                    Text('Body Text', style: AppText.body),
                  ],
                ),
              ),
            ),
          ),
        );
        
        expect(find.text('Screen Title'), findsOneWidget);
        expect(find.text('Section Title'), findsOneWidget);
        expect(find.text('Body Text'), findsOneWidget);
      }
    );

    testWidgets('AppText provides consistent text styles',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  children: [
                    Text('Welcome Title', style: AppText.welcTitle),
                    Text('Card Title', style: AppText.cardTitle),
                    Text('Subtitle', style: AppText.subtitle),
                    Text('Caption', style: AppText.caption),
                    Text('Label', style: AppText.label),
                    Text('Button', style: AppText.button),
                  ],
                ),
              ),
            ),
          ),
        );
        
        expect(find.text('Welcome Title'), findsOneWidget);
        expect(find.text('Card Title'), findsOneWidget);
        expect(find.text('Subtitle'), findsOneWidget);
      }
    );
  });

  group('Responsive Layout Tests', () {
    testWidgets('AppResponsive provides breakpoint constants',
      (WidgetTester tester) async {
        expect(AppResponsive.mobileBreakpoint, 480.0);
        expect(AppResponsive.tabletBreakpoint, 768.0);
        expect(AppResponsive.desktopBreakpoint, 1024.0);
      }
    );

    testWidgets('AppResponsive provides helper methods without error',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                AppResponsive.isMobile(context);
                AppResponsive.isTablet(context);
                AppResponsive.isDesktop(context);
                AppResponsive.getMaxContentWidth(context);
                AppResponsive.getHorizontalPadding(context);
                AppResponsive.getGridCrossAxisCount(context);
                AppResponsive.getAdaptiveSpacing(context);
                
                return const Scaffold(
                  body: Center(
                    child: Text('Responsive helpers work'),
                  ),
                );
              },
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        expect(find.text('Responsive helpers work'), findsOneWidget);
      }
    );

    testWidgets('AppResponsive adaptive spacing works',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final spacing = AppResponsive.getAdaptiveSpacing(
                  context,
                  mobile: 8.0,
                  tablet: 16.0,
                  desktop: 24.0,
                );
                return Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(spacing),
                    child: const Text('Adaptive Spacing'),
                  ),
                );
              },
            ),
          ),
        );
        
        expect(find.text('Adaptive Spacing'), findsOneWidget);
      }
    );
  });

  group('Login/Signup Integration Tests', () {
    testWidgets('LoginScreen text fields are visible and usable',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: LoginScreen(onAuthenticated: _noop),
        ));
        
        expect(find.byType(TextFormField), findsWidgets);
        expect(find.byType(FilledButton), findsOneWidget);
      }
    );

    testWidgets('SignupScreen shows all required fields',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: SignupScreen(onCreated: _noop),
        ));
        
        await tester.pump();
        
        expect(find.byType(TextFormField), findsWidgets);
        // Scoped to the button: the AppBar title carries the same text and
        // the submit button sits below the fold in the lazy ListView, so a
        // bare find.text is order/viewport-dependent (finds 1 or 2 widgets).
        expect(find.widgetWithText(FilledButton, 'Create account'),
            findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Confirm password'), findsOneWidget);
      }
    );
  });

  group('Material 3 Theme Tests', () {
    testWidgets('Theme uses Material 3 colors',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
          home: const Scaffold(
            body: Center(child: Text('Material 3')),
          ),
        ));
        
        expect(find.text('Material 3'), findsOneWidget);
      }
    );
  });
}

void _noop() {}
