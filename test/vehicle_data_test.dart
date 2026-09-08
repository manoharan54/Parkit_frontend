import 'package:flutter_test/flutter_test.dart';
import 'package:parkit_flutter/vehicle_data.dart';

void main() {
  test('Category labels map to catalog kinds', () {
    expect(vehicleKindForLabel('Car'), 'car');
    expect(vehicleKindForLabel('Scooty'), 'scooty');
    expect(vehicleKindForLabel('Mini-Truck'), 'miniTruck');
    expect(vehicleKindForLabel('Mini-Van'), 'miniVan');
    expect(vehicleKindForLabel('E-Cycle'), 'eCycle');
    // Bike and Auto have no catalog dataset.
    expect(vehicleKindForLabel('Bike'), isNull);
    expect(vehicleKindForLabel('Auto'), isNull);
  });

  test('Car prefix queries resolve brand + model', () {
    final bre =
        suggestModels(query: 'Bre', kind: 'car').map((e) => e.display);
    expect(bre.first, 'Maruti Suzuki Brezza');

    final marBre =
        suggestModels(query: 'mar bre', kind: 'car').map((e) => e.display);
    expect(marBre.first, 'Maruti Suzuki Brezza');

    final swift =
        suggestModels(query: 'swift', kind: 'car').map((e) => e.display);
    expect(swift.first, 'Maruti Suzuki Swift');

    final cre =
        suggestModels(query: 'cre', kind: 'car').map((e) => e.display);
    expect(cre.first, 'Hyundai Creta');

    final nex =
        suggestModels(query: 'nex', kind: 'car').map((e) => e.display);
    expect(nex.first, 'Tata Nexon');
  });

  test('Scooter number queries resolve correctly', () {
    final act = suggestModels(query: 'Act', kind: 'scooty');
    expect(act.map((e) => e.display),
        containsAll(['Honda Activa', 'Honda Activa 125', 'Honda Activa 6G']));

    final jup =
        suggestModels(query: 'Jup', kind: 'scooty').map((e) => e.display);
    expect(jup, containsAll(['TVS Jupiter', 'TVS Jupiter 125']));

    final nt =
        suggestModels(query: 'Nt', kind: 'scooty').map((e) => e.display);
    expect(nt.first, 'TVS Ntorq 125');

    final n450 =
        suggestModels(query: '450', kind: 'scooty').map((e) => e.display);
    expect(
        n450,
        containsAll(
            ['Ather 450', 'Ather 450X', 'Ather 450S', 'Ather 450 Apex']));

    final s1 =
        suggestModels(query: 'S1', kind: 'scooty').map((e) => e.display);
    expect(s1, containsAll(['Ola Electric S1', 'Ola Electric S1 Pro']));

    final riz =
        suggestModels(query: 'Riz', kind: 'scooty').map((e) => e.display);
    expect(riz.first, 'Ather Rizta');
  });

  test('Mini truck, van and e-cycle queries resolve', () {
    final ace =
        suggestModels(query: 'Ace', kind: 'miniTruck').map((e) => e.display);
    expect(
        ace,
        containsAll([
          'Tata Ace',
          'Tata Ace Gold',
          'Tata Ace EV',
          'Tata Ace HT Plus'
        ]));

    final eeco =
        suggestModels(query: 'Eeco', kind: 'miniVan').map((e) => e.display);
    expect(eeco.first, 'Maruti Suzuki Eeco');

    final jeeto =
        suggestModels(query: 'Jeeto', kind: 'miniTruck').map((e) => e.display);
    expect(jeeto,
        containsAll(['Mahindra Jeeto', 'Mahindra Jeeto Plus']));

    final lectro =
        suggestModels(query: 'Lectro', kind: 'eCycle').map((e) => e.display);
    expect(
        lectro,
        containsAll([
          'Hero Lectro C6',
          'Hero Lectro C7',
          'Hero Lectro C8',
          'Hero Lectro H7'
        ]));

    final emx =
        suggestModels(query: 'EMX', kind: 'eCycle').map((e) => e.display);
    expect(emx.first, 'EMotorad EMX');
  });

  test('Queries stay within their category and limit results', () {
    // Scooter query must not leak car models.
    final act = suggestModels(query: 'Act', kind: 'scooty');
    expect(act.every((e) => e.kind == 'scooty'), isTrue);

    // Unknown gibberish yields nothing.
    expect(suggestModels(query: 'zzzqqq', kind: 'car'), isEmpty);

    // Result cap is respected.
    expect(suggestModels(query: 'a', kind: 'car').length,
        lessThanOrEqualTo(6));

    // Empty query returns popular picks for the kind.
    final popular = suggestModels(query: '', kind: 'car');
    expect(popular, isNotEmpty);
    expect(popular.every((e) => e.kind == 'car'), isTrue);
  });
}
