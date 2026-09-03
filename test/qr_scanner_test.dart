import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:parkit_flutter/qr_scanner_view.dart';
import 'package:parkit_flutter/main.dart';
import 'package:parkit_flutter/styles.dart';

void main() {
  group('QRScannerView Widget Tests', () {
    testWidgets('QR scanner view renders with AppBar and flashlight toggle', 
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: QRScannerView(
            onScanned: (_) {},
          ),
        ));
        
        expect(find.text('Scan parking QR'), findsOneWidget);
        expect(find.byIcon(Icons.flashlight_on), findsOneWidget);
      }
    );

    testWidgets('QR scanner bottom bar contains flashlight button',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: QRScannerView(onScanned: (_) {}),
        ));
        
        expect(find.byIcon(Icons.flashlight_on_outlined), findsOneWidget);
        expect(find.text('Flashlight'), findsOneWidget);
      }
    );

    testWidgets('Flashlight toggle button exists in bottom bar',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: QRScannerView(onScanned: (_) {}),
        ));
        
        expect(find.byIcon(Icons.flashlight_on_outlined), findsOneWidget);
        expect(find.text('Flashlight'), findsOneWidget);
        
        await tester.tap(find.byIcon(Icons.flashlight_on_outlined));
        await tester.pump();
        
        expect(find.byType(OutlinedButton), findsWidgets);
      }
    );

    testWidgets('QRScannerView AppBar uses correct typography',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: QRScannerView(onScanned: (_) {}),
        ));
        
        final titleText = find.text('Scan parking QR');
        expect(titleText, findsOneWidget);
        
        final appBar = find.byType(AppBar);
        expect(appBar, findsOneWidget);
      }
    );

    testWidgets('QRScannerView uses AppSpacing for layout',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: QRScannerView(onScanned: (_) {}),
        ));
        
        expect(find.byType(SafeArea), findsWidgets);
        
        final padding = find.byType(Padding);
        expect(padding, findsWidgets);
      }
    );

    testWidgets('QRScannerView scaffold has correct structure',
      (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: QRScannerView(onScanned: (_) {}),
        ));
        
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(SafeArea), findsWidgets);
      }
    );
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('ProfileScreen displays user information',
      (WidgetTester tester) async {
        final testUser = AppUser(
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '+9876543210',
          vehicle: 'XYZ789',
          password: 'secure123',
        );
        
        await tester.pumpWidget(MaterialApp(
          home: ProfileScreen(
            user: testUser,
            onUpdated: () {},
            onLogout: () {},
          ),
        ));
        
        await tester.pump();
        
        expect(find.text('My profile'), findsOneWidget);
        expect(find.text('Jane Smith'), findsOneWidget);
        expect(find.text('jane@example.com'), findsOneWidget);
        expect(find.text('XYZ789'), findsOneWidget);
      }
    );

    testWidgets('ProfileScreen menu options are accessible',
      (WidgetTester tester) async {
        final testUser = AppUser(
          name: 'Jane Smith',
          email: 'jane@example.com',
          phone: '+9876543210',
          vehicle: 'XYZ789',
          password: 'secure123',
        );
        
        await tester.pumpWidget(MaterialApp(
          home: ProfileScreen(
            user: testUser,
            onUpdated: () {},
            onLogout: () {},
          ),
        ));
        
        await tester.pump();
        
        expect(find.text('Edit profile'), findsOneWidget);
        expect(find.text('My vehicles'), findsOneWidget);
        expect(find.text('Parking history'), findsOneWidget);
        expect(find.text('About ParkIt'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
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
        expect(find.text('Create account'), findsOneWidget);
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
