// lib/models/prayer_today.dart
class PTTimes {
  final String fajr;
  final String syuruk;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  PTTimes({
    required this.fajr,
    required this.syuruk,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PTTimes.fromJakim(Map<String, dynamic> json) {
    return PTTimes(
      fajr: json['fajr'] ?? '',
      syuruk: json['syuruk'] ?? '',
      dhuhr: json['dhuhr'] ?? '',
      asr: json['asr'] ?? '',
      maghrib: json['maghrib'] ?? '',
      isha: json['isha'] ?? '',
    );
  }
}