import 'dart:convert';
import 'jakim_http.dart';

class MonthlyPrayerEntry {
  final DateTime date;
  final String subuh;
  final String syuruk;
  final String zohor;
  final String asar;
  final String maghrib;
  final String isyak;

  MonthlyPrayerEntry({
    required this.date,
    required this.subuh,
    required this.syuruk,
    required this.zohor,
    required this.asar,
    required this.maghrib,
    required this.isyak,
  });
}

class MonthlyPrayerService {
  const MonthlyPrayerService();

  Future<List<MonthlyPrayerEntry>> fetchMonth({
    required String zoneCode,
    required int month,
    required int year,
  }) async {
    final uri = Uri.parse("https://www.e-solat.gov.my/index.php").replace(
      queryParameters: {
        'r': 'esolatApi/TakwimSolat',
        'period': 'month',
        'zone': zoneCode.toUpperCase(),
        'month': month.toString(),
        'year': year.toString(),
      },
    );

    // Use the centralized helper so JAKIM's WAF accepts the request.
    final resp = await JakimHttp.get(uri, timeout: const Duration(seconds: 20));

    if (resp.statusCode >= 300) {
      throw Exception("HTTP ${resp.statusCode}");
    }

    final json = jsonDecode(resp.body);
    final list = json["prayerTime"];

    if (list is! List) {
      throw Exception("Format tidak sah");
    }

    return list.map((row) {
      return MonthlyPrayerEntry(
        date: DateTime.parse(row["date"]),
        subuh: row["fajr"],
        syuruk: row["syuruk"],
        zohor: row["dhuhr"],
        asar: row["asr"],
        maghrib: row["maghrib"],
        isyak: row["isha"] ?? row["isyak"],
      );
    }).toList();
  }
}