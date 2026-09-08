import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'parking_rate.dart';
import 'payment_screen.dart';
import 'vehicle_data.dart';
import 'session_details_screen.dart';
import 'qr_scanner_view.dart';
import 'widgets.dart';
import 'styles.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ParkitApp());

class AppUser {
  const AppUser({required this.name, required this.email, required this.phone, required this.vehicle, required this.password});
  final String name;
  final String email;
  final String phone;
  final String vehicle;
  final String password;

  AppUser copyWith({String? name, String? email, String? phone, String? vehicle, String? password}) => AppUser(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        vehicle: vehicle ?? this.vehicle,
        password: password ?? this.password,
      );
}

class LocalStore {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<AppUser?> readUser() async {
    final prefs = await _prefs;
    final values = ['name', 'email', 'phone', 'vehicle', 'password'].map(prefs.getString).toList();
    if (values.any((value) => value == null)) return null;
    return AppUser(name: values[0]!, email: values[1]!, phone: values[2]!, vehicle: values[3]!, password: values[4]!);
  }

  Future<void> saveUser(AppUser user) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString('name', user.name),
      prefs.setString('email', user.email),
      prefs.setString('phone', user.phone),
      prefs.setString('vehicle', user.vehicle),
      prefs.setString('password', user.password),
    ]);
  }

  Future<bool> isLoggedIn() async => (await _prefs).getBool('logged_in') ?? false;
  Future<void> setLoggedIn(bool value) async => (await _prefs).setBool('logged_in', value);

  static const _vehiclesKey = 'vehicles';
  static const _activeVehicleKey = 'active_vehicle';

  /// All user vehicles as {number, type, model} maps.
  Future<List<Map<String, String>>> readVehicles() async {
    final raw = (await _prefs).getString(_vehiclesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveVehicles(List<Map<String, String>> vehicles) async =>
      (await _prefs).setString(_vehiclesKey, jsonEncode(vehicles));

  Future<String?> readActiveVehicle() async =>
      (await _prefs).getString(_activeVehicleKey);

  Future<void> saveActiveVehicle(String number) async =>
      (await _prefs).setString(_activeVehicleKey, number);
}

class ParkitApp extends StatelessWidget {
  const ParkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ParkIt',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          surface: AppColors.surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.indicatorBg,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          elevation: 8,
          height: 80,
          labelTextStyle: WidgetStatePropertyAll(AppText.formLabel),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: AppColors.primary, size: 28);
            }
            return const IconThemeData(color: AppColors.secondaryText, size: 24);
          }),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _store = LocalStore();
  late Future<bool> _session;

  @override
  void initState() {
    super.initState();
    _session = _store.isLoggedIn();
  }

  void _refresh() {
    _refreshSession();
  }

  Future<void> _refreshSession() async {
    final loggedIn = await _store.isLoggedIn();
    if (mounted) setState(() => _session = Future.value(loggedIn));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _session,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snapshot.data! ? MainShell(onLogout: _refresh) : LoginScreen(onAuthenticated: _refresh);
        },
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onAuthenticated, super.key});
  final VoidCallback onAuthenticated;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _store = LocalStore();
  bool _hidden = true;
  bool _busy = false;

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final user = await _store.readUser();
    if (!mounted) return;
    if (user == null || user.email.toLowerCase() != _email.text.trim().toLowerCase() || user.password != _password.text) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No matching account found. Please check your details.')));
      return;
    }
    await _store.setLoggedIn(true);
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(28, 28, 28, 20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _BrandMark(),
          const SizedBox(height: 48),
          Text('Welcome back', style: AppText.welcTitle),
          const SizedBox(height: 8),
          Text('Smart parking management, made effortless.', style: AppText.subtitle),
          const SizedBox(height: 32),
          appLabel('Email address'),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (value) => value == null || value.trim().isEmpty ? 'Email is required' : !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? 'Enter a valid email' : null),
          const SizedBox(height: 18),
          appLabel('Password'),
          TextFormField(controller: _password, obscureText: _hidden, decoration: InputDecoration(hintText: 'Enter your password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(tooltip: 'Show or hide password', onPressed: () => setState(() => _hidden = !_hidden), icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (value) => value == null || value.isEmpty ? 'Password is required' : value.length < 6 ? 'Use at least 6 characters' : null),
          const SizedBox(height: 26),
          SizedBox(width: double.infinity, height: AppSpacing.buttonHeight, child: FilledButton(onPressed: _busy ? null : _login, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in'))),
          const SizedBox(height: 22),
          Center(child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignupScreen(onCreated: widget.onAuthenticated))), child: const Text('Create an account'))),
        ])))))),
      );
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({required this.onCreated, super.key});
  final VoidCallback onCreated;
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _phone = TextEditingController(), _vehicle = TextEditingController(), _password = TextEditingController(), _confirm = TextEditingController();
  bool _hidden = true;

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await LocalStore().saveUser(AppUser(name: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), vehicle: _vehicle.text.trim().toUpperCase(), password: _password.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Sign in to continue.')));
    Navigator.pop(context);
  }

  String? _required(String? value, String label) => value == null || value.trim().isEmpty ? '$label is required' : null;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Create account', style: AppText.formLabel)), body: SafeArea(child: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 32), children: [
        Text('Your parking profile', style: AppText.cardTitle), const SizedBox(height: 8), Text('Keep your details ready for a faster parking experience.', style: AppText.subtitle), const SizedBox(height: 26),
        _field('Full name', _name, Icons.person_outline_rounded, (v) => _required(v, 'Full name')),
        _field('Email address', _email, Icons.mail_outline_rounded, (v) => _required(v, 'Email') ?? (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim()) ? 'Enter a valid email' : null), keyboard: TextInputType.emailAddress),
        _field('Phone number', _phone, Icons.phone_outlined, (v) => _required(v, 'Phone number'), keyboard: TextInputType.phone),
        _field('Vehicle number', _vehicle, Icons.directions_car_outlined, (v) => _required(v, 'Vehicle number') ?? (RegExp(r'^[A-Za-z0-9 -]{2,12}$').hasMatch(v!.trim()) ? null : 'Enter a valid vehicle number')),
        _field('Password', _password, Icons.lock_outline_rounded, (v) => v == null || v.length < 6 ? 'Use at least 6 characters' : null, obscure: _hidden, toggle: () => setState(() => _hidden = !_hidden)),
        _field('Confirm password', _confirm, Icons.lock_reset_outlined, (v) => v != _password.text ? 'Passwords do not match' : null, obscure: _hidden),
        const SizedBox(height: 14), SizedBox(height: AppSpacing.buttonHeight, child: FilledButton(onPressed: _create, child: const Text('Create account'))), const SizedBox(height: 8), TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to login')),
      ]))));

  Widget _field(String label, TextEditingController controller, IconData icon, String? Function(String?) validator, {TextInputType? keyboard, bool obscure = false, VoidCallback? toggle}) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: controller, keyboardType: keyboard, obscureText: obscure, validator: validator, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: toggle == null ? null : IconButton(onPressed: toggle, icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))));
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Row(children: [ClipRRect(borderRadius: BorderRadius.circular(AppSpacing.radiusSmall), child: Image.asset('assets/images/parkit_logo.png', width: AppSpacing.iconButtonSize, height: AppSpacing.iconButtonSize, fit: BoxFit.cover)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ParkIt', style: AppText.button.copyWith(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.ink)), Text('SMART PARKING', style: AppText.uppercaseLabel)])]);
}

class MainShell extends StatefulWidget {
  const MainShell({required this.onLogout, super.key});
  final VoidCallback onLogout;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  AppUser? _user;
  final _store = LocalStore();
  final _activeCount = ValueNotifier<int>(1);
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() {
    _activeCount.dispose();
    super.dispose();
  }

  Future<void> _load() async { final user = await _store.readUser(); if (mounted) setState(() => _user = user); }
  Future<void> _logout() async { await _store.setLoggedIn(false); widget.onLogout(); }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [_HomePage(user: user), HistoryScreen(activeCount: _activeCount), ProfileScreen(user: user, onUpdated: _load, onLogout: _logout)];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: IndexedStack(
          key: ValueKey<int>(_tab),
          index: _tab,
          children: pages,
        ),
      ),
      bottomNavigationBar: _BottomDock(
        tab: _tab,
        bookingCount: _activeCount,
        onHome: () => _selectTab(0),
        onScan: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ScanScreen()));
        },
        onBookings: () => _selectTab(1),
        onProfile: () => _selectTab(2),
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    HapticFeedback.lightImpact();
    setState(() => _tab = index);
  }
}

/// Floating glass-clay bottom dock: frosted translucent bar, soft clay
/// shadows, animated active pill, center-emphasized Scan action and a
/// live badge with the active booking count.
class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.tab,
    required this.bookingCount,
    required this.onHome,
    required this.onScan,
    required this.onBookings,
    required this.onProfile,
  });

  final int tab;
  final ValueNotifier<int> bookingCount;
  final VoidCallback onHome;
  final VoidCallback onScan;
  final VoidCallback onBookings;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          // Frosted glass background.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9)),
                  boxShadow: [
                    // Clay depth: soft dark drop + gentle top light.
                    BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 12)),
                    BoxShadow(
                        color:
                            Colors.white.withValues(alpha: 0.9),
                        blurRadius: 2,
                        offset: const Offset(0, -1)),
                  ],
                ),
                // Four uniform slots: identical size, icons and labels.
                // Scan is a regular tab that opens the scanner overlay.
                child: Row(children: [
                  Expanded(
                    child: _DockTab(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: tab == 0,
                      onTap: onHome,
                    ),
                  ),
                  Expanded(
                    child: _DockTab(
                      icon: Icons.qr_code_scanner_outlined,
                      selectedIcon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                      selected: false,
                      onTap: onScan,
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<int>(
                      valueListenable: bookingCount,
                      builder: (_, count, __) => _DockTab(
                        icon: Icons.receipt_long_outlined,
                        selectedIcon: Icons.receipt_long_rounded,
                        label: 'Bookings',
                        selected: tab == 1,
                        badgeCount: count,
                        onTap: onBookings,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _DockTab(
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: 'Profile',
                      selected: tab == 2,
                      onTap: onProfile,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Single dock tab with an animated glass-clay active pill.
class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primary : AppColors.secondaryText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        // Monotonic curve: easeOutBack overshoots and makes neighbours
        // visually collide mid-animation.
        scale: selected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.indicatorBg.withValues(alpha: 0.85)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.9))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800)),
              backgroundColor: AppColors.error,
              child: Icon(selected ? selectedIcon : icon,
                  color: color, size: 25),
            ),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: color)),
          ]),
        ),
      ),
    );
  }
}



class _HomePage extends StatefulWidget {
  const _HomePage({required this.user});
  final AppUser user;
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late DateTime _entryTime;
  late DateTime _now;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Demo session started 1h 26m 43s ago; ticks live every second.
    _entryTime = DateTime.now()
        .subtract(const Duration(hours: 1, minutes: 26, seconds: 43));
    _now = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _duration => _now.difference(_entryTime);

  void _openSession() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ParkingSessionDetailsScreen(
              status: 'Active',
              slot: 'A-17',
              zone: 'Visitor Parking',
              vehicleNumber: widget.user.vehicle,
              facility: 'REC Main Parking',
              ownerName: widget.user.name)));

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final fee = parkingFeeFor(_duration);
    return SafeArea(child: LayoutBuilder(builder: (context, _) {
      final contentWidth = AppResponsive.getMaxContentWidth(context);
      return ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
          children: [
            Center(
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const _BrandMark(), Stack(children: [IconButton(onPressed: () => _showNotifications(context), tooltip: 'Notifications', icon: const Icon(Icons.notifications_none_rounded)), Positioned(right: 8, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))])]),
                          const SizedBox(height: 24),
                          Text('Welcome, ${user.name.split(' ').first}',
                              style: AppText.welcTitle),
                          const SizedBox(height: 5),
                          // Display date and time on a single line without wrapping.
                          // Desired format: dd MMM yyyy - hh:mmAM/PM (e.g., 08 Sep 2026 - 06:10PM).
                          // We format the date and time separately, then concatenate
                          // them with the required separator and remove the space that
                          // `DateFormat` inserts before the AM/PM marker.
                          Builder(builder: (context) {
                            final now = DateTime.now();
                            final dateStr = DateFormat('dd MMM yyyy').format(now);
                            // "hh:mm a" yields "06:10 PM" – we strip the space.
                            final timeStr = DateFormat('hh:mm a').format(now).replaceAll(' ', '');
                            final combined = '$dateStr - $timeStr';
                            return Text(
                              combined,
                              style: AppText.subtitle,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                          const SizedBox(height: 24),
                          Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.large),
                              decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusLarge)),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('ACTIVE PARKING SESSION',
                                              style:
                                                  AppText.uppercaseLabel),
                                          Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color: AppColors
                                                                .accent,
                                                            shape: BoxShape
                                                                .circle)),
                                                const SizedBox(width: 6),
                                                Text('PARKED',
                                                    style: AppText.formLabel
                                                        .copyWith(
                                                            color: AppColors
                                                                .accent)),
                                              ]),
                                        ]),
                                    const SizedBox(height: 12),
                                    Text('Slot A-17',
                                        style: AppText.slotNumber),
                                    Text(
                                        'Visitor Zone  •  ${user.vehicle}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.metricLabel),
                                    const SizedBox(height: 14),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          '${formatDurationClock(_duration)}  •  ₹$fee current fee',
                                          maxLines: 1,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                        '₹20 first hour · then ₹10 / 30 min',
                                        style: TextStyle(
                                            color: Colors.white.withValues(
                                                alpha: 0.6),
                                            fontSize: 12)),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                            onPressed: _openSession,
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(
                                                    color: Colors.white38)),
                                            child:
                                                const Text('View session'))),
                                  ])),
                          const SizedBox(height: 16),
                          Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.large),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusLarge),
                                  border: Border.all(
                                      color: AppColors.borderLight)),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                              color:
                                                  AppColors.indicatorBg,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12)),
                                          child: const Icon(
                                              Icons
                                                  .payments_outlined,
                                              color: AppColors.primary,
                                              size: 22)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text('Parking rates',
                                                style: AppText.cardTitle
                                                    .copyWith(
                                                        fontSize: 17)),
                                            Text(
                                                'Simple community tariff',
                                                style: AppText.caption),
                                          ])),
                                    ]),
                                    const SizedBox(height: 12),
                                    const _RateRow(
                                        label: 'First hour',
                                        value: '₹20'),
                                    const _RateRow(
                                        label: 'Every 30 min after',
                                        value: '₹10'),
                                    const _RateRow(
                                        label: 'Daily maximum',
                                        value: '₹150',
                                        last: true),
                                  ])),
                          const SizedBox(height: 24),
                          Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.large),
                              decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusLarge)),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('PARKING AVAILABILITY',
                                              style:
                                                  AppText.uppercaseLabel),
                                          Text('73% free',
                                              style: AppText.metricLabel)
                                        ]),
                                    const SizedBox(height: 14),
                                    ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        child: const LinearProgressIndicator(
                                            value: .73,
                                            minHeight: 8,
                                            backgroundColor:
                                                Color(0xFF3D504A),
                                            color: AppColors.accent)),
                                    const SizedBox(height: 20),
                                    const Row(children: [
                                      _Metric(
                                          value: '248',
                                          label: 'Available'),
                                      _Metric(
                                          value: '92', label: 'Occupied'),
                                      _Metric(value: '340', label: 'Total')
                                    ]),
                                  ])),
                          const SizedBox(height: 8),
                        ]))),
          ]);
    }));
  }

  void _showNotifications(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('Notifications',
                                style: AppText.sectionTitle)),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              showParkitSnack(context, 'All caught up — no new alerts',
                                  icon: Icons.mark_email_read_outlined);
                            },
                            child: const Text('Mark all read')),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: const [
                        _NotificationTile(
                            icon: Icons.local_parking_rounded,
                            title: 'Parking session active',
                            body: 'Your vehicle is parked in slot A-17.',
                            time: '2m ago',
                            unread: true),
                        _NotificationTile(
                            icon: Icons.payments_outlined,
                            title: 'Payment completed',
                            body: 'Your latest receipt is ready.',
                            time: '1h ago'),
                        _NotificationTile(
                            icon: Icons.event_available_rounded,
                            title: 'Reservation reminder',
                            body: 'Your reservation starts tomorrow.',
                            time: 'Yesterday'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      );

}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.icon, required this.title, required this.body, required this.time, this.unread = false});
  final IconData icon;
  final String title, body, time;
  final bool unread;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: unread ? AppColors.indicatorBg.withValues(alpha: 0.45) : const Color(0xFFF5F7F6),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.borderLight)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))), if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))]),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
            const SizedBox(height: 4),
            Text(time, style: AppText.caption.copyWith(fontSize: 12)),
          ])),
        ]),
      );
}

class _Metric extends StatelessWidget { const _Metric({required this.value, required this.label}); final String value, label; @override Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: AppText.metricValue), const SizedBox(height: 4), Text(label, style: AppText.metricLabel)])); }

/// Single tariff row used by the Home parking-rates card.
class _RateRow extends StatelessWidget {
  const _RateRow(
      {required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 8),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle.copyWith(fontSize: 14))),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ]),
      );
}
class ScanScreen extends StatelessWidget { const ScanScreen({super.key}); @override Widget build(BuildContext context) => QRScannerView(onScanned: (code) {
    // Process the scanned QR code – for now just show a snackbar and pop.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: $code')));
    Navigator.of(context).pop();
  }); }

class _Booking {
  _Booking({required this.facility, required this.slot, required this.vehicle, required this.date, required this.duration, required this.amount, required this.status, this.active = false, this.upcoming = false});
  final String facility, slot, vehicle, date, duration, amount;
  String status;
  bool active, upcoming;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.activeCount});
  @override State<HistoryScreen> createState() => _HistoryScreenState();

  /// Live notifier for the dock badge. When omitted (e.g. tests), the
  /// screen tracks the count privately.
  final ValueNotifier<int>? activeCount;
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'All';
  final _bookings = <_Booking>[
    _Booking(facility: 'REC Main Parking', slot: 'A-17', vehicle: 'TN07AB1234', date: 'Today, 9:14 AM', duration: '01h 26m', amount: '₹42', status: 'Active', active: true),
    _Booking(facility: 'Visitor Parking Block A', slot: 'V-08', vehicle: 'TN07AB1234', date: 'Tomorrow, 10:30 AM', duration: '2 hours', amount: '₹60', status: 'Reserved', upcoming: true),
    _Booking(facility: 'Academic Block Parking', slot: 'C-22', vehicle: 'TN07AB1234', date: '18 August 2026', duration: '1h 42m', amount: '₹65', status: 'Completed'),
    _Booking(facility: 'REC Main Parking', slot: 'B-108', vehicle: 'TN07AB1234', date: '04 August 2026', duration: '2h 10m', amount: '₹82', status: 'Paid'),
    _Booking(facility: 'Library Parking', slot: 'L-14', vehicle: 'TN07AB1234', date: '28 July 2026', duration: '45m', amount: '₹24', status: 'Completed'),
    _Booking(facility: 'REC Main Parking', slot: 'A-04', vehicle: 'TN07AB1234', date: '15 July 2026', duration: '3h 05m', amount: '₹110', status: 'Completed'),
    _Booking(facility: 'Visitor Parking Block A', slot: 'V-19', vehicle: 'TN07AB1234', date: '02 July 2026', duration: '1h 12m', amount: '₹38', status: 'Cancelled'),
    _Booking(facility: 'Academic Block Parking', slot: 'C-11', vehicle: 'TN07AB1234', date: '28 June 2026', duration: '2h 30m', amount: '₹90', status: 'Completed'),
  ];

  static const _filterOptions = [
    'All',
    'Active',
    'Reserved',
    'Completed',
    'Paid',
    'Cancelled',
  ];

  ValueNotifier<int>? _ownedCount;
  ValueNotifier<int> get _counter =>
      widget.activeCount ?? (_ownedCount ??= ValueNotifier(1));

  @override
  void initState() {
    super.initState();
    _syncCount();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _ownedCount?.dispose();
    super.dispose();
  }

  void _syncCount() {
    _counter.value = _bookings.where((item) => item.active).length;
  }

  List<_Booking> get _activeBookings =>
      _bookings.where((item) => item.active).toList();
  List<_Booking> get _upcomingBookings =>
      _bookings.where((item) => item.upcoming).toList();
  List<_Booking> get _pastBookings => _bookings
      .where((item) => !item.active && !item.upcoming)
      .toList();

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'parked':
      case 'paid':
        return const Color(0xFF1B9E6B);
      case 'reserved':
      case 'upcoming':
        return const Color(0xFF2563EB);
      case 'cancelled':
      case 'expired':
        return AppColors.error;
      default:
        return AppColors.secondaryText;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('Bookings', style: AppText.appBarTitle),
            actions: [
              IconButton(
                  onPressed: () => _showFilters(context),
                  tooltip: 'Filter bookings',
                  icon: Badge(
                    isLabelVisible: _filter != 'All',
                    child: const Icon(Icons.tune_rounded),
                  )),
            ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search date, slot, vehicle or facility',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ))),
          if (_filter != 'All')
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 4),
                    child: Chip(
                        label: Text(_filter),
                        onDeleted: () =>
                            setState(() => _filter = 'All')))),
          TabBar(controller: _tabs, tabs: [
            Tab(text: 'Active (${_activeBookings.length})'),
            Tab(text: 'Upcoming (${_upcomingBookings.length})'),
            Tab(text: 'History (${_pastBookings.length})'),
          ]),
          Expanded(
              child: TabBarView(controller: _tabs, children: [
            _list(_activeBookings, _EmptyState.active),
            _list(_upcomingBookings, _EmptyState.upcoming),
            _list(_pastBookings, _EmptyState.history),
          ])),
        ]),
      );

  Widget _list(List<_Booking> source, _EmptyState empty) {
    final results = source
        .where((item) => _filter == 'All' || item.status == _filter)
        .where((item) =>
            '${item.facility} ${item.slot} ${item.vehicle} ${item.date}'
                .toLowerCase()
                .contains(_query))
        .toList();
    if (results.isEmpty) return _emptyView(empty);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() {});
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: results.length,
        itemBuilder: (context, index) =>
            _bookingCard(results[index]),
      ),
    );
  }

  Widget _bookingCard(_Booking booking) {
    final color = _statusColor(booking.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: () => _showDetails(context, booking),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(booking.facility,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.formLabel),
              ),
              const SizedBox(width: 10),
              _statusPill(booking.status, color),
            ]),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Slot ${booking.slot}',
                            style: AppText.cardTitle
                                .copyWith(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text('${booking.vehicle}  •  ${booking.date}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.subtitle
                                .copyWith(fontSize: 14)),
                      ]),
                ),
                if (booking.active) ...[
                  const SizedBox(width: 10),
                  const _LiveBadge(),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(booking.duration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 13)),
              ),
              Text(booking.amount,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              _cardAction(booking),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Contextual action per booking state; ending/cancelling moves the
  /// booking across tabs because [active]/[upcoming] are updated too.
  Widget _cardAction(_Booking booking) {
    if (booking.active) {
      return FilledButton(
        onPressed: () => _confirmEnd(booking),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          minimumSize: const Size(0, 40),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('End session',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
    }
    if (booking.upcoming) {
      return OutlinedButton(
        onPressed: () => _confirmCancel(booking),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          minimumSize: const Size(0, 40),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Cancel',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
    }
    return OutlinedButton(
      onPressed: () => _showDetails(context, booking),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Receipt',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statusPill(String status, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color)),
      );

  Widget _emptyView(_EmptyState kind) {
    final (icon, title, body) = switch (kind) {
      _EmptyState.active => (
          Icons.local_parking_rounded,
          'No active sessions',
          'Your live parking sessions will appear here.'
        ),
      _EmptyState.upcoming => (
          Icons.event_available_rounded,
          'No upcoming reservations',
          'Future reservations will appear here.'
        ),
      _EmptyState.history => (
          Icons.receipt_long_outlined,
          'No bookings found',
          'Try a different search or filter.'
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.indicatorBg,
                borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center, style: AppText.caption),
        ]),
      ),
    );
  }

  void _confirmEnd(_Booking booking) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('End parking session?'),
          content: Text(
              'Slot ${booking.slot} will be released. The final bill settles automatically via UPI.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Keep parking')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  final fee = int.tryParse(booking.amount.replaceAll(
                          RegExp(r'[^0-9]'), '')) ??
                      0;
                  final tax = parkingTaxFor(fee);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentScreen(
                        payment: ParkingPayment(
                          receiptId:
                              'PKT-2026-${booking.slot.replaceAll('-', '')}',
                          slot: booking.slot,
                          vehicle: booking.vehicle,
                          facility: booking.facility,
                          entryLabel: booking.date,
                          durationLabel: booking.duration,
                          fee: fee,
                          tax: tax,
                        ),
                        onPaid: () {
                          if (!mounted) return;
                          setState(() {
                            booking.status = 'Completed';
                            booking.active = false;
                          });
                          _syncCount();
                        },
                      ),
                    ),
                  );
                },
                child: const Text('End session')),
          ],
        ),
      );

  void _confirmCancel(_Booking booking) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel reservation?'),
          content: Text(
              'Slot ${booking.slot} (${booking.date}) will be released.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Keep it')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  setState(() {
                    booking.status = 'Cancelled';
                    booking.upcoming = false;
                  });
                  _syncCount();
                  showParkitSnack(
                      context, 'Reservation cancelled',
                      icon: Icons.cancel_outlined);
                },
                child: const Text('Cancel booking')),
          ],
        ),
      );

  void _showFilters(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 20),
            child: SingleChildScrollView(
              child:
                  Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Filter by status',
                        style: AppText.cardTitle.copyWith(fontSize: 17)),
                  ),
                ),
                const SizedBox(height: 6),
                for (final filter in _filterOptions)
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: Icon(
                        filter == 'All'
                            ? Icons.filter_alt_outlined
                            : Icons.circle,
                        size: filter == 'All' ? 22 : 12,
                        color: filter == 'All'
                            ? AppColors.primary
                            : _statusColor(filter)),
                    title: Text(filter,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: _filter == filter
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _filter = filter);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ]),
            ),
          ),
        ),
      );

  void _showDetails(BuildContext context, _Booking booking) {
    final slot = booking.slot;
    final zone = slot.startsWith('V')
        ? 'Visitor Parking'
        : slot.startsWith('C')
            ? 'Zone B'
            : slot.startsWith('L')
                ? 'Library Zone'
                : 'Visitor Parking';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParkingSessionDetailsScreen(
          status: booking.status,
          slot: slot,
          zone: zone,
          vehicleNumber: booking.vehicle,
          facility: booking.facility,
        ),
      ),
    );
  }
}

enum _EmptyState { active, upcoming, history }

/// Pulsing "LIVE" marker for the active booking card.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B9E6B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.35).animate(_controller),
            child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF1B9E6B), shape: BoxShape.circle)),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF1B9E6B))),
        ]),
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.user, required this.onUpdated, required this.onLogout, super.key});
  final AppUser user;
  final VoidCallback onUpdated, onLogout;
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, String>> _vehicles = [];
  String? _activeNumber;
  bool _loadingVehicles = true;
  bool _parkingAlerts = true, _bookingAlerts = true, _paymentAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    List<Map<String, String>> list = [];
    String? active;
    try {
      final store = LocalStore();
      list = await store.readVehicles();
      active = await store.readActiveVehicle();
      if (list.isEmpty && widget.user.vehicle.isNotEmpty) {
        list = [
          {
            'number': widget.user.vehicle,
            'type': 'Car',
            'model': 'Hyundai i20'
          }
        ];
        active = widget.user.vehicle;
        await store.saveVehicles(list);
        await store.saveActiveVehicle(active);
      }
    } catch (_) {
      // Storage unavailable (e.g. fresh install): fall back to memory.
      if (widget.user.vehicle.isNotEmpty) {
        list = [
          {
            'number': widget.user.vehicle,
            'type': 'Car',
            'model': 'Hyundai i20'
          }
        ];
        active = widget.user.vehicle;
      }
    }
    if (mounted) {
      setState(() {
        _vehicles = list;
        _activeNumber = active;
        _loadingVehicles = false;
      });
    }
  }

  Map<String, String>? get _activeVehicle {
    final number = _activeNumber ?? widget.user.vehicle;
    for (final vehicle in _vehicles) {
      if (vehicle['number'] == number) return vehicle;
    }
    return _vehicles.isNotEmpty ? _vehicles.first : null;
  }

  Future<void> _handleVehiclesSave(
      List<Map<String, String>> list, String? active) async {
    try {
      final store = LocalStore();
      await store.saveVehicles(list);
      if (active != null) await store.saveActiveVehicle(active);
      if (active != null &&
          active.isNotEmpty &&
          active != widget.user.vehicle) {
        await store.saveUser(widget.user.copyWith(vehicle: active));
      }
    } catch (_) {
      // Keep in-memory state even if storage fails.
    }
    if (!mounted) return;
    setState(() {
      _vehicles = list;
      _activeNumber = active;
    });
    if (active != null &&
        active.isNotEmpty &&
        active != widget.user.vehicle) {
      widget.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _activeVehicle;
    return Scaffold(
      appBar: AppBar(title: Text('My profile', style: AppText.appBarTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _headerCard(),
          const SizedBox(height: 20),
          Text('My Vehicle', style: AppText.cardTitle),
          const SizedBox(height: 10),
          _vehicleCard(vehicle),
          const SizedBox(height: 20),
          Text('Parking Statistics', style: AppText.cardTitle),
          const SizedBox(height: 10),
          const Row(children: [
            _StatCard(value: '42', label: 'Total Visits'),
            SizedBox(width: 10),
            _StatCard(value: '118h', label: 'Hours Parked'),
            SizedBox(width: 10),
            _StatCard(value: '₹1850', label: 'Total Spent'),
          ]),
          const SizedBox(height: 20),
          Text('Account Settings', style: AppText.cardTitle),
          const SizedBox(height: 10),
          _settingsCard(),
          const SizedBox(height: 20),
          _aboutCard(),
        ]),
      ),
    );
  }

  Widget _headerCard() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        ),
        child: Column(children: [
          const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.indicatorBg,
              child: Icon(Icons.person_rounded,
                  size: 44, color: AppColors.primary)),
          const SizedBox(height: 14),
          Text(widget.user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(widget.user.email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditProfileScreen(
                            user: widget.user,
                            onSaved: widget.onUpdated))),
                child: const Text('Edit Profile'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38)),
                child: const Text('Logout'),
              ),
            ),
          ]),
        ]),
      );

  Widget _vehicleCard(Map<String, String>? vehicle) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _loadingVehicles
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator()))
              : vehicle == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          const Text('No vehicle added yet',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Add your vehicle for faster parking.',
                              style: AppText.caption),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                              onPressed: _openManager,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Vehicle')),
                        ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          Row(children: [
                            Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                    color: AppColors.indicatorBg,
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(
                                    iconForVehicleType(
                                        vehicle['type']),
                                    color: AppColors.primary,
                                    size: 28)),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(vehicle['number'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${vehicle['type'] ?? 'Car'} · ${vehicle['model'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption),
                                ])),
                          ]),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                              onPressed: _openManager,
                              icon: const Icon(Icons.garage_outlined),
                              label: const Text('Manage Vehicle')),
                        ]),
        ),
      );

  Widget _settingsCard() => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Column(children: [
          _settingTile(
              'Edit Profile',
              Icons.edit_outlined,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                          user: widget.user,
                          onSaved: widget.onUpdated)))),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _settingTile('Change Password', Icons.lock_outline_rounded,
              _openChangePassword),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _settingTile('Notifications',
              Icons.notifications_none_rounded, _openNotifications),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
              onTap: _confirmLogout,
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Logout',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.secondaryText)),
        ]),
      );

  Widget _settingTile(String label, IconData icon, VoidCallback onTap) =>
      ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondaryText));

  Widget _aboutCard() => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSmall),
                  child: Image.asset('assets/images/parkit_logo.png',
                      width: 48, height: 48, fit: BoxFit.cover)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('ParkIt',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Version 1.0.0', style: AppText.caption),
                    const SizedBox(height: 2),
                    Text('Smart Parking Allocation & Management System',
                        style: AppText.caption),
                  ])),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                  onPressed: _openProjectInfo,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('View Project Info')),
            ),
          ]),
        ),
      );

  void _openManager() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _VehicleManagerSheet(
            vehicles: _vehicles,
            activeNumber: _activeNumber ?? widget.user.vehicle,
            onSave: _handleVehiclesSave,
          ),
        ),
      );

  void _openNotifications() => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => StatefulBuilder(
          builder: (sheetContext, setSheet) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications', style: AppText.sectionTitle),
                    const SizedBox(height: 8),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Parking alerts'),
                        subtitle:
                            const Text('Entry, exit and fee updates'),
                        value: _parkingAlerts,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          setSheet(() {});
                          setState(() => _parkingAlerts = value);
                        }),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Booking alerts'),
                        subtitle:
                            const Text('Reservations and reminders'),
                        value: _bookingAlerts,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          setSheet(() {});
                          setState(() => _bookingAlerts = value);
                        }),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Payment alerts'),
                        subtitle:
                            const Text('Bills and receipts'),
                        value: _paymentAlerts,
                        activeThumbColor: AppColors.primary,
                        onChanged: (value) {
                          setSheet(() {});
                          setState(() => _paymentAlerts = value);
                        }),
                  ]),
            ),
          ),
        ),
      );

  void _openChangePassword() => showDialog<void>(
        context: context,
        builder: (_) => _ChangePasswordDialog(user: widget.user),
      ).then((_) {
        if (mounted) widget.onUpdated();
      });

  void _confirmLogout() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
              'You will need to sign in again to manage parking.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Stay')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  widget.onLogout();
                },
                child: const Text('Logout')),
          ],
        ),
      );

  void _openProjectInfo() => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusLarge)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusSmall),
                  child: Image.asset('assets/images/parkit_logo.png',
                      width: 64, height: 64, fit: BoxFit.cover)),
              const SizedBox(height: 12),
              const Text('ParkIt',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text('Version 1.0.0', style: AppText.caption),
              const SizedBox(height: 8),
              Text('Smart Parking Allocation & Management System',
                  textAlign: TextAlign.center, style: AppText.subtitle),
              const SizedBox(height: 14),
              const _ProjectFeature(
                  icon: Icons.qr_code_rounded,
                  text: 'QR-based gate access passes'),
              const _ProjectFeature(
                  icon: Icons.schedule_rounded,
                  text: 'Live billing with duration tracking'),
              const _ProjectFeature(
                  icon: Icons.local_parking_rounded,
                  text: 'Smart slot allocation & receipts'),
              const SizedBox(height: 12),
              Text('© 2026 ParkIt · Academic project demo',
                  style: AppText.caption),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ),
            ]),
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Column(children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _ProjectFeature extends StatelessWidget {
  const _ProjectFeature({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppColors.indicatorBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 19)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Bottom sheet for vehicle CRUD: add, edit, delete and default vehicle.
class _VehicleManagerSheet extends StatefulWidget {
  const _VehicleManagerSheet(
      {required this.vehicles,
      required this.activeNumber,
      required this.onSave});
  final List<Map<String, String>> vehicles;
  final String activeNumber;
  final void Function(List<Map<String, String>> vehicles, String? active)
      onSave;
  @override
  State<_VehicleManagerSheet> createState() => _VehicleManagerSheetState();
}

class _VehicleManagerSheetState extends State<_VehicleManagerSheet> {
  late final List<Map<String, String>> _vehicles =
      widget.vehicles.map(Map<String, String>.of).toList();
  late String? _active = widget.activeNumber.isEmpty
      ? null
      : widget.activeNumber;

  void _persist() =>
      widget.onSave(_vehicles.map(Map<String, String>.of).toList(), _active);

  Future<void> _addOrEdit({Map<String, String>? existing, int? index}) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _VehicleFormDialog(
        initial: existing,
        takenNumbers: [
          for (var i = 0; i < _vehicles.length; i++)
            if (i != index) _vehicles[i]['number'] ?? ''
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      if (index == null) {
        _vehicles.add(result);
        _active ??= result['number'];
      } else {
        final wasActive = _vehicles[index]['number'] == _active;
        _vehicles[index] = result;
        if (wasActive) _active = result['number'];
      }
    });
    _persist();
    if (mounted) {
      showParkitSnack(
          context,
          index == null ? 'Vehicle added' : 'Vehicle updated',
          icon: Icons.directions_car_rounded);
    }
  }

  Future<void> _delete(int index) async {
    final number = _vehicles[index]['number'] ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('$number will be removed from your profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _vehicles.removeAt(index);
      if (_active == number) {
        _active =
            _vehicles.isNotEmpty ? _vehicles.first['number'] : null;
      }
    });
    _persist();
    if (mounted) {
      showParkitSnack(context, 'Vehicle deleted',
          icon: Icons.delete_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child:
                      Text('Manage vehicles', style: AppText.sectionTitle)),
              IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 8),
            Flexible(
              child: _vehicles.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 20),
                      child: Text('No vehicles yet. Add your first one.',
                          style: AppText.subtitle),
                    )
                  : RadioGroup<String?>(
                      groupValue: _active,
                      onChanged: (value) {
                        setState(() => _active = value);
                        _persist();
                      },
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _vehicles.length,
                        itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];
                        final isActive =
                            vehicle['number'] == _active;
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: isActive
                                ? AppColors.indicatorBg
                                    .withValues(alpha: 0.5)
                                : const Color(0xFFF5F7F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium),
                              side: BorderSide(
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.borderLight),
                            ),
                            child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                            leading: Radio<String?>(
                              value: vehicle['number'],
                              activeColor: AppColors.primary,
                            ),
                            title: Text(vehicle['number'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(
                                '${vehicle['type'] ?? ''} · ${vehicle['model'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      tooltip: 'Edit vehicle',
                                      visualDensity:
                                          VisualDensity.compact,
                                      icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: AppColors.primary),
                                      onPressed: () => _addOrEdit(
                                          existing: vehicle,
                                          index: index)),
                                  IconButton(
                                      tooltip: 'Delete vehicle',
                                      visualDensity:
                                          VisualDensity.compact,
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: Colors.redAccent),
                                      onPressed: () =>
                                          _delete(index)),
                                ]),
                            onTap: () {
                              setState(
                                  () => _active = vehicle['number']);
                              _persist();
                            },
                          ),
                        ),
                        );
                      },
                    ),
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              child: FilledButton.icon(
                  onPressed: () => _addOrEdit(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Vehicle')),
            ),
          ]),
        ),
      );
}

/// Add / edit vehicle form. Returns the vehicle map on save, null on cancel.
class _VehicleFormDialog extends StatefulWidget {
  const _VehicleFormDialog({this.initial, this.takenNumbers = const []});
  final Map<String, String>? initial;
  final List<String> takenNumbers;
  @override
  State<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<_VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number =
      TextEditingController(text: widget.initial?['number'] ?? '');
  late final TextEditingController _type =
      TextEditingController(text: widget.initial?['type'] ?? 'Car');
  late final TextEditingController _model =
      TextEditingController(text: widget.initial?['model'] ?? '');
  TextEditingController? _autoModel;

  @override
  void initState() {
    super.initState();
    // Live number-plate preview while typing.
    _number.addListener(_refresh);
    _model.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _attachAuto(TextEditingController controller) {
    if (identical(_autoModel, controller)) return;
    _autoModel?.removeListener(_refresh);
    _autoModel = controller;
    _autoModel?.addListener(_refresh);
  }

  /// Autocomplete-backed types (Car, Scooty, Mini-Truck, Mini-Van, E-Cycle).
  /// Bike and Auto accept free-text models (no catalog dataset).
  bool get _usesAutocomplete =>
      vehicleKindForLabel(_type.text.trim()) != null;

  String get _modelText {
    if (_usesAutocomplete && _autoModel != null) return _autoModel!.text;
    return _model.text;
  }

  @override
  void dispose() {
    _number.dispose();
    _type.dispose();
    _model.dispose();
    super.dispose();
  }

  String get _previewNumber {
    final text = _number.text.trim().toUpperCase();
    return text.isEmpty ? 'TN07AB1234' : text;
  }

  bool get _numberIsPlaceholder => _number.text.trim().isEmpty;

  String get _previewSubtitle {
    final type = _type.text.trim();
    final model = _model.text.trim();
    if (type.isEmpty && model.isEmpty) return 'Your vehicle preview';
    if (type.isEmpty) return model;
    if (model.isEmpty) return type;
    return '$type · $model';
  }

  void _pickType(String type) {
    if (_type.text.trim() == type) return;
    setState(() => _type.text = type);
  }

  String _modelHintFor(String kind) {
    switch (kind) {
      case 'car':
        return 'Try Brezza, Creta, Swift…';
      case 'scooty':
        return 'Try Activa, Jupiter, Ntorq…';
      case 'miniTruck':
        return 'Try Ace, Jeeto, Dost…';
      case 'miniVan':
        return 'Try Eeco, Omni, Traveller…';
      case 'eCycle':
        return 'Try C6, EMX, One…';
      default:
        return 'Vehicle model';
    }
  }

  String? _validateNumber(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return 'Vehicle number is required';
    if (!RegExp(r'^[A-Za-z0-9 -]{2,12}$').hasMatch(text)) {
      return 'Enter a valid vehicle number';
    }
    if (widget.takenNumbers
        .map((e) => e.toUpperCase())
        .contains(text)) {
      return 'This vehicle is already added';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
        title: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.indicatorBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(iconForVehicleType(_type.text),
                  color: AppColors.primary, size: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.initial == null ? 'Add Vehicle' : 'Edit Vehicle',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                Text('Details appear on your gate pass',
                    style: AppText.caption.copyWith(fontSize: 12)),
              ])),
        ]),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child:
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _platePreview(),
              const SizedBox(height: 18),
              _fieldLabel('Vehicle number'),
              TextFormField(
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      hintText: 'TN07AB1234',
                      prefixIcon:
                          Icon(Icons.directions_car_outlined)),
                  validator: _validateNumber),
              const SizedBox(height: 14),
              _fieldLabel('Vehicle type'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _vehicleTypeOptions)
                    ChoiceChip(
                      avatar: Icon(option.$2,
                          size: 18,
                          color: _type.text.trim() == option.$1
                              ? AppColors.primary
                              : AppColors.secondaryText),
                      label: Text(option.$1),
                      selected: _type.text.trim() == option.$1,
                      selectedColor: AppColors.indicatorBg,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _type.text.trim() == option.$1
                              ? AppColors.primary
                              : AppColors.ink),
                      side: BorderSide(
                          color: _type.text.trim() == option.$1
                              ? AppColors.primary
                              : AppColors.borderLight),
                      onSelected: (_) => _pickType(option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _fieldLabel('Vehicle model'),
              _modelField(),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) {
                  return;
                }
                final type = _type.text.trim().isEmpty
                    ? 'Car'
                    : _type.text.trim();
                Navigator.pop(context, {
                  'number': _number.text.trim().toUpperCase(),
                  'type': type,
                  'model': _modelText.trim(),
                });
              },
              child: const Text('Save')),
        ],
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800)),
      );

  /// Model input: catalog-backed autocomplete for Car, Scooty, Mini-Truck,
  /// Mini-Van and E-Cycle; free text for Bike and Auto (no dataset).
  Widget _modelField() {
    final kind = vehicleKindForLabel(_type.text.trim());
    if (kind == null) {
      return TextFormField(
          controller: _model,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              hintText: 'E.g. Pulsar 150, Splendor+',
              prefixIcon: Icon(Icons.edit_outlined)),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Vehicle model is required'
              : null);
    }
    // Keyed by kind so switching categories restarts with carried text.
    final carried = _modelText;
    return Autocomplete<VehicleEntry>(
      key: ValueKey('model-$kind'),
      initialValue: TextEditingValue(text: carried),
      displayStringForOption: (option) => option.display,
      optionsBuilder: (value) =>
          suggestModels(query: value.text, kind: kind),
      onSelected: (_) {},
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: 224, maxWidth: 320),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(6),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  leading: Icon(
                      iconForVehicleType(_type.text.trim()),
                      size: 22,
                      color: AppColors.primary),
                  title: Text(option.display,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(segmentLabel(option.segment),
                      style:
                          AppText.caption.copyWith(fontSize: 12)),
                  trailing: option.isEV
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B9E6B)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('EV',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B9E6B))),
                        )
                      : null,
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ),
      ),
      fieldViewBuilder:
          (context, controller, focusNode, onFieldSubmitted) {
        _attachAuto(controller);
        return TextFormField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                hintText: _modelHintFor(kind),
                prefixIcon: const Icon(Icons.search_rounded)),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Vehicle model is required'
                : null);
      },
    );
  }

  /// Indian-style number plate that updates live while typing.
  Widget _platePreview() => Column(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.ink.withValues(alpha: 0.85), width: 1.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF1B4F9C),
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('IND',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _previewNumber,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['monospace'],
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: _numberIsPlaceholder
                        ? AppColors.secondaryText.withValues(alpha: 0.5)
                        : AppColors.ink),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          _previewSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption,
        ),
      ]);
}

/// Change-password dialog with current-password verification.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.user});
  final AppUser user;
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final store = LocalStore();
    final fresh = await store.readUser();
    if (!mounted) return;
    if (fresh == null || fresh.password != _current.text) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Current password is incorrect')));
      return;
    }
    await store.saveUser(fresh.copyWith(password: _next.text));
    if (!mounted) return;
    Navigator.pop(context);
    showParkitSnack(context, 'Password updated successfully',
        icon: Icons.lock_outline_rounded);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: _current,
                  obscureText: _hidden,
                  decoration: const InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: Icon(Icons.lock_outline_rounded))),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _next,
                  obscureText: _hidden,
                  decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon:
                          const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                          tooltip: 'Show or hide password',
                          onPressed: () =>
                              setState(() => _hidden = !_hidden),
                          icon: Icon(_hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
                  validator: (v) => v == null || v.length < 6
                      ? 'Use at least 6 characters'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _confirm,
                  obscureText: _hidden,
                  decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.lock_outline_rounded)),
                  validator: (v) => v != _next.text
                      ? 'Passwords do not match'
                      : null),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update')),
        ],
      );
}

class EditProfileScreen extends StatefulWidget { const EditProfileScreen({required this.user, required this.onSaved, super.key}); final AppUser user; final VoidCallback onSaved; @override State<EditProfileScreen> createState() => _EditProfileScreenState(); }
class _EditProfileScreenState extends State<EditProfileScreen> { late final TextEditingController _name = TextEditingController(text: widget.user.name), _phone = TextEditingController(text: widget.user.phone), _vehicle = TextEditingController(text: widget.user.vehicle); Future<void> _save() async { await LocalStore().saveUser(widget.user.copyWith(name: _name.text.trim(), phone: _phone.text.trim(), vehicle: _vehicle.text.trim().toUpperCase())); widget.onSaved(); if (mounted) Navigator.pop(context); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Edit profile', style: AppText.formLabel)), body: ListView(padding: const EdgeInsets.all(24), children: [_fieldLabel('Full name'), TextField(controller: _name), const SizedBox(height: 18), _fieldLabel('Email address'), TextField(enabled: false, controller: TextEditingController(text: widget.user.email)), const SizedBox(height: 18), _fieldLabel('Phone number'), TextField(controller: _phone, keyboardType: TextInputType.phone), const SizedBox(height: 18), _fieldLabel('Vehicle number'), TextField(controller: _vehicle), const SizedBox(height: 28), SizedBox(height: AppSpacing.buttonHeight, child: FilledButton(onPressed: _save, child: const Text('Save changes')))])); }

Widget _fieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.small), child: Text(text, style: AppText.formLabel));

/// The 7 fixed Edit-Vehicle categories with a dedicated icon each.
const _vehicleTypeOptions = <(String, IconData)>[
  ('Car', Icons.directions_car_rounded),
  ('Scooty', Icons.moped_rounded),
  ('Bike', Icons.two_wheeler_rounded),
  ('E-Cycle', Icons.electric_bike_rounded),
  ('Auto', Icons.local_taxi_rounded),
  ('Mini-Truck', Icons.local_shipping_rounded),
  ('Mini-Van', Icons.airport_shuttle_rounded),
];

/// Icon matching the selected vehicle category (bike → bike, etc.).
IconData iconForVehicleType(String? type) {
  for (final option in _vehicleTypeOptions) {
    if (option.$1 == type?.trim()) return option.$2;
  }
  return Icons.directions_car_rounded;
}
