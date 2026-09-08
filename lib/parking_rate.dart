/// ParkIt demo tariff for residential / community parking.
///
/// Simple and easy to explain: first hour → ₹20, every additional
/// 30 minutes → ₹10, maximum daily charge → ₹150.
/// Examples: 1h30m → ₹30 · 2h10m → ₹40 · 4h → ₹80.
///
/// Parking fee in rupees for [duration].
///
/// The first 60 minutes cost a flat ₹20. Each additional *completed*
/// 30-minute block adds ₹10. The total is capped at ₹150 per day.
int parkingFeeFor(Duration duration) {
  if (duration.inSeconds <= 0) return 0;
  final minutes = duration.inMinutes;
  if (minutes <= 60) return 20;
  final fee = 20 + ((minutes - 60) ~/ 30) * 10;
  return fee > 150 ? 150 : fee;
}

/// GST-style tax in rupees for a parking [fee] (5%, minimum ₹1).
int parkingTaxFor(int fee) {
  if (fee <= 0) return 0;
  final tax = (fee * 0.05).round();
  return tax < 1 ? 1 : tax;
}

/// Total payable (fee + tax) for [duration].
int parkingTotalFor(Duration duration) {
  final fee = parkingFeeFor(duration);
  return fee + parkingTaxFor(fee);
}

/// Ticking clock label, e.g. `01h 26m 43s`.
String formatDurationClock(Duration duration) {
  final total = duration.inSeconds.clamp(0, 99 * 3600);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return '${h.toString().padLeft(2, '0')}h '
      '${m.toString().padLeft(2, '0')}m '
      '${s.toString().padLeft(2, '0')}s';
}

/// Compact duration label, e.g. `2h 27m`.
String formatDurationShort(Duration duration) {
  final m = duration.inMinutes.clamp(0, 9999);
  return '${m ~/ 60}h ${m % 60}m';
}
