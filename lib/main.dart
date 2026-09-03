import 'dart:async';

import 'package:flutter/material.dart';
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
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final user = await _store.readUser(); if (mounted) setState(() => _user = user); }
  Future<void> _logout() async { await _store.setLoggedIn(false); widget.onLogout(); }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [_HomePage(user: user, onScan: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()))), const HistoryScreen(), ProfileScreen(user: user, onUpdated: _load, onLogout: _logout)];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontalSmall, vertical: AppSpacing.small),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Bookings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.user, required this.onScan});
  final AppUser user;
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) => SafeArea(child: LayoutBuilder(builder: (context, _) {
        final contentWidth = AppResponsive.getMaxContentWidth(context);
        return ListView(padding: const EdgeInsets.fromLTRB(22, 26, 22, 30), children: [
          Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: contentWidth), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const _BrandMark(), Stack(children: [IconButton(onPressed: () => _showNotifications(context), tooltip: 'Notifications', icon: const Icon(Icons.notifications_none_rounded)), Positioned(right: 8, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))])]),
            const SizedBox(height: 24),
            Text('Welcome, ${user.name.split(' ').first}', style: AppText.welcTitle),
            const SizedBox(height: 5),
            Text('${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}  •  ${DateFormat('h:mm a').format(DateTime.now())}', style: AppText.subtitle),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(AppSpacing.large), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('ACTIVE PARKING SESSION', style: AppText.uppercaseLabel), Text('PARKED', style: AppText.formLabel.copyWith(color: AppColors.accent))]),
              const SizedBox(height: 12),
              Text('Slot A-17', style: AppText.slotNumber),
              Text('Visitor Zone  •  ${user.vehicle}', style: AppText.metricLabel),
              const SizedBox(height: 14),
              const Text('01h 26m 43s  •  ₹42 current fee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => _showSession(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)), child: const Text('View session'))),
            ])),
            const SizedBox(height: 24),
            Container(padding: const EdgeInsets.all(AppSpacing.large), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('PARKING AVAILABILITY', style: AppText.uppercaseLabel), Text('73% free', style: AppText.metricLabel)]),
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: const LinearProgressIndicator(value: .73, minHeight: 8, backgroundColor: Color(0xFF3D504A), color: AppColors.accent)),
              const SizedBox(height: 20),
              const Row(children: [_Metric(value: '248', label: 'Available'), _Metric(value: '92', label: 'Occupied'), _Metric(value: '340', label: 'Total')]),
            ])),
            const SizedBox(height: 28),
            Text('Quick actions', style: AppText.cardTitle),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, actionConstraints) {
              final actionWidth = (actionConstraints.maxWidth - 24) / 3;
              return Row(children: [_Action(width: actionWidth, icon: Icons.qr_code_scanner_rounded, label: 'Scan QR', onTap: onScan), const SizedBox(width: 12), _Action(width: actionWidth, icon: Icons.local_parking_rounded, label: 'My parking'), const SizedBox(width: 12), _Action(width: actionWidth, icon: Icons.history_rounded, label: 'History')]);
            }),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Your vehicle', style: AppText.cardTitle), Text('Ready to park', style: AppText.label.copyWith(color: AppColors.primary))]),
            const SizedBox(height: 12),
            Card(elevation: 0, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5), leading: CircleAvatar(backgroundColor: AppColors.indicatorBg, child: const Icon(Icons.directions_car_rounded, color: AppColors.primary)), title: Text(user.vehicle, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(user.phone), trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText))),
          ]))),
        ]);
      }));

  void _showNotifications(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (_) => SafeArea(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [Text('Notifications', style: AppText.sectionTitle), const SizedBox(height: 8), const ListTile(leading: Icon(Icons.local_parking_rounded, color: AppColors.primary), title: Text('Parking session active'), subtitle: Text('Your vehicle is parked in slot A-17.')), const ListTile(leading: Icon(Icons.payments_outlined, color: AppColors.primary), title: Text('Payment completed'), subtitle: Text('Your latest receipt is ready.')), const ListTile(leading: Icon(Icons.event_available_rounded, color: AppColors.primary), title: Text('Reservation reminder'), subtitle: Text('Your reservation starts tomorrow.'))])));

  void _showSession(BuildContext context) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Active parking session'), content: const Text('Slot A-17\nVisitor Zone\nDuration: 01h 26m 43s\nCurrent fee: ₹42'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')), FilledButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parking session ended'))); }, child: const Text('End session'))]));
}

class _Metric extends StatelessWidget { const _Metric({required this.value, required this.label}); final String value, label; @override Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: AppText.metricValue), const SizedBox(height: 4), Text(label, style: AppText.metricLabel)])); }
class _Action extends StatelessWidget { const _Action({required this.width, required this.icon, required this.label, this.onTap}); final double width; final IconData icon; final String label; final VoidCallback? onTap; @override Widget build(BuildContext context) => SizedBox(width: width, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppSpacing.radiusMedium), child: Ink(padding: const EdgeInsets.symmetric(vertical: AppSpacing.large), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMedium)), child: Column(children: [Icon(icon, color: AppColors.primary), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: AppText.formLabel)])))); }

class ScanScreen extends StatelessWidget { const ScanScreen({super.key}); @override Widget build(BuildContext context) => QRScannerView(onScanned: (code) {
    // Process the scanned QR code – for now just show a snackbar and pop.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scanned: $code')));
    Navigator.of(context).pop();
  }); }

class _Booking {
  _Booking({required this.facility, required this.slot, required this.vehicle, required this.date, required this.duration, required this.amount, required this.status, this.active = false, this.upcoming = false});
  final String facility, slot, vehicle, date, duration, amount;
  String status;
  final bool active, upcoming;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override State<HistoryScreen> createState() => _HistoryScreenState();
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

  @override void dispose() { _tabs.dispose(); _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Bookings', style: AppText.formLabel), actions: [IconButton(onPressed: () => _showFilters(context), tooltip: 'Filter bookings', icon: const Icon(Icons.tune_rounded))]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4), child: TextField(controller: _search, onChanged: (value) => setState(() => _query = value.toLowerCase()), decoration: const InputDecoration(hintText: 'Search date, slot, vehicle or facility', prefixIcon: Icon(Icons.search_rounded)))),
          if (_filter != 'All') Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 20, bottom: 4), child: Chip(label: Text(_filter), onDeleted: () => setState(() => _filter = 'All')))),
          TabBar(controller: _tabs, tabs: const [Tab(text: 'Active'), Tab(text: 'Upcoming'), Tab(text: 'History')]),
          Expanded(child: TabBarView(controller: _tabs, children: [_list(_bookings.where((item) => item.active).toList()), _list(_bookings.where((item) => item.upcoming).toList()), _list(_bookings.where((item) => !item.active && !item.upcoming).toList())])),
        ]),
      );

  Widget _list(List<_Booking> source) {
    final results = source.where((item) => _filter == 'All' || item.status == _filter).where((item) => '${item.facility} ${item.slot} ${item.vehicle} ${item.date}'.toLowerCase().contains(_query)).toList();
    if (results.isEmpty) return const Center(child: Text('No bookings found'));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: results.length, itemBuilder: (context, index) {
      final booking = results[index];
      return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () => _showDetails(context, booking), borderRadius: BorderRadius.circular(AppSpacing.radiusMedium), child: Padding(padding: const EdgeInsets.all(AppSpacing.large), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Flexible(child: Text(booking.facility, style: AppText.formLabel)), _status(booking.status)]),
        const SizedBox(height: 10), Text('Slot ${booking.slot}', style: AppText.cardTitle), const SizedBox(height: 4), Text('${booking.vehicle}  •  ${booking.date}', style: AppText.subtitle),
        const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(booking.duration), Text(booking.amount, style: AppText.formLabel), if (booking.active) TextButton(onPressed: () => _endSession(booking), child: const Text('End session'))]),
      ]))));
    });
  }

  Widget _status(String status) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: status == 'Cancelled' ? Colors.red.shade50 : AppColors.indicatorBg, borderRadius: BorderRadius.circular(20)), child: Text(status, style: AppText.caption.copyWith(color: status == 'Cancelled' ? Colors.redAccent : AppColors.primary, fontWeight: FontWeight.w700)));
  void _endSession(_Booking booking) { setState(() => booking.status = 'Completed'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parking session ended'))); }
  void _showFilters(BuildContext context) => showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: ['All', 'Completed', 'Paid', 'Cancelled', 'Reserved'].map((filter) => ListTile(title: Text(filter), leading: const Icon(Icons.filter_alt_outlined), onTap: () { setState(() => _filter = filter); Navigator.pop(sheetContext); })).toList())));
  void _showDetails(BuildContext context, _Booking booking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Wrap(
            children: [
              Text('Booking details', style: AppText.sectionTitle),
              const SizedBox(height: 16),
              _detail('Facility', booking.facility),
              _detail('Slot', booking.slot),
              _detail('Vehicle', booking.vehicle),
              _detail('Entry time', booking.date),
              _detail('Duration', booking.duration),
              _detail('Payment', booking.amount),
              _detail('Status', booking.status),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigation started'))), icon: const Icon(Icons.near_me_rounded), label: const Text('Navigate'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(onPressed: () { Navigator.pop(sheetContext); _showReceipt(context, booking); }, icon: const Icon(Icons.receipt_long_rounded), label: const Text('Receipt'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
  void _showReceipt(BuildContext context, _Booking booking) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('ParkIt receipt'), content: Text('Facility: ${booking.facility}\nSlot: ${booking.slot}\nDuration: ${booking.duration}\nAmount: ${booking.amount}\nPayment: UPI'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')), FilledButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt download started'))); }, child: const Text('Download'))]));
  Widget _detail(String label, String value) => ListTile(contentPadding: EdgeInsets.zero, title: Text(label, style: AppText.caption), trailing: Text(value, style: AppText.formLabel));
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.user, required this.onUpdated, required this.onLogout, super.key});
  final AppUser user;
  final VoidCallback onUpdated, onLogout;
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _parkingAlerts = true, _bookingAlerts = true, _paymentAlerts = true, _promotions = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('My profile', style: AppText.formLabel)),
        body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 30), child: Column(children: [
          _profileHeader(),
          const SizedBox(height: 24),
          Text('Vehicle information', style: AppText.cardTitle),
          const SizedBox(height: 10),
          Card(elevation: 0, child: Column(children: [
            _info('Vehicle number', widget.user.vehicle, Icons.directions_car_outlined),
            const Divider(height: 1),
            _info('Vehicle type', 'Private vehicle', Icons.directions_car_filled_outlined),
            _info('Registered', '12 January 2026', Icons.calendar_today_outlined),
            Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(right: 12, bottom: 8), child: TextButton.icon(onPressed: () => _message('Vehicle manager opened'), icon: const Icon(Icons.garage_outlined), label: const Text('Manage vehicles')))),
          ])),
          const SizedBox(height: 24),
          Text('Parking statistics', style: AppText.cardTitle),
          const SizedBox(height: 10),
          Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [_ProfileStat('42', 'Sessions'), _ProfileStat('118h', 'Hours parked'), _ProfileStat('₹1850', 'Amount spent')]))),
          const SizedBox(height: 24),
          Text('Notification preferences', style: AppText.cardTitle),
          const SizedBox(height: 10),
          Card(elevation: 0, child: Column(children: [
            _toggle('Parking alerts', _parkingAlerts, (value) => setState(() => _parkingAlerts = value)),
            _toggle('Booking alerts', _bookingAlerts, (value) => setState(() => _bookingAlerts = value)),
            _toggle('Payment alerts', _paymentAlerts, (value) => setState(() => _paymentAlerts = value)),
            _toggle('Promotions', _promotions, (value) => setState(() => _promotions = value)),
          ])),
          const SizedBox(height: 24),
          Text('Achievements', style: AppText.cardTitle),
          const SizedBox(height: 10),
          Card(elevation: 0, child: Column(children: [
            _achievement('First parking session', 'Completed', 1),
            _achievement('10 bookings completed', '8 of 10', .8),
            _achievement('50 hours parked', '42 of 50 hours', .84),
          ])),
          const SizedBox(height: 24),
          Text('Account', style: AppText.cardTitle),
          const SizedBox(height: 10),
          Card(elevation: 0, child: Column(children: [
            _option('Edit profile', Icons.edit_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(user: widget.user, onSaved: widget.onUpdated)))),
            _option('My vehicles', Icons.garage_outlined, () => _message('Vehicle manager opened')),
            _option('Parking history', Icons.history_rounded, () => _message('Opening your parking history')),
            _option('Notifications', Icons.notifications_none_rounded, () => _message('Notification center opened')),
            _option('Payment methods', Icons.account_balance_wallet_outlined, () => _paymentMethods()),
            _option('Security settings', Icons.lock_outline_rounded, () => _message('Security settings opened')),
            _option('Privacy settings', Icons.privacy_tip_outlined, () => _message('Privacy settings opened')),
            _option('Support', Icons.support_agent_rounded, () => _support()),
            _option('About ParkIt', Icons.info_outline_rounded, () => _about()),
            _option('Logout', Icons.logout_rounded, widget.onLogout, danger: true),
          ])),
        ])),
      );

  Widget _profileHeader() => Card(
        color: AppColors.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const CircleAvatar(radius: 38, backgroundColor: AppColors.indicatorBg, child: Icon(Icons.person_rounded, size: 42, color: AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.user.name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(widget.user.email, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Row(children: [Text('Gold Member', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)), const SizedBox(width: 8), Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)), const SizedBox(width: 8), const Text('92% complete', style: TextStyle(color: Colors.white70))]),
            ])),
          ]),
        ),
      );
  Widget _info(String label, String value, IconData icon) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), leading: Icon(icon, color: AppColors.primary), title: Text(label, style: AppText.caption), subtitle: Text(value, style: AppText.formLabel));
  Widget _toggle(String title, bool value, ValueChanged<bool> onChanged) => SwitchListTile(title: Text(title), value: value, onChanged: onChanged, activeThumbColor: AppColors.primary);
  Widget _option(String label, IconData icon, VoidCallback onTap, {bool danger = false}) => ListTile(onTap: onTap, leading: Icon(icon, color: danger ? Colors.redAccent : AppColors.primary), title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? Colors.redAccent : null)), trailing: const Icon(Icons.chevron_right_rounded));
  Widget _achievement(String title, String progress, double value) => ListTile(leading: CircleAvatar(backgroundColor: AppColors.indicatorBg, child: Icon(value == 1 ? Icons.check_rounded : Icons.emoji_events_outlined, color: AppColors.primary)), title: Text(title, style: AppText.formLabel), subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: value, minHeight: 6, borderRadius: BorderRadius.circular(6))), trailing: Text(progress, style: AppText.caption));
  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  void _paymentMethods() => showModalBottomSheet<void>(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const ListTile(title: Text('Payment methods'), subtitle: Text('Choose a method for faster checkout')), const ListTile(leading: Icon(Icons.account_balance, color: AppColors.primary), title: Text('UPI'), trailing: Icon(Icons.check_circle, color: AppColors.primary)), const ListTile(leading: Icon(Icons.credit_card, color: AppColors.primary), title: Text('Credit card')), ListTile(leading: const Icon(Icons.add_circle_outline, color: AppColors.primary), title: const Text('Add payment method'), onTap: () { Navigator.pop(context); _message('Payment method form opened'); })])));
  void _support() => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Support center'), content: const Text('How can we help today?'), actions: [TextButton(onPressed: () { Navigator.pop(context); _message('Support ticket started'); }, child: const Text('Raise ticket')), TextButton(onPressed: () { Navigator.pop(context); _message('Calling ParkIt support'); }, child: const Text('Call support'))]));
  void _about() => showAboutDialog(context: context, applicationName: 'ParkIt', applicationVersion: '1.0.0', applicationLegalese: 'Smart parking made effortless.');
}

class _ProfileStat extends StatelessWidget { const _ProfileStat(this.value, this.label); final String value, label; @override Widget build(BuildContext context) => Column(children: [Text(value, style: AppText.formLabel), const SizedBox(height: 4), Text(label, style: AppText.caption)]); }

class EditProfileScreen extends StatefulWidget { const EditProfileScreen({required this.user, required this.onSaved, super.key}); final AppUser user; final VoidCallback onSaved; @override State<EditProfileScreen> createState() => _EditProfileScreenState(); }
class _EditProfileScreenState extends State<EditProfileScreen> { late final TextEditingController _name = TextEditingController(text: widget.user.name), _phone = TextEditingController(text: widget.user.phone), _vehicle = TextEditingController(text: widget.user.vehicle); Future<void> _save() async { await LocalStore().saveUser(widget.user.copyWith(name: _name.text.trim(), phone: _phone.text.trim(), vehicle: _vehicle.text.trim().toUpperCase())); widget.onSaved(); if (mounted) Navigator.pop(context); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Edit profile', style: AppText.formLabel)), body: ListView(padding: const EdgeInsets.all(24), children: [_fieldLabel('Full name'), TextField(controller: _name), const SizedBox(height: 18), _fieldLabel('Email address'), TextField(enabled: false, controller: TextEditingController(text: widget.user.email)), const SizedBox(height: 18), _fieldLabel('Phone number'), TextField(controller: _phone, keyboardType: TextInputType.phone), const SizedBox(height: 18), _fieldLabel('Vehicle number'), TextField(controller: _vehicle), const SizedBox(height: 28), SizedBox(height: AppSpacing.buttonHeight, child: FilledButton(onPressed: _save, child: const Text('Save changes')))])); }

Widget _fieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.small), child: Text(text, style: AppText.formLabel));
