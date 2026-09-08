/// Indian-market vehicle catalog backing the ParkIt Edit Vehicle form.
///
/// Each record stores brand + model + vehicle kind + segment + fuel +
/// aliases, so the model autocomplete can resolve short queries like `Bre`
/// → Maruti Suzuki Brezza or `450` → Ather 450X.
class VehicleEntry {
  const VehicleEntry(this.brand, this.model, this.kind,
      {this.segment = '', this.fuel = '', this.aliases = const []});

  final String brand;
  final String model;
  /// One of: car, scooty, miniTruck, miniVan, eCycle.
  final String kind;
  /// hatchback, sedan, compact_suv, suv, scooter, mini_van_bus,
  /// mini_truck, e_cycle (may be empty).
  final String segment;
  final String fuel;
  final List<String> aliases;

  String get display => '$brand $model';

  bool get isEV => fuel.toLowerCase() == 'ev';
}

/// Display label for a segment key.
String segmentLabel(String segment) {
  switch (segment) {
    case 'hatchback':
      return 'Hatchback';
    case 'sedan':
      return 'Sedan';
    case 'compact_suv':
      return 'Compact SUV';
    case 'suv':
      return 'SUV';
    case 'scooter':
      return 'Scooter';
    case 'mini_van_bus':
      return 'Mini Van';
    case 'mini_truck':
      return 'Mini Truck';
    case 'e_cycle':
      return 'E-Cycle';
    default:
      return '';
  }
}

/// Maps the 7 fixed Edit-Vehicle categories to catalog kinds.
/// Bike and Auto have no catalog dataset (free-text models).
String? vehicleKindForLabel(String label) {
  switch (label.trim()) {
    case 'Car':
      return 'car';
    case 'Scooty':
      return 'scooty';
    case 'Mini-Truck':
      return 'miniTruck';
    case 'Mini-Van':
      return 'miniVan';
    case 'E-Cycle':
      return 'eCycle';
    default:
      return null;
  }
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[-_.,/+]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Lower is better. -1 means no match.
int _matchScore(String query, VehicleEntry e) {
  final terms = <String>{
    _norm(e.model),
    _norm(e.brand),
    _norm('${e.brand} ${e.model}'),
    ...e.aliases.map(_norm),
  };
  final words = terms.expand((t) => t.split(' ')).toSet();
  final qws = query.split(' ').where((w) => w.isNotEmpty).toList();
  if (qws.isEmpty) return 50;
  for (final qw in qws) {
    if (!words.any((w) => w.startsWith(qw))) return -1;
  }
  final model = _norm(e.model);
  if (model == query) return 0;
  if (model.startsWith(query)) return 1;
  if (_norm('${e.brand} ${e.model}').startsWith(query)) return 2;
  return 3;
}

/// Prefix-aware suggestions for [query] within one catalog [kind].
/// An empty query returns the first entries (popular picks).
List<VehicleEntry> suggestModels(
    {required String query, required String kind, int limit = 6}) {
  final q = _norm(query);
  final scored = <(int, VehicleEntry)>[];
  for (final e in _catalog) {
    if (e.kind != kind) continue;
    final score = _matchScore(q, e);
    if (score >= 0) scored.add((score, e));
  }
  scored.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    if (c != 0) return c;
    return a.$2.model.length.compareTo(b.$2.model.length);
  });
  return scored.take(limit).map((e) => e.$2).toList();
}

const List<VehicleEntry> _catalog = [
  // ------------------------------- Cars -------------------------------
  VehicleEntry('Maruti Suzuki', 'Alto', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Alto K10', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', '800', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Zen', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Zen Estilo', 'car',
      segment: 'hatchback', aliases: ['estilo']),
  VehicleEntry('Maruti Suzuki', 'WagonR', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Swift', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'A-Star', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Ritz', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Celerio', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Baleno', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Ignis', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'S-Presso', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Eeco', 'car', segment: 'hatchback'),
  VehicleEntry('Maruti Suzuki', 'Dzire', 'car', segment: 'sedan'),
  VehicleEntry('Maruti Suzuki', 'SX4', 'car', segment: 'sedan'),
  VehicleEntry('Maruti Suzuki', 'Ciaz', 'car', segment: 'sedan'),
  VehicleEntry('Maruti Suzuki', 'Brezza', 'car',
      segment: 'compact_suv', aliases: ['vitara brezza']),
  VehicleEntry('Maruti Suzuki', 'Fronx', 'car', segment: 'compact_suv'),
  VehicleEntry('Maruti Suzuki', 'Grand Vitara', 'car', segment: 'suv'),
  VehicleEntry('Maruti Suzuki', 'Jimny', 'car', segment: 'suv'),
  VehicleEntry('Maruti Suzuki', 'S-Cross', 'car', segment: 'compact_suv'),
  VehicleEntry('Hyundai', 'Santro', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'Getz', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'i10', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'Grand i10', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'Grand i10 Nios', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'i20', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'Eon', 'car', segment: 'hatchback'),
  VehicleEntry('Hyundai', 'Accent', 'car', segment: 'sedan'),
  VehicleEntry('Hyundai', 'Xcent', 'car', segment: 'sedan'),
  VehicleEntry('Hyundai', 'Aura', 'car', segment: 'sedan'),
  VehicleEntry('Hyundai', 'Verna', 'car', segment: 'sedan'),
  VehicleEntry('Hyundai', 'Venue', 'car', segment: 'compact_suv'),
  VehicleEntry('Hyundai', 'Creta', 'car', segment: 'compact_suv'),
  VehicleEntry('Hyundai', 'Alcazar', 'car', segment: 'suv'),
  VehicleEntry('Hyundai', 'Exter', 'car', segment: 'compact_suv'),
  VehicleEntry('Hyundai', 'Tucson', 'car', segment: 'suv'),
  VehicleEntry('Hyundai', 'Santa Fe', 'car', segment: 'suv'),
  VehicleEntry('Tata', 'Indica', 'car', segment: 'hatchback'),
  VehicleEntry('Tata', 'Indica Vista', 'car', segment: 'hatchback'),
  VehicleEntry('Tata', 'Nano', 'car', segment: 'hatchback'),
  VehicleEntry('Tata', 'Bolt', 'car', segment: 'hatchback'),
  VehicleEntry('Tata', 'Tiago', 'car', segment: 'hatchback'),
  VehicleEntry('Tata', 'Altroz', 'car', segment: 'hatchback'),
  VehicleEntry('Tata', 'Zest', 'car', segment: 'sedan'),
  VehicleEntry('Tata', 'Indigo', 'car', segment: 'sedan'),
  VehicleEntry('Tata', 'Indigo CS', 'car', segment: 'sedan'),
  VehicleEntry('Tata', 'Manza', 'car', segment: 'sedan'),
  VehicleEntry('Tata', 'Tigor', 'car', segment: 'sedan'),
  VehicleEntry('Tata', 'Sierra', 'car', segment: 'suv'),
  VehicleEntry('Tata', 'Safari', 'car', segment: 'suv'),
  VehicleEntry('Tata', 'Harrier', 'car', segment: 'suv'),
  VehicleEntry('Tata', 'Nexon', 'car', segment: 'compact_suv'),
  VehicleEntry('Tata', 'Punch', 'car', segment: 'compact_suv'),
  VehicleEntry('Tata', 'Curvv', 'car', segment: 'compact_suv'),
  VehicleEntry('Honda', 'City', 'car', segment: 'sedan'),
  VehicleEntry('Honda', 'Amaze', 'car', segment: 'sedan'),
  VehicleEntry('Honda', 'Civic', 'car', segment: 'sedan'),
  VehicleEntry('Honda', 'Accord', 'car', segment: 'sedan'),
  VehicleEntry('Honda', 'Brio', 'car', segment: 'hatchback'),
  VehicleEntry('Honda', 'Jazz', 'car', segment: 'hatchback'),
  VehicleEntry('Honda', 'WR-V', 'car', segment: 'compact_suv'),
  VehicleEntry('Honda', 'Elevate', 'car', segment: 'compact_suv'),
  VehicleEntry('Toyota', 'Qualis', 'car', segment: 'suv'),
  VehicleEntry('Toyota', 'Innova', 'car', segment: 'suv'),
  VehicleEntry('Toyota', 'Innova Crysta', 'car', segment: 'suv'),
  VehicleEntry('Toyota', 'Etios', 'car', segment: 'sedan'),
  VehicleEntry('Toyota', 'Etios Liva', 'car', segment: 'hatchback'),
  VehicleEntry('Toyota', 'Yaris', 'car', segment: 'sedan'),
  VehicleEntry('Toyota', 'Glanza', 'car', segment: 'hatchback'),
  VehicleEntry('Toyota', 'Urban Cruiser', 'car', segment: 'compact_suv'),
  VehicleEntry('Toyota', 'Urban Cruiser Hyryder', 'car',
      segment: 'compact_suv'),
  VehicleEntry('Mahindra', 'Bolero', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'Scorpio', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'Scorpio Classic', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'Scorpio-N', 'car',
      segment: 'suv', aliases: ['scorpio n']),
  VehicleEntry('Mahindra', 'XUV500', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'XUV700', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'XUV300', 'car', segment: 'compact_suv'),
  VehicleEntry('Mahindra', 'XUV 3XO', 'car',
      segment: 'compact_suv', aliases: ['xuv 3xo']),
  VehicleEntry('Mahindra', 'TUV300', 'car', segment: 'compact_suv'),
  VehicleEntry('Mahindra', 'Thar', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'Thar Roxx', 'car', segment: 'suv'),
  VehicleEntry('Mahindra', 'BE 6', 'car',
      segment: 'compact_suv', fuel: 'EV'),
  VehicleEntry('Mahindra', 'XEV 9e', 'car', segment: 'suv', fuel: 'EV'),
  VehicleEntry('Mahindra', 'XEV 9S', 'car', segment: 'suv', fuel: 'EV'),
  VehicleEntry('Mahindra', 'XUV400', 'car',
      segment: 'compact_suv', fuel: 'EV'),
  VehicleEntry('Kia', 'Seltos', 'car', segment: 'compact_suv'),
  VehicleEntry('Kia', 'Sonet', 'car', segment: 'compact_suv'),
  VehicleEntry('Kia', 'Carens', 'car', segment: 'suv'),
  VehicleEntry('Kia', 'Carnival', 'car', segment: 'suv'),
  VehicleEntry('Renault', 'Duster', 'car', segment: 'compact_suv'),
  VehicleEntry('Renault', 'Kwid', 'car', segment: 'hatchback'),
  VehicleEntry('Renault', 'Triber', 'car', segment: 'suv'),
  VehicleEntry('Renault', 'Kiger', 'car', segment: 'compact_suv'),
  VehicleEntry('Nissan', 'Micra', 'car', segment: 'hatchback'),
  VehicleEntry('Nissan', 'Sunny', 'car', segment: 'sedan'),
  VehicleEntry('Nissan', 'Terrano', 'car', segment: 'compact_suv'),
  VehicleEntry('Nissan', 'Magnite', 'car', segment: 'compact_suv'),
  VehicleEntry('Ford', 'Figo', 'car', segment: 'hatchback'),
  VehicleEntry('Ford', 'Aspire', 'car', segment: 'sedan'),
  VehicleEntry('Ford', 'Fiesta', 'car', segment: 'sedan'),
  VehicleEntry('Ford', 'EcoSport', 'car', segment: 'compact_suv'),
  VehicleEntry('Volkswagen', 'Polo', 'car', segment: 'hatchback'),
  VehicleEntry('Volkswagen', 'Vento', 'car', segment: 'sedan'),
  VehicleEntry('Volkswagen', 'Ameo', 'car', segment: 'sedan'),
  VehicleEntry('Volkswagen', 'Taigun', 'car', segment: 'compact_suv'),
  VehicleEntry('Volkswagen', 'Virtus', 'car', segment: 'sedan'),
  VehicleEntry('Skoda', 'Fabia', 'car', segment: 'hatchback'),
  VehicleEntry('Skoda', 'Rapid', 'car', segment: 'sedan'),
  VehicleEntry('Skoda', 'Slavia', 'car', segment: 'sedan'),
  VehicleEntry('Skoda', 'Kushaq', 'car', segment: 'compact_suv'),
  VehicleEntry('Fiat', 'Palio', 'car', segment: 'hatchback'),
  VehicleEntry('Fiat', 'Punto', 'car', segment: 'hatchback'),
  VehicleEntry('Fiat', 'Linea', 'car', segment: 'sedan'),
  VehicleEntry('Chevrolet', 'Spark', 'car', segment: 'hatchback'),
  VehicleEntry('Chevrolet', 'Beat', 'car', segment: 'hatchback'),
  VehicleEntry('Chevrolet', 'Aveo', 'car', segment: 'sedan'),
  VehicleEntry('Chevrolet', 'Cruze', 'car', segment: 'sedan'),
  VehicleEntry('Chevrolet', 'Captiva', 'car', segment: 'suv'),
  VehicleEntry('MG', 'Hector', 'car', segment: 'suv'),
  VehicleEntry('MG', 'Astor', 'car', segment: 'compact_suv'),
  VehicleEntry('MG', 'ZS EV', 'car', segment: 'compact_suv', fuel: 'EV'),
  VehicleEntry('MG', 'Windsor', 'car', segment: 'hatchback'),
  VehicleEntry('Citroën', 'C3', 'car', segment: 'hatchback'),
  VehicleEntry('Citroën', 'C3 Aircross', 'car', segment: 'suv'),
  VehicleEntry('Citroën', 'C5 Aircross', 'car', segment: 'suv'),
  // ------------------------------ Scooters ------------------------------
  VehicleEntry('Honda', 'Activa', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Activa 3G', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Activa 4G', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Activa 5G', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Activa 6G', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Activa 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Activa 125 BS6', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Dio', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Dio BS6', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Aviator', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Grazia', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Grazia 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Cliq', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Honda', 'Navi', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Scooty Pep', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Scooty Pep+', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Scooty Streak', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Scooty Zest', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Jupiter', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Jupiter 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Ntorq 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'Wego', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('TVS', 'iQube', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('TVS', 'X', 'scooty', segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Suzuki', 'Access 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Suzuki', 'Access 125 BS6', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Suzuki', 'Burgman Street', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Suzuki', 'Burgman Street EX', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Suzuki', 'Avenis', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Suzuki', 'Lets', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Fascino', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Fascino 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Ray', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Ray Z', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Ray ZR', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Ray ZR 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Yamaha', 'Aerox 155', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Pleasure', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Pleasure+', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Pleasure+ XTEC', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Maestro', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Maestro Edge', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Maestro Edge 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Destini 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Destini Prime', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Xoom', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Xoom 110', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero', 'Xoom 125', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Hero Electric', 'Optima', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Hero Electric', 'Photon', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Hero Electric', 'NYX', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Hero Electric', 'Atria', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ather', '450', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ather', '450X', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ather', '450S', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ather', '450 Apex', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ather', 'Rizta', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ola Electric', 'S1', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ola Electric', 'S1 Pro', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ola Electric', 'S1 Air', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ola Electric', 'S1X', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ola Electric', 'S1X+', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ola Electric', 'S1 Pro+', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Bajaj', 'Chetak', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Bajaj', 'Chetak Premium', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Bajaj', 'Chetak Urbane', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Bajaj', 'Chetak 35 Series', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ampere', 'Magnus', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ampere', 'Magnus EX', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ampere', 'Primus', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Ampere', 'Zeal EX', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Okinawa', 'Praise', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Okinawa', 'PraisePro', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Okinawa', 'Ridge', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Okinawa', 'iPraise+', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Okinawa', 'Okhi90', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Simple Energy', 'One', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('River', 'Indie', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Vida', 'V1', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Vida', 'V2', 'scooty',
      segment: 'scooter', fuel: 'EV'),
  VehicleEntry('Kinetic', 'Honda ZX', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Kinetic', 'Blaze', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  VehicleEntry('Kinetic', 'Nova', 'scooty',
      segment: 'scooter', fuel: 'Petrol'),
  // ------------------------- Mini Van / Mini Bus -------------------------
  VehicleEntry('Maruti Suzuki', 'Omni', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Petrol/CNG'),
  VehicleEntry('Maruti Suzuki', 'Eeco', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Petrol/CNG'),
  VehicleEntry('Maruti Suzuki', 'Versa', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Petrol'),
  VehicleEntry('Mahindra', 'Supro', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Magic', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Magic Express', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Magic Gold', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Winger', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Force', 'Traveller', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Force', 'Trax Cruiser', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  VehicleEntry('Force', 'Urbania', 'miniVan',
      segment: 'mini_van_bus', fuel: 'Diesel'),
  // ------------------------------ Mini Trucks ------------------------------
  VehicleEntry('Tata', 'Ace', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel/Petrol/CNG'),
  VehicleEntry('Tata', 'Ace Gold', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel/Petrol/CNG'),
  VehicleEntry('Tata', 'Ace HT Plus', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Ace EV', 'miniTruck',
      segment: 'mini_truck', fuel: 'EV'),
  VehicleEntry('Tata', 'Intra V10', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Intra V30', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Intra V50', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Tata', 'Intra V70', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Mahindra', 'Jeeto', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel/Petrol/CNG'),
  VehicleEntry('Mahindra', 'Jeeto Plus', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Mahindra', 'Supro Profit Truck', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Mahindra', 'Supro Profit Truck Maxi', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Mahindra', 'Bolero Pik-Up', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Mahindra', 'Bolero Camper', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Ashok Leyland', 'Dost', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Ashok Leyland', 'Dost+', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Ashok Leyland', 'Bada Dost', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Ashok Leyland', 'Bada Dost i5', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel'),
  VehicleEntry('Maruti Suzuki', 'Super Carry', 'miniTruck',
      segment: 'mini_truck', fuel: 'Petrol/CNG'),
  VehicleEntry('Piaggio', 'Ape Xtra', 'miniTruck',
      segment: 'mini_truck', fuel: 'Diesel/CNG'),
  VehicleEntry('Piaggio', 'Ape E-Xtra', 'miniTruck',
      segment: 'mini_truck', fuel: 'EV'),
  VehicleEntry('Euler', 'HiLoad EV', 'miniTruck',
      segment: 'mini_truck', fuel: 'EV'),
  VehicleEntry('Altigreen', 'neEV Tez', 'miniTruck',
      segment: 'mini_truck', fuel: 'EV'),
  // -------------------------------- E-Cycles --------------------------------
  VehicleEntry('Hero Lectro', 'C6', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Hero Lectro', 'C7', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Hero Lectro', 'C8', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Hero Lectro', 'H7', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Hero Lectro', 'WINN', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Hero Lectro', 'F6i', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Hero Lectro', 'F3', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('EMotorad', 'EMX', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('EMotorad', 'T-Rex', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('EMotorad', 'Doodle', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('EMotorad', 'X1', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('EMotorad', 'Lil E', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Ninety One', 'Meraki', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Ninety One', 'E-Switch', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Ninety One', 'Wanderer', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Ninety One', 'Trooper', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Toutche', 'Heileo H100', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Toutche', 'Heileo M100', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Toutche', 'Heileo H200', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Firefox', 'Adventron', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Firefox', 'Urban Eco', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Firefox', 'Flip', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Voltrix', 'Urban', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Voltrix', 'Ingenious', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Voltrix', 'Flex', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Being Human', 'BH12', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
  VehicleEntry('Being Human', 'BH27', 'eCycle',
      segment: 'e_cycle', fuel: 'EV'),
];
