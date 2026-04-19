// lib/zones/zone_store.dart
import 'dart:math' as math;

class Zone {
  final String code;
  final String name;

  const Zone({required this.code, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Zone && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$code – $name';
}

class ZoneStore {
  // Public constructor
  ZoneStore();

  /// Simple singleton-style access
  static final ZoneStore instance = ZoneStore();

  // =========================
  // State -> Zones (JAKIM)
  // =========================
  static const Map<String, List<Zone>> _byState = {
    'Wilayah Persekutuan': [
      Zone(code: 'WLY01', name: 'Kuala Lumpur, Putrajaya'),
      Zone(code: 'WLY02', name: 'Labuan'),
    ],

    'Selangor': [
      Zone(
        code: 'SGR01',
        name: 'Gombak, Petaling, Sepang, Hulu Langat, Hulu Selangor, S.Alam',
      ),
      Zone(code: 'SGR02', name: 'Kuala Selangor, Sabak Bernam'),
      Zone(code: 'SGR03', name: 'Klang, Kuala Langat'),
    ],

    'Perlis': [
      Zone(code: 'PLS01', name: 'Kangar, Padang Besar, Arau'),
    ],

    'Pulau Pinang': [
      Zone(code: 'PNG01', name: 'Seluruh Negeri Pulau Pinang'),
    ],

    'Kedah': [
      Zone(
        code: 'KDH01',
        name: 'Kota Setar, Kubang Pasu, Pokok Sena (Daerah Kecil)',
      ),
      Zone(code: 'KDH02', name: 'Kuala Muda, Yan, Pendang'),
      Zone(code: 'KDH03', name: 'Padang Terap, Sik'),
      Zone(code: 'KDH04', name: 'Baling'),
      Zone(code: 'KDH05', name: 'Bandar Baharu, Kulim'),
      Zone(code: 'KDH06', name: 'Langkawi'),
      Zone(code: 'KDH07', name: 'Puncak Gunung Jerai'),
    ],

    'Perak': [
      Zone(code: 'PRK01', name: 'Tapah, Slim River, Tanjung Malim'),
      Zone(
        code: 'PRK02',
        name: 'Kuala Kangsar, Sg. Siput , Ipoh, Batu Gajah, Kampar',
      ),
      Zone(code: 'PRK03', name: 'Lenggong, Pengkalan Hulu, Grik'),
      Zone(code: 'PRK04', name: 'Temengor, Belum'),
      Zone(
        code: 'PRK05',
        name:
        'Kg Gajah, Teluk Intan, Bagan Datuk, Seri Iskandar, Beruas, Parit, Lumut, Sitiawan, Pulau Pangkor',
      ),
      Zone(code: 'PRK06', name: 'Selama, Taiping, Bagan Serai, Parit Buntar'),
      Zone(code: 'PRK07', name: 'Bukit Larut'),
    ],

    'Melaka': [
      Zone(code: 'MLK01', name: 'SELURUH NEGERI MELAKA'),
    ],

    'Negeri Sembilan': [
      Zone(code: 'NGS01', name: 'Tampin, Jempol'),
      Zone(code: 'NGS02', name: 'Jelebu, Kuala Pilah, Rembau'),
      Zone(code: 'NGS03', name: 'Port Dickson, Seremban'),
    ],

    'Johor': [
      Zone(code: 'JHR01', name: 'Pulau Aur dan Pulau Pemanggil'),
      Zone(code: 'JHR02', name: 'Johor Bahru, Kota Tinggi, Mersing, Kulai'),
      Zone(code: 'JHR03', name: 'Kluang, Pontian'),
      Zone(
        code: 'JHR04',
        name: 'Batu Pahat, Muar, Segamat, Gemas Johor, Tangkak',
      ),
    ],

    'Pahang': [
      Zone(code: 'PHG01', name: 'Pulau Tioman'),
      Zone(code: 'PHG02', name: 'Kuantan, Pekan, Muadzam Shah'),
      Zone(
        code: 'PHG03',
        name: 'Jerantut, Temerloh, Maran, Bera, Chenor, Jengka',
      ),
      Zone(code: 'PHG04', name: 'Bentong, Lipis, Raub'),
      Zone(code: 'PHG05', name: 'Genting Sempah, Janda Baik, Bukit Tinggi'),
      Zone(
        code: 'PHG06',
        name: 'Cameron Highlands, Genting Higlands, Bukit Fraser',
      ),
      Zone(
        code: 'PHG07',
        name: 'Zon Khas Daerah Rompin, (Mukim Rompin, Mukim Endau, Mukim Pontian)',
      ),
    ],

    'Terengganu': [
      Zone(code: 'TRG01', name: 'Kuala Terengganu, Marang, Kuala Nerus'),
      Zone(code: 'TRG02', name: 'Besut, Setiu'),
      Zone(code: 'TRG03', name: 'Hulu Terengganu'),
      Zone(code: 'TRG04', name: 'Dungun, Kemaman'),
    ],

    'Kelantan': [
      Zone(
        code: 'KTN01',
        name:
        'Bachok, Kota Bharu, Machang, Pasir Mas, Pasir Puteh, Tanah Merah, Tumpat, Kuala Krai, Mukim Chiku',
      ),
      Zone(
        code: 'KTN02',
        name: 'Gua Musang (Daerah Galas Dan Bertam), Jeli, Jajahan Kecil Lojing',
      ),
    ],

    'Sabah': [
      Zone(
        code: 'SBH01',
        name:
        'Bahagian Sandakan (Timur), Bukit Garam, Semawang, Temanggong, Tambisan, Bandar Sandakan, Sukau',
      ),
      Zone(
        code: 'SBH02',
        name:
        'Beluran, Telupid, Pinangah, Terusan, Kuamut, Bahagian Sandakan (Barat)',
      ),
      Zone(
        code: 'SBH03',
        name:
        'Lahad Datu, Silabukan, Kunak, Sahabat, Semporna, Tungku, Bahagian Tawau (Timur)',
      ),
      Zone(
        code: 'SBH04',
        name: 'Bandar Tawau, Balong, Merotai, Kalabakan, Bahagian Tawau (Barat)',
      ),
      Zone(
        code: 'SBH05',
        name: 'Kudat, Kota Marudu, Pitas, Pulau Banggi, Bahagian Kudat',
      ),
      Zone(code: 'SBH06', name: 'Gunung Kinabalu'),
      Zone(
        code: 'SBH07',
        name:
        'Kota Kinabalu, Ranau, Kota Belud, Tuaran, Penampang, Papar, Putatan, Bahagian Pantai Barat',
      ),
      Zone(
        code: 'SBH08',
        name:
        'Pensiangan, Keningau, Tambunan, Nabawan, Bahagian Pendalaman (Atas)',
      ),
      Zone(
        code: 'SBH09',
        name:
        'Beaufort, Kuala Penyu, Sipitang, Tenom, Long Pasia, Membakut, Weston, Bahagian Pendalaman (Bawah)',
      ),
    ],

    'Sarawak': [
      Zone(code: 'SWK01', name: 'Limbang, Lawas, Sundar, Trusan'),
      Zone(code: 'SWK02', name: 'Miri, Niah, Bekenu, Sibuti, Marudi'),
      Zone(code: 'SWK03', name: 'Pandan, Belaga, Suai, Tatau, Sebauh, Bintulu'),
      Zone(
        code: 'SWK04',
        name: 'Sibu, Mukah, Dalat, Song, Igan, Oya, Balingian, Kanowit, Kapit',
      ),
      Zone(
        code: 'SWK05',
        name: 'Sarikei, Matu, Julau, Rajang, Daro, Bintangor, Belawai',
      ),
      Zone(
        code: 'SWK06',
        name:
        'Lubok Antu, Sri Aman, Roban, Debak, Kabong, Lingga, Engkelili, Betong, Spaoh, Pusa, Saratok',
      ),
      Zone(
        code: 'SWK07',
        name: 'Serian, Simunjan, Samarahan, Sebuyau, Meludam',
      ),
      Zone(code: 'SWK08', name: 'Kuching, Bau, Lundu, Sematan'),
      Zone(code: 'SWK09', name: 'Zon Khas (Kampung Patarikan)'),
    ],
  };

  /// Approximate centroid coordinates (lat, lon) for each zone code.
  /// Purpose: map GPS -> nearest prayer zone.
  ///
  /// These are practical approximations only.
  static const Map<String, ({double lat, double lon})> _zoneCentroids = {
    // Wilayah
    'WLY01': (lat: 3.1390, lon: 101.6869), // Kuala Lumpur
    'WLY02': (lat: 5.2800, lon: 115.2470), // Labuan

    // Selangor
    'SGR01': (lat: 3.0738, lon: 101.5183), // Shah Alam / Petaling / Sepang
    'SGR02': (lat: 3.6000, lon: 101.0000), // Kuala Selangor / Sabak Bernam
    'SGR03': (lat: 2.9900, lon: 101.4500), // Klang / Kuala Langat

    // Perlis / Penang / Melaka
    'PLS01': (lat: 6.4440, lon: 100.1980), // Kangar
    'PNG01': (lat: 5.4164, lon: 100.3327), // George Town
    'MLK01': (lat: 2.1896, lon: 102.2501), // Melaka

    // Kedah
    'KDH01': (lat: 6.1210, lon: 100.3670), // Alor Setar
    'KDH02': (lat: 5.6500, lon: 100.4900), // Sungai Petani
    'KDH03': (lat: 6.0500, lon: 100.9000), // Sik / Padang Terap
    'KDH04': (lat: 5.6740, lon: 100.9860), // Baling
    'KDH05': (lat: 5.2000, lon: 100.5600), // Bandar Baharu / Kulim
    'KDH06': (lat: 6.3500, lon: 99.8000),  // Langkawi
    'KDH07': (lat: 5.7870, lon: 100.4290), // Gunung Jerai

    // Perak
    'PRK01': (lat: 4.2000, lon: 101.2500), // Tapah / Tanjung Malim
    'PRK02': (lat: 4.5975, lon: 101.0901), // Ipoh
    'PRK03': (lat: 5.1330, lon: 100.9800), // Gerik / Lenggong
    'PRK04': (lat: 5.4500, lon: 101.3500), // Temengor / Belum
    'PRK05': (lat: 4.0000, lon: 100.7000), // Teluk Intan / Manjung side
    'PRK06': (lat: 4.8500, lon: 100.6300), // Taiping / Parit Buntar
    'PRK07': (lat: 4.8500, lon: 100.8000), // Bukit Larut

    // Negeri Sembilan
    'NGS01': (lat: 2.9000, lon: 102.4500), // Tampin / Jempol
    'NGS02': (lat: 2.7400, lon: 102.2500), // Jelebu / Kuala Pilah / Rembau
    'NGS03': (lat: 2.7258, lon: 101.9420), // Seremban / Port Dickson

    // Johor
    'JHR01': (lat: 2.6500, lon: 104.2500), // Pulau Aur / Pemanggil
    'JHR02': (lat: 1.4927, lon: 103.7414), // Johor Bahru
    'JHR03': (lat: 1.7600, lon: 103.2500), // Kluang / Pontian
    'JHR04': (lat: 2.1000, lon: 102.9000), // Batu Pahat / Muar / Segamat / Tangkak

    // Pahang
    'PHG01': (lat: 2.7900, lon: 104.1500), // Pulau Tioman
    'PHG02': (lat: 3.8077, lon: 103.3260), // Kuantan / Pekan / Muadzam Shah
    'PHG03': (lat: 3.4500, lon: 102.4200), // Jerantut / Temerloh / Maran / Bera
    'PHG04': (lat: 3.7900, lon: 101.8600), // Bentong / Lipis / Raub
    'PHG05': (lat: 3.3430, lon: 101.8390), // Genting Sempah / Janda Baik / Bukit Tinggi
    'PHG06': (lat: 4.4700, lon: 101.3800), // Cameron / Genting Highlands / Fraser's Hill
    'PHG07': (lat: 2.8000, lon: 103.4500), // Rompin special zone

    // Terengganu
    'TRG01': (lat: 5.3290, lon: 103.1360), // Kuala Terengganu
    'TRG02': (lat: 5.8300, lon: 102.5500), // Besut / Setiu
    'TRG03': (lat: 4.9500, lon: 103.0000), // Hulu Terengganu
    'TRG04': (lat: 4.7500, lon: 103.4000), // Dungun / Kemaman

    // Kelantan
    'KTN01': (lat: 6.1330, lon: 102.2380), // Kota Bharu
    'KTN02': (lat: 4.8800, lon: 101.9600), // Gua Musang / Jeli / Lojing

    // Sabah
    'SBH01': (lat: 5.8400, lon: 118.1200), // Sandakan / Sukau
    'SBH02': (lat: 5.7300, lon: 117.5000), // Beluran / Telupid
    'SBH03': (lat: 5.0300, lon: 118.3300), // Lahad Datu / Semporna
    'SBH04': (lat: 4.2500, lon: 117.8900), // Tawau
    'SBH05': (lat: 6.8900, lon: 116.8500), // Kudat
    'SBH06': (lat: 6.0750, lon: 116.5580), // Gunung Kinabalu
    'SBH07': (lat: 5.9804, lon: 116.0735), // Kota Kinabalu
    'SBH08': (lat: 5.3300, lon: 116.1700), // Keningau / Tambunan
    'SBH09': (lat: 5.3500, lon: 115.7400), // Beaufort / Sipitang / Tenom

    // Sarawak
    'SWK01': (lat: 4.7500, lon: 115.0000), // Limbang / Lawas
    'SWK02': (lat: 4.3990, lon: 113.9910), // Miri
    'SWK03': (lat: 3.1700, lon: 113.0300), // Bintulu
    'SWK04': (lat: 2.2870, lon: 111.8300), // Sibu / Kapit
    'SWK05': (lat: 2.1200, lon: 111.5200), // Sarikei
    'SWK06': (lat: 1.3000, lon: 111.3000), // Sri Aman / Betong / Saratok
    'SWK07': (lat: 1.1800, lon: 110.5500), // Serian / Samarahan / Simunjan
    'SWK08': (lat: 1.5533, lon: 110.3592), // Kuching
    'SWK09': (lat: 2.8500, lon: 112.5000), // Kampung Patarikan
  };

  /// List of state names (sorted for stable UI)
  List<String> get states {
    final s = _byState.keys.toList()..sort();
    return s;
  }

  /// Zones for a given state
  List<Zone> zonesIn(String state) => _byState[state] ?? const <Zone>[];

  /// Find a zone by its code (e.g. "WLY01"). Returns null if not found.
  Zone? lookupByCode(String code) {
    for (final entry in _byState.entries) {
      for (final z in entry.value) {
        if (z.code == code) return z;
      }
    }
    return null;
  }

  /// Given a zone code, return its state's name. Null if unknown.
  String? stateOf(String code) {
    for (final entry in _byState.entries) {
      for (final z in entry.value) {
        if (z.code == code) return entry.key;
      }
    }
    return null;
  }

  // ===================== LOCATION -> ZONE =====================

  /// Returns the nearest Zone based on centroid distance.
  /// Returns null if no centroid is available.
  Zone? findNearestZone(double lat, double lon) {
    String? bestCode;
    double bestKm = double.infinity;

    for (final e in _zoneCentroids.entries) {
      final km = _haversineKm(lat, lon, e.value.lat, e.value.lon);
      if (km < bestKm) {
        bestKm = km;
        bestCode = e.key;
      }
    }

    if (bestCode == null) return null;
    return lookupByCode(bestCode);
  }

  /// Convenience: returns both (state, zone) for UI dropdown selection.
  ({String state, Zone zone})? findNearestZoneWithState(double lat, double lon) {
    final z = findNearestZone(lat, lon);
    if (z == null) return null;
    final st = stateOf(z.code);
    if (st == null) return null;
    return (state: st, zone: z);
  }

  /// If you need the raw distance to the nearest zone (for debugging / QA).
  ({Zone zone, double km})? findNearestZoneWithDistance(double lat, double lon) {
    String? bestCode;
    double bestKm = double.infinity;

    for (final e in _zoneCentroids.entries) {
      final km = _haversineKm(lat, lon, e.value.lat, e.value.lon);
      if (km < bestKm) {
        bestKm = km;
        bestCode = e.key;
      }
    }

    if (bestCode == null) return null;
    final z = lookupByCode(bestCode);
    if (z == null) return null;
    return (zone: z, km: bestKm);
  }

  // Haversine distance (km)
  static double _haversineKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const r = 6371.0; // Earth radius (km)
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_deg2rad(lat1)) *
                math.cos(_deg2rad(lat2)) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;
}