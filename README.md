# ParkIt

ParkIt is a Flutter smart-parking application for discovering parking availability, scanning parking QR codes, managing active and historical bookings, and maintaining vehicle and account preferences.

The app is designed as a polished frontend prototype. Authentication and user details are stored locally, while parking availability, booking history, receipts, and notifications use realistic in-app mock data.

## Features

- Local account creation, sign-in, session persistence, and logout
- Responsive dashboard with:
	- Current date and time
	- Active parking session status
	- Availability and utilization metrics
	- Quick actions for scanning, reserving, finding parking, and support
	- Nearby facility previews
	- Parking insights and recent activity
- QR parking scanner powered by `mobile_scanner`
- Booking management with Active, Upcoming, and History tabs
- Instant booking search by facility, slot, vehicle, or date
- Booking status filters, session ending, details, receipt preview, and action feedback
- Profile account center with:
	- Membership and profile completion status
	- Vehicle information
	- Parking statistics
	- Notification preferences
	- Achievement progress
	- Payment, security, privacy, support, and about actions
- ParkIt branding on the in-app header, Android launcher icon, and Android splash screen
- Material 3 theme with centralized colors, spacing, typography, and responsive helpers

## Screens

| Screen | Purpose |
| --- | --- |
| Login | Authenticate an existing local account |
| Create account | Register user, contact, vehicle, and password details |
| Home | Monitor availability, active session, facilities, and parking insights |
| Bookings | Search, filter, review, and manage parking bookings |
| QR scanner | Scan a parking QR code and return the scanned value |
| Profile | Manage account, vehicle, preferences, and support actions |
| Booking details | Review a booking and open its receipt |
| Receipt | View receipt information and trigger mock share/download actions |

## Tech Stack

- Flutter and Dart
- Material 3
- `mobile_scanner` for QR scanning
- `shared_preferences` for local account and session storage
- `intl` for date and time formatting
- `google_fonts` for Roboto typography

## Requirements

- Flutter SDK compatible with Dart `>=3.0.0 <4.0.0`
- Android Studio or Xcode for mobile builds
- A connected Android/iOS device or emulator for device testing

## Getting Started

From the project directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

To run on a particular device:

```bash
flutter devices
flutter run -d <device-id>
```

## Project Structure

```text
lib/
	main.dart             App entry point, authentication, navigation, and screens
	qr_scanner_view.dart  QR scanner interface and torch controls
	styles.dart           AppColors, AppSpacing, AppText, and responsive helpers
	widgets.dart          Shared labels, metrics, actions, and buttons
assets/
	images/
		parkit_logo.png     App and launcher branding asset
test/
	widget_test.dart      Login and account creation smoke tests
	qr_scanner_test.dart  Scanner, profile, design-system, responsive, and theme tests
```

## Local Data

`LocalStore` in [lib/main.dart](lib/main.dart) stores the local user profile and login state with `SharedPreferences`. No backend, remote database, payment gateway, or external parking service is required to run the prototype.

Parking bookings and other UI content are intentionally mock data so the main workflows can be demonstrated offline.

## Design System

Shared visual values live in [lib/styles.dart](lib/styles.dart):

- `AppColors` for the ParkIt palette and status colors
- `AppSpacing` for consistent padding, gaps, radii, and control sizes
- `AppText` for headings, body text, labels, metrics, and scanner typography
- `AppResponsive` for mobile, tablet, desktop, adaptive spacing, and content widths

The logo asset is registered in [pubspec.yaml](pubspec.yaml) and reused by the Flutter UI and Android branding resources.

## Fonts

The app currently uses Roboto through `google_fonts`. Instructions for adding licensed local fonts such as Product Sans or Aptos are available in [CUSTOM_FONTS_SETUP.md](CUSTOM_FONTS_SETUP.md).

## Testing

Run all tests with:

```bash
flutter test
```

The test suite covers the QR scanner widget structure, scanner controls, profile rendering, authentication forms, Material 3 configuration, design-system usage, and responsive helper execution.

## Building

Android debug build:

```bash
flutter build apk --debug
```

Android release build:

```bash
flutter build apk --release
```

Before publishing a production build, replace mock workflows with backend services, secure authentication, real payment processing, and a production QR validation flow.
