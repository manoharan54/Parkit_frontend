import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/parking_rate.dart';

void main() {
  test('Tariff table: first hour flat, then per completed 30-min block', () {
    String fee(int minutes) =>
        '₹${parkingFeeFor(Duration(minutes: minutes))}';
    expect(fee(0), '₹0');
    expect(fee(1), '₹20');
    expect(fee(30), '₹20');
    expect(fee(60), '₹20');
    expect(fee(61), '₹20');
    expect(fee(90), '₹30');
    expect(fee(120), '₹40');
    expect(fee(130), '₹40');
    expect(fee(150), '₹50');
    expect(fee(180), '₹60');
    expect(fee(240), '₹80');
  });

  test('Daily maximum caps at ₹150', () {
    expect(parkingFeeFor(const Duration(hours: 8)), 150);
    expect(parkingFeeFor(const Duration(hours: 24)), 150);
    expect(parkingFeeFor(const Duration(hours: 48)), 150);
  });

  test('Tax is 5% with a ₹1 floor, total is fee + tax', () {
    expect(parkingTaxFor(0), 0);
    expect(parkingTaxFor(20), 1);
    expect(parkingTaxFor(40), 2);
    expect(parkingTaxFor(150), 8);
    expect(parkingTotalFor(const Duration(minutes: 90)), 32);
    expect(parkingTotalFor(const Duration(minutes: 130)), 42);
  });

  test('Duration formatters', () {
    expect(formatDurationClock(const Duration(hours: 1, minutes: 26, seconds: 43)),
        '01h 26m 43s');
    expect(formatDurationClock(const Duration(minutes: 5, seconds: 7)),
        '00h 05m 07s');
    expect(formatDurationShort(const Duration(hours: 2, minutes: 27)),
        '2h 27m');
    expect(formatDurationShort(const Duration(minutes: 45)), '0h 45m');
  });
}
