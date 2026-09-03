import 'package:flutter/material.dart';
import 'styles.dart';

/// Reusable label widget for form fields.
Widget appLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Text(text, style: AppText.label),
    );

/// Reusable field label (used in edit profile screen).
Widget appFieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );

/// Metric widget showing a value and label, used on home screen.
class AppMetric extends StatelessWidget {
  const AppMetric({required this.value, required this.label, super.key});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.small),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      );
}

/// Action button widget used on home screen for quick actions.
class AppAction extends StatelessWidget {
  const AppAction({required this.icon, required this.label, this.onTap, super.key});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.medium),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.medium)),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: AppSpacing.small),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}
