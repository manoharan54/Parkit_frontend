import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'receipt_card.dart';
import 'receipt_service.dart';
import 'styles.dart';
import 'widgets.dart';
import 'widgets/payment_success_animation.dart';

/// Demo-only parking payment input. No real money ever moves.
class ParkingPayment {
  const ParkingPayment({
    required this.receiptId,
    required this.slot,
    required this.vehicle,
    required this.facility,
    required this.entryLabel,
    required this.durationLabel,
    required this.fee,
    required this.tax,
  });

  final String receiptId;
  final String slot;
  final String vehicle;
  final String facility;
  final String entryLabel;
  final String durationLabel;
  final int fee;
  final int tax;

  int get total => fee + tax;
}

enum _PayStage { details, processing, success }

/// Demo payment methods (mocked — no real processors involved).
const _demoMethods = [
  ('UPI', Icons.account_balance_rounded, true),
  ('Card', Icons.credit_card_rounded, false),
  ('Wallet', Icons.account_balance_wallet_outlined, false),
];

/// Mock checkout: method select → Pay → processing → success with the
/// payment-success video animation → receipt actions.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.payment, this.onPaid, super.key});

  final ParkingPayment payment;

  /// Called exactly once when the mock payment succeeds.
  final VoidCallback? onPaid;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  _PayStage _stage = _PayStage.details;
  String _method = _demoMethods.first.$1;
  bool _paidFired = false;

  ParkingPayment get _payment => widget.payment;

  ReceiptData get _receipt => ReceiptData(
        receiptId: _payment.receiptId,
        vehicle: _payment.vehicle,
        facility: _payment.facility,
        slot: _payment.slot,
        entryLabel: _payment.entryLabel,
        durationLabel: _payment.durationLabel,
        amountLabel: '₹${_payment.total}',
        parkingFee: '₹${_payment.fee}',
        tax: '₹${_payment.tax}',
        total: '₹${_payment.total}',
        generatedLabel: receiptTimestamp(),
      );

  Future<void> _pay() async {
    if (_stage != _PayStage.details) return;
    setState(() => _stage = _PayStage.processing);
    // Mock bank round-trip (demo only).
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || _stage != _PayStage.processing) return;
    setState(() => _stage = _PayStage.success);
    if (!_paidFired) {
      _paidFired = true;
      widget.onPaid?.call();
    }
  }

  Future<void> _share() async {
    final data = _receipt;
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

  Future<void> _download() async {
    final data = _receipt;
    showParkitSnack(context, 'Saving receipt…',
        icon: Icons.hourglass_top_rounded);
    try {
      final path = await saveReceiptPdfToDevice(data);
      if (!mounted) return;
      showParkitSnack(
        context,
        'Receipt saved successfully · ${receiptPdfName(data.vehicle)}',
        icon: Icons.download_done_rounded,
        actionLabel: 'Open File',
        onAction: () => openReceiptFile(path).then((result) {
          if (!mounted) return;
          if (result.type != ResultType.done) {
            showParkitSnack(
                context, 'Could not open the file — try again',
                icon: Icons.error_outline_rounded);
          }
        }),
      );
    } catch (_) {
      if (!mounted) return;
      showParkitSnack(context, 'Could not save the PDF — try again',
          icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = AppResponsive.getMaxContentWidth(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(
              _stage == _PayStage.success ? 'Payment Successful' : 'Payment',
              style: AppText.formLabel)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_stage == _PayStage.success) ...[
                  // Fixed animation zone (220px): the animation can never
                  // push the text or buttons below it.
                  const SizedBox(
                    height: 220,
                    child: Center(
                        child: PaymentSuccessAnimation()),
                  ),
                  // Fixed text zone (70px): title + subtitle stay put.
                  SizedBox(
                    height: 70,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Payment Successful',
                            textAlign: TextAlign.center,
                            style: AppText.sectionTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Parking Session Completed',
                            textAlign: TextAlign.center,
                            style: AppText.subtitle
                                .copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Fixed action rows: Receipt + Share, Download + Done.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                                double.infinity,
                                AppSpacing.buttonHeight),
                          ),
                          onPressed: () =>
                              showReceiptPreview(context, _receipt),
                          icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18),
                          label:
                              Text('Receipt', style: AppText.button),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                                double.infinity,
                                AppSpacing.buttonHeight),
                          ),
                          onPressed: _share,
                          icon: const Icon(
                              Icons.ios_share_outlined,
                              size: 18),
                          label:
                              Text('Share', style: AppText.button),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                                double.infinity,
                                AppSpacing.buttonHeight),
                          ),
                          onPressed: _download,
                          icon: const Icon(
                              Icons.download_outlined,
                              size: 18),
                          label: Text('Download',
                              style: AppText.button),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(
                                double.infinity,
                                AppSpacing.buttonHeight),
                          ),
                          onPressed: () =>
                              Navigator.of(context).popUntil(
                                  (route) => route.isFirst),
                          child:
                              Text('Done', style: AppText.button),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _TransactionCard(
                    receiptId: _payment.receiptId,
                    method: _method,
                    amount: '₹${_payment.total}',
                  ),
                ] else ...[
                  _AmountCard(payment: _payment),
                  const SizedBox(height: 16),
                  _MethodsCard(
                    method: _method,
                    enabled: _stage == _PayStage.details,
                    onChanged: (value) =>
                        setState(() => _method = value),
                  ),
                  const SizedBox(height: 8),
                  Text('Demo mode — no real money moves.',
                      textAlign: TextAlign.center,
                      style: AppText.caption),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: AppSpacing.buttonHeight,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _stage == _PayStage.details
                          ? _pay
                          : null,
                      child: _stage == _PayStage.processing
                          ? const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Text('Processing…'),
                              ],
                            )
                          : Text('Pay ₹${_payment.total}'),
                    ),
                  ),
                  if (_stage == _PayStage.processing) ...[
                    const SizedBox(height: 12),
                    Text('Contacting bank (demo)…',
                        textAlign: TextAlign.center,
                        style: AppText.caption),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.payment});

  final ParkingPayment payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AMOUNT DUE', style: AppText.uppercaseLabel),
          const SizedBox(height: 6),
          Text('₹${payment.total}', style: AppText.countdown),
          const SizedBox(height: 12),
          _FeeLine(label: 'Parking fee', value: '₹${payment.fee}'),
          const SizedBox(height: 6),
          _FeeLine(label: 'Tax (GST)', value: '₹${payment.tax}'),
          const SizedBox(height: 6),
          _FeeLine(
              label: 'Slot ${payment.slot} · ${payment.vehicle}',
              value: payment.durationLabel),
        ],
      ),
    );
  }
}

class _FeeLine extends StatelessWidget {
  const _FeeLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white60, fontSize: 13)),
      ),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700)),
    ]);
  }
}

class _MethodsCard extends StatelessWidget {
  const _MethodsCard(
      {required this.method,
      required this.enabled,
      required this.onChanged});

  final String method;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demo payment method',
                style: AppText.cardTitle.copyWith(fontSize: 17)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: method,
            onChanged: (value) {
              if (enabled && value != null) onChanged(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (name, icon, recommended) in _demoMethods)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: name,
                    activeColor: AppColors.primary,
                    secondary:
                        Icon(icon, color: AppColors.primary),
                    title: Row(children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.indicatorBg,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: const Text('Recommended',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard(
      {required this.receiptId,
      required this.method,
      required this.amount});

  final String receiptId;
  final String method;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: [
        _TxRow(label: 'Amount', value: amount, bold: true),
        _TxRow(label: 'Receipt ID', value: receiptId),
        _TxRow(label: 'Method', value: '$method · Demo'),
        _TxRow(
            label: 'Paid at',
            value: receiptTimestamp(),
            last: true),
      ]),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow(
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
      child: Row(children: [
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w700)),
        ),
      ]),
    );
  }
}
