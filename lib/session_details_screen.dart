import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import 'parking_rate.dart';
import 'payment_screen.dart';
import 'receipt_card.dart';
import 'receipt_service.dart';
import 'styles.dart';
import 'widgets.dart';

/// Simplified premium parking session screen.
///
/// Keeps only the core end-user sections: status hero (with live duration),
/// live analytics, parking location, cost breakdown, QR access pass and
/// session records. Admin-oriented sections (occupancy, insights, security)
/// were intentionally removed to reduce cognitive load.
class ParkingSessionDetailsScreen extends StatefulWidget {
  const ParkingSessionDetailsScreen({
    super.key,
    this.status = 'Active',
    this.slot = 'A-17',
    this.zone = 'Visitor Parking',
    this.vehicleNumber = 'TN07AB1234',
    this.facility = 'REC Main Parking',
    this.ownerName = 'Guest User',
  });

  final String status;
  final String slot;
  final String zone;
  final String vehicleNumber;
  final String facility;
  final String ownerName;

  @override
  State<ParkingSessionDetailsScreen> createState() =>
      _ParkingSessionDetailsScreenState();
}

enum _SessionKind { active, reserved, completed, expired }

_SessionKind _kindOf(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'parked':
      return _SessionKind.active;
    case 'reserved':
    case 'upcoming':
      return _SessionKind.reserved;
    case 'expired':
    case 'cancelled':
      return _SessionKind.expired;
    default:
      return _SessionKind.completed;
  }
}

class _ParkingSessionDetailsScreenState
    extends State<ParkingSessionDetailsScreen> {
  late final _SessionKind _kind;
  late DateTime _entryTime;
  late DateTime _now;
  Timer? _ticker;

  static const _bookingId = 'PKT-2026-1045';

  @override
  void initState() {
    super.initState();
    _kind = _kindOf(widget.status);
    // Demo entry: 2h 27m ago so the screen matches the reference example.
    _entryTime = DateTime.now().subtract(const Duration(hours: 2, minutes: 27));
    _now = DateTime.now();
    if (_kind == _SessionKind.active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    } else {
      // Static snapshot for non-active sessions.
      _now = _entryTime.add(const Duration(hours: 2, minutes: 27));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _duration => _now.difference(_entryTime);

  /// Live cost from the community tariff (₹20 first hour, ₹10 per
  /// additional 30 minutes, ₹150 daily max).
  int get _liveCost => parkingFeeFor(_duration);

  int get _liveTax => parkingTaxFor(_liveCost);

  int get _liveTotal => _liveCost + _liveTax;

  /// Prominent ticking clock, e.g. "02h 27m 45s".
  String get _clockLabel => formatDurationClock(_duration);

  String get _durationLabel => formatDurationShort(_duration);

  /// Branded receipt payload shared by the PNG share and PDF download flows.
  ReceiptData get _receiptData => ReceiptData(
        receiptId: _bookingId,
        vehicle: widget.vehicleNumber,
        facility: widget.facility,
        slot: widget.slot,
        entryLabel: DateFormat('dd MMM · hh:mm a').format(_entryTime),
        durationLabel: _durationLabel,
        amountLabel: '₹$_liveTotal',
        parkingFee: '₹$_liveCost',
        tax: '₹$_liveTax',
        total: '₹$_liveTotal',
        generatedLabel: receiptTimestamp(),
      );

  Color get _statusColor {
    switch (_kind) {
      case _SessionKind.active:
        return const Color(0xFF1B9E6B);
      case _SessionKind.reserved:
        return const Color(0xFF2563EB);
      case _SessionKind.completed:
        return const Color(0xFF667671);
      case _SessionKind.expired:
        return AppColors.error;
    }
  }

  String get _statusLabel {
    switch (_kind) {
      case _SessionKind.active:
        return 'Active';
      case _SessionKind.reserved:
        return 'Reserved';
      case _SessionKind.completed:
        return 'Completed';
      case _SessionKind.expired:
        return 'Expired';
    }
  }

  String get _lastActivity {
    switch (_kind) {
      case _SessionKind.active:
        return 'Vehicle verified · '
            '${DateFormat('hh:mm a').format(_now.subtract(const Duration(minutes: 2)))}';
      case _SessionKind.reserved:
        return 'Slot reserved';
      case _SessionKind.completed:
        return 'Session closed';
      case _SessionKind.expired:
        return 'Session expired';
    }
  }

  String get _paymentLabel {
    switch (_kind) {
      case _SessionKind.active:
        return 'Pending';
      case _SessionKind.reserved:
        return 'Unpaid';
      case _SessionKind.completed:
        return 'Paid';
      case _SessionKind.expired:
        return 'Failed';
    }
  }

  Color get _paymentColor {
    switch (_kind) {
      case _SessionKind.active:
        return const Color(0xFFB7791F);
      case _SessionKind.reserved:
        return const Color(0xFF2563EB);
      case _SessionKind.completed:
        return const Color(0xFF1B9E6B);
      case _SessionKind.expired:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = AppResponsive.getMaxContentWidth(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Session details', style: AppText.formLabel),
        actions: [
          PopupMenuButton<_ReceiptMenuAction>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMedium)),
            onSelected: _onMenuAction,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ReceiptMenuAction.view,
                child: _MenuRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'View Receipt'),
              ),
              PopupMenuItem(
                value: _ReceiptMenuAction.share,
                child: _MenuRow(
                    icon: Icons.ios_share_outlined,
                    label: 'Share Receipt'),
              ),
              PopupMenuItem(
                value: _ReceiptMenuAction.downloadPdf,
                child: _MenuRow(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Download PDF'),
              ),
              PopupMenuItem(
                value: _ReceiptMenuAction.savePng,
                child: _MenuRow(
                    icon: Icons.image_outlined, label: 'Save PNG'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _StatusHeroCard(
                  statusLabel: _statusLabel,
                  statusColor: _statusColor,
                  slot: widget.slot,
                  zone: widget.zone,
                  vehicle: widget.vehicleNumber,
                  facility: widget.facility,
                  clockLabel: _clockLabel,
                  isActive: _kind == _SessionKind.active,
                ),
                const SizedBox(height: 16),
                _LiveAnalyticsCard(
                  entry: _entryTime,
                  now: _now,
                  durationLabel: _durationLabel,
                  cost: _liveCost,
                  live: _kind == _SessionKind.active,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Parking location',
                  child: _LocationInfo(
                    facility: widget.facility,
                    zone: widget.zone,
                    slot: widget.slot,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Cost breakdown',
                  child: _CostBreakdown(
                    fee: _liveCost,
                    tax: _liveTax,
                    total: _liveTotal,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'QR access pass',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _kind == _SessionKind.active
                          ? 'VALID · GATE A'
                          : _statusLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _statusColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  child: _QrPass(
                    bookingId: _bookingId,
                    vehicle: widget.vehicleNumber,
                    slot: widget.slot,
                    entry: _entryTime,
                    onEnlarge: _enlargeQr,
                    onShare: _shareReceipt,
                    onDownload: _downloadReceipt,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Session records',
                  child: _SessionRecords(
                    entry: _entryTime,
                    lastActivity: _lastActivity,
                    paymentLabel: _paymentLabel,
                    paymentColor: _paymentColor,
                    bookingId: _bookingId,
                  ),
                ),
                // breathing room above the fixed bottom action bar
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomActions(
        kind: _kind,
        onExtend: () => _extendSheet(),
        onEnd: () => _endSheet(),
        onReceipt: () => showParkitSnack(
            context, 'Receipt download started (PDF)',
            icon: Icons.download_outlined),
        onRebook: () => showParkitSnack(
            context, 'Slot ${widget.slot} reserved for tomorrow, 10:30 AM',
            icon: Icons.repeat_rounded),
        onCancel: () => showParkitSnack(
            context, 'Reservation cancelled',
            icon: Icons.cancel_outlined),
      ),
    );
  }

  void _enlargeQr() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gate access pass', style: AppText.cardTitle),
              const SizedBox(height: 4),
              Text(_bookingId, style: AppText.caption),
              const SizedBox(height: 16),
              const ReceiptQr(size: 240, seed: _bookingId),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Share flow: shared branded receipt preview → capture card → share.
  void _shareReceipt() => showReceiptPreview(context, _receiptData);

  void _extendSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extend parking', style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text('Extra time is billed at ₹10 per 30 minutes.',
                  style: AppText.subtitle.copyWith(fontSize: 14)),
              const SizedBox(height: 16),
              for (final option in [
                '+30 minutes · ₹10',
                '+1 hour · ₹20',
                '+2 hours · ₹40'
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded,
                      color: AppColors.primary),
                  title: Text(option,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showParkitSnack(
                        context, 'Parking extended ($option)',
                        icon: Icons.schedule_rounded);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _endSheet() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End parking session?'),
        content: const Text(
            'Your vehicle must exit via Gate A. You will be taken to secure demo checkout.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep parking')),
          FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(
                      payment: ParkingPayment(
                        receiptId: _bookingId,
                        slot: widget.slot,
                        vehicle: widget.vehicleNumber,
                        facility: widget.facility,
                        entryLabel: DateFormat('dd MMM · hh:mm a')
                            .format(_entryTime),
                        durationLabel: _durationLabel,
                        fee: _liveCost,
                        tax: _liveTax,
                      ),
                    ),
                  ),
                );
              },
              child: Text('Pay ₹$_liveTotal')),
        ],
      ),
    );
  }

  void _onMenuAction(_ReceiptMenuAction action) {
    switch (action) {
      case _ReceiptMenuAction.view:
        _shareReceipt();
        break;
      case _ReceiptMenuAction.share:
        _shareReceiptNow();
        break;
      case _ReceiptMenuAction.downloadPdf:
        _savePdfOnly();
        break;
      case _ReceiptMenuAction.savePng:
        _savePngOnly();
        break;
    }
  }

  void _openSavedFile(String path) {
    openReceiptFile(path).then((result) {
      if (!mounted) return;
      if (result.type != ResultType.done) {
        showParkitSnack(context, 'Could not open the file — try again',
            icon: Icons.error_outline_rounded);
      }
    });
  }

  void _savedSnack(String fileName, String path) {
    if (!mounted) return;
    showParkitSnack(
      context,
      'Receipt saved successfully · $fileName',
      icon: Icons.download_done_rounded,
      actionLabel: 'Open File',
      onAction: () => _openSavedFile(path),
    );
  }

  void _saveFailedSnack() {
    if (!mounted) return;
    showParkitSnack(context, 'Could not save the receipt — try again',
        icon: Icons.error_outline_rounded);
  }

  /// QR Download action: permanently stores BOTH the PNG and the PDF under
  /// Downloads/ParkIt (Android) or Documents/ParkIt (iOS).
  Future<void> _downloadReceipt() async {
    final data = _receiptData;
    showParkitSnack(context, 'Saving receipt…',
        icon: Icons.hourglass_top_rounded);
    try {
      final png = await captureReceiptCard(context, data);
      if (png == null) throw StateError('receipt capture failed');
      final pngPath = await saveReceiptPngToDevice(
          pngBytes: png, vehicle: data.vehicle);
      final pdfPath = await saveReceiptPdfToDevice(data);
      if (!mounted) return;
      showParkitSnack(
        context,
        'Receipt saved successfully · ${receiptsLocationLabel()}',
        icon: Icons.download_done_rounded,
        actionLabel: 'Open File',
        onAction: () => _openSavedFile(pdfPath),
      );
      debugPrint('Saved PNG: $pngPath · PDF: $pdfPath');
    } catch (_) {
      _saveFailedSnack();
    }
  }

  /// One-tap share: capture the receipt card and open the system share sheet.
  Future<void> _shareReceiptNow() async {
    final data = _receiptData;
    showParkitSnack(context, 'Preparing receipt…',
        icon: Icons.hourglass_top_rounded);
    try {
      final png = await captureReceiptCard(context, data);
      if (png == null) throw StateError('receipt capture failed');
      await shareReceiptPng(png, data);
      if (!mounted) return;
      showParkitSnack(context, 'Receipt shared successfully',
          icon: Icons.ios_share_outlined);
    } catch (_) {
      if (!mounted) return;
      showParkitSnack(
          context, 'Could not create the receipt image — try again',
          icon: Icons.error_outline_rounded);
    }
  }

  /// Stores only the PDF receipt on the device.
  Future<void> _savePdfOnly() async {
    final data = _receiptData;
    showParkitSnack(context, 'Saving PDF…',
        icon: Icons.hourglass_top_rounded);
    try {
      final path = await saveReceiptPdfToDevice(data);
      _savedSnack(receiptPdfName(data.vehicle), path);
    } catch (_) {
      _saveFailedSnack();
    }
  }

  /// Stores only the PNG receipt on the device.
  Future<void> _savePngOnly() async {
    final data = _receiptData;
    showParkitSnack(context, 'Saving PNG…',
        icon: Icons.hourglass_top_rounded);
    try {
      final png = await captureReceiptCard(context, data);
      if (png == null) throw StateError('receipt capture failed');
      final path = await saveReceiptPngToDevice(
          pngBytes: png, vehicle: data.vehicle);
      _savedSnack(receiptPngName(data.vehicle), path);
    } catch (_) {
      _saveFailedSnack();
    }
  }
}

enum _ReceiptMenuAction { view, share, downloadPdf, savePng }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable premium card shell
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(fontSize: 17)),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(child: trailing!),
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Session status hero (top priority, prominent live duration)
// ---------------------------------------------------------------------------

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({
    required this.statusLabel,
    required this.statusColor,
    required this.slot,
    required this.zone,
    required this.vehicle,
    required this.facility,
    required this.clockLabel,
    required this.isActive,
  });

  final String statusLabel;
  final Color statusColor;
  final String slot;
  final String zone;
  final String vehicle;
  final String facility;
  final String clockLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 10),
                const _PulseDot(),
                const SizedBox(width: 6),
                const Text('LIVE',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text('PARKING SLOT', style: AppText.uppercaseLabel),
          const SizedBox(height: 6),
          Text('Slot $slot',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.slotNumber.copyWith(fontSize: 34)),
          const SizedBox(height: 16),
          Text('CURRENT DURATION', style: AppText.uppercaseLabel),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              clockLabel,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.14)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _HeroFact(
                      label: 'Vehicle Number', value: vehicle)),
              const SizedBox(width: 16),
              Expanded(
                  child:
                      _HeroFact(label: 'Facility', value: facility)),
            ],
          ),
          const SizedBox(height: 12),
          _HeroFact(label: 'Zone', value: zone),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Values wrap onto multiple lines — never truncated with "...".
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(value,
            softWrap: true,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
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
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_controller),
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
            color: AppColors.accent, shape: BoxShape.circle),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Live parking analytics (compact, 2-column responsive)
// ---------------------------------------------------------------------------

class _LiveAnalyticsCard extends StatelessWidget {
  const _LiveAnalyticsCard({
    required this.entry,
    required this.now,
    required this.durationLabel,
    required this.cost,
    required this.live,
  });

  final DateTime entry;
  final DateTime now;
  final String durationLabel;
  final int cost;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('hh:mm a');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E7767), Color(0xFF14493F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: const [
          BoxShadow(
              color: Color(0x331E7767),
              blurRadius: 24,
              offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('LIVE PARKING ANALYTICS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.uppercaseLabel
                        .copyWith(color: Colors.white70)),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  live ? 'LIVE' : 'FINAL',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final entryW = _Analytic(
                  label: 'Entry', value: timeFmt.format(entry));
              final currentW = _Analytic(
                  label: 'Current', value: timeFmt.format(now));
              final durationW = _Analytic(
                  label: 'Duration', value: durationLabel, big: true);
              final costW =
                  _Analytic(label: 'Cost', value: '₹$cost', big: true);
              if (constraints.maxWidth > 560) {
                return Row(
                    children: [entryW, currentW, durationW, costW]);
              }
              return Column(
                children: [
                  Row(children: [entryW, currentW]),
                  const SizedBox(height: 16),
                  Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.16)),
                  const SizedBox(height: 16),
                  Row(children: [durationW, costW]),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            live
                ? '₹20 first hour · then ₹10 / 30 min · settles at exit'
                : 'Settled · receipt available below',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Analytic extends StatelessWidget {
  const _Analytic(
      {required this.label, required this.value, this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: big ? 26 : 19,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Parking location (no map, small parking icon)
// ---------------------------------------------------------------------------

class _LocationInfo extends StatelessWidget {
  const _LocationInfo({
    required this.facility,
    required this.zone,
    required this.slot,
  });

  final String facility;
  final String zone;
  final String slot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.indicatorBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.local_parking_rounded,
              color: AppColors.primary, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              _InfoRow(label: 'Facility', value: facility, bold: true),
              const _InfoRow(label: 'Floor', value: 'Ground Floor'),
              _InfoRow(label: 'Zone', value: zone),
              _InfoRow(
                  label: 'Assigned slot', value: 'Slot $slot', bold: true),
              const _InfoRow(
                  label: 'Landmark',
                  value: 'Near Main Entrance',
                  last: true),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Cost breakdown (minimal invoice styling)
// ---------------------------------------------------------------------------

class _CostBreakdown extends StatelessWidget {
  const _CostBreakdown(
      {required this.fee, required this.tax, required this.total});

  final int fee;
  final int tax;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text('INVOICE #INV-2026-4417',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.secondaryText)),
              ),
              SizedBox(width: 10),
              Text('UPI · Pending',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CostRow(label: 'Parking fee', value: '₹$fee'),
        _CostRow(label: 'Tax (GST)', value: '₹$tax', last: true),
        const Divider(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text('Total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Text('₹$total',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
          ],
        ),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow(
      {required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle.copyWith(fontSize: 14)),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. QR access pass (equal-width responsive buttons, wrap on narrow screens)
// ---------------------------------------------------------------------------

class _QrPass extends StatelessWidget {
  const _QrPass({
    required this.bookingId,
    required this.vehicle,
    required this.slot,
    required this.entry,
    required this.onEnlarge,
    required this.onShare,
    required this.onDownload,
  });

  final String bookingId;
  final String vehicle;
  final String slot;
  final DateTime entry;
  final VoidCallback onEnlarge;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7F6),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BoardingRow(label: 'Session ID', value: bookingId),
                  const SizedBox(height: 9),
                  _BoardingRow(label: 'Vehicle', value: vehicle),
                  const SizedBox(height: 9),
                  _BoardingRow(label: 'Slot', value: slot),
                  const SizedBox(height: 9),
                  _BoardingRow(
                      label: 'Entry Time',
                      value: DateFormat('hh:mm a').format(entry),
                      last: true),
                ],
              );
              // Phones: QR sits on top, colon-aligned info uses full width.
              // Tablets: classic side-by-side boarding-pass row.
              if (constraints.maxWidth < 320) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                        child:
                            ReceiptQr(size: 120, seed: bookingId)),
                    const SizedBox(height: 14),
                    info,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ReceiptQr(size: 112, seed: bookingId),
                  const SizedBox(width: 18),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final enlarge = _QrButton(
              icon: Icons.zoom_out_map_rounded,
              tooltip: 'Enlarge QR',
              outlined: true,
              onPressed: onEnlarge,
            );
            final share = _QrButton(
              icon: Icons.ios_share_outlined,
              tooltip: 'Share receipt',
              outlined: true,
              onPressed: onShare,
            );
            final download = _QrButton(
              icon: Icons.download_outlined,
              tooltip: 'Download receipt',
              outlined: false,
              onPressed: onDownload,
            );
            // Icon-only buttons need ~176px total, so a single row fits
            // every phone and tablet; only absurdly narrow widths stack.
            if (constraints.maxWidth < 160) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  enlarge,
                  const SizedBox(height: 10),
                  share,
                  const SizedBox(height: 10),
                  download,
                ],
              );
            }
            // Equal-width buttons in one row: [Enlarge] [Share] [Download].
            return Row(
              children: [
                Expanded(child: enlarge),
                const SizedBox(width: 10),
                Expanded(child: share),
                const SizedBox(width: 10),
                Expanded(child: download),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Icon-only action button: equal width/height via the parent [Expanded],
/// accessible label via [tooltip]. Never overflows — no text to clip.
class _QrButton extends StatelessWidget {
  const _QrButton({
    required this.icon,
    required this.tooltip,
    required this.outlined,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool outlined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall))),
    );
    final content = Icon(icon, size: 22);
    if (outlined) {
      return Tooltip(
        message: tooltip,
        child: OutlinedButton(
            onPressed: onPressed, style: style, child: content),
      );
    }
    return Tooltip(
      message: tooltip,
      child: FilledButton(
          onPressed: onPressed, style: style, child: content),
    );
  }
}

/// Boarding-pass info row with aligned colons:
/// `Session ID : PKT-2026-1045`. Labels share a fixed width so every colon
/// lines up; values wrap instead of truncating.
class _BoardingRow extends StatelessWidget {
  const _BoardingRow(
      {required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  static const double _labelWidth = 86;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText)),
          ),
          const Text(' : ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Session records (essential records only)
// ---------------------------------------------------------------------------

class _SessionRecords extends StatelessWidget {
  const _SessionRecords({
    required this.entry,
    required this.lastActivity,
    required this.paymentLabel,
    required this.paymentColor,
    required this.bookingId,
  });

  final DateTime entry;
  final String lastActivity;
  final String paymentLabel;
  final Color paymentColor;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(
            label: 'Entry time',
            value: DateFormat('hh:mm a').format(entry)),
        _InfoRow(label: 'Last activity', value: lastActivity),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text('Payment', style: AppText.caption),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: paymentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(paymentLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: paymentColor)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: Text('Booking ID', style: AppText.caption)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(bookingId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Copy booking ID',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded,
                  size: 18, color: AppColors.primary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: bookingId));
                showParkitSnack(context, 'Booking ID copied to clipboard',
                    icon: Icons.copy_rounded);
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fixed bottom action bar (SafeArea-aware)
// ---------------------------------------------------------------------------

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.kind,
    required this.onExtend,
    required this.onEnd,
    required this.onReceipt,
    required this.onRebook,
    required this.onCancel,
  });

  final _SessionKind kind;
  final VoidCallback onExtend;
  final VoidCallback onEnd;
  final VoidCallback onReceipt;
  final VoidCallback onRebook;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons;
    if (kind == _SessionKind.active) {
      buttons = [
        _BottomButton(
            icon: Icons.schedule_rounded,
            label: 'Extend',
            filled: false,
            onPressed: onExtend),
        _BottomButton(
            icon: Icons.stop_circle_outlined,
            label: 'End session',
            filled: true,
            fillColor: AppColors.error,
            onPressed: onEnd),
      ];
    } else if (kind == _SessionKind.reserved) {
      buttons = [
        _BottomButton(
            icon: Icons.cancel_outlined,
            label: 'Cancel',
            filled: true,
            fillColor: AppColors.error,
            onPressed: onCancel),
      ];
    } else {
      buttons = [
        _BottomButton(
            icon: Icons.download_outlined,
            label: 'Receipt',
            filled: false,
            onPressed: onReceipt),
        _BottomButton(
            icon: Icons.repeat_rounded,
            label: 'Rebook',
            filled: true,
            onPressed: onRebook),
      ];
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  const _BottomButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
    this.fillColor,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onPressed;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 7),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 54)),
      padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: (fillColor == null
                ? style
                : style.copyWith(
                    backgroundColor:
                        WidgetStatePropertyAll(fillColor)))
            .copyWith(
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall)))),
        child: content,
      );
    }
    return OutlinedButton(onPressed: onPressed, style: style, child: content);
  }
}

// ---------------------------------------------------------------------------
// Shared rows
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label,
      required this.value,
      this.bold = false,
      this.last = false});

  final String label;
  final String value;
  final bool bold;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}
