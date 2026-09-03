# ParkIt Custom Fonts Setup Guide

## Current Font Configuration

The ParkIt Flutter app currently uses **Google Fonts** (Roboto) as the primary font fallback via the `google_fonts` package. This ensures cross-platform compatibility and automatic font loading without manual file management.

## Typography Hierarchy

- **Product Sans** → Primary (preferred, requires manual acquisition)
- **Aptos** → Secondary (preferred, Microsoft proprietary)  
- **Roboto** → Fallback (via Google Fonts, currently active)

## Adding Custom Fonts Locally

If you acquire Product Sans and/or Aptos font files, follow these steps to bundle them with the app:

### 1. Prepare Font Files

Place `.ttf` or `.otf` font files in the `assets/fonts/` directory:

```
assets/
  fonts/
    ProductSans/
      ProductSans-Regular.ttf
      ProductSans-Bold.ttf
      ProductSans-Medium.ttf
      ProductSans-Light.ttf
    Aptos/
      Aptos-Regular.ttf
      Aptos-Bold.ttf
      Aptos-Medium.ttf
      Aptos-SemiBold.ttf
    Roboto/
      Roboto-Regular.ttf
      Roboto-Bold.ttf
      Roboto-Medium.ttf
```

### 2. Update `pubspec.yaml`

Add font declarations under the `flutter:` section:

```yaml
flutter:
  fonts:
    - family: ProductSans
      fonts:
        - asset: assets/fonts/ProductSans/ProductSans-Regular.ttf
        - asset: assets/fonts/ProductSans/ProductSans-Light.ttf
          weight: 300
        - asset: assets/fonts/ProductSans/ProductSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/ProductSans/ProductSans-Bold.ttf
          weight: 700
        - asset: assets/fonts/ProductSans/ProductSans-Bold.ttf
          weight: 800
    - family: Aptos
      fonts:
        - asset: assets/fonts/Aptos/Aptos-Regular.ttf
        - asset: assets/fonts/Aptos/Aptos-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Aptos/Aptos-Bold.ttf
          weight: 700
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto/Roboto-Regular.ttf
        - asset: assets/fonts/Roboto/Roboto-Medium.ttf
          weight: 500
        - asset: assets/fonts/Roboto/Roboto-Bold.ttf
          weight: 700
```

### 3. Update Font References in `lib/styles.dart`

Replace GoogleFonts calls with local fonts:

```dart
class AppText {
  // Use local Product Sans
  static final TextStyle screenTitle = TextStyle(
    fontFamily: 'ProductSans',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.ink,
  );

  // Use local Aptos
  static final TextStyle sectionTitle = TextStyle(
    fontFamily: 'Aptos',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  // Use local Roboto as fallback
  static final TextStyle body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
  // ... rest of the styles
}
```

### 4. Run the App

```bash
flutter pub get
flutter run
```

## Acquiring Font Files

### Google Fonts (Open Source)
- **Roboto**: Available from [fonts.google.com](https://fonts.google.com/specimen/Roboto)
- Direct download: `https://fonts.google.com/?query=roboto`

### Microsoft Fonts
- **Aptos**: Included with Windows 11; can be extracted from `C:\Windows\Fonts\aptos.ttf`
- **Cascadia Code**: Available for free from Microsoft's repository

### Google Proprietary Fonts  
- **Product Sans**: Proprietary Google Font; not freely available for external use
- Alternative: Use similar open-source fonts like **Rubik** or **Inter**

## Font Attribution

When using custom fonts, ensure proper attribution:

1. Include font license files in the app bundle or documentation
2. Display attribution in the About screen or settings
3. Respect the license terms (most Google Fonts use OFL/Apache 2.0)

## Testing Custom Fonts

After bundling custom fonts:

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check that fonts load correctly in the UI
```

## Fallback Behavior

The app is configured with a fallback chain:
1. Custom bundled fonts (if added)
2. Google Fonts (if available online)
3. System default fonts (as last resort)

This ensures the app always displays readable text, even if custom fonts fail to load.

## References

- [Flutter Fonts Documentation](https://flutter.dev/docs/cookbook/design/fonts)
- [Google Fonts Repository](https://github.com/google/fonts)
- [Material 3 Typography](https://m3.material.io/styles/typography/overview)
