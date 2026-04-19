// lib/models/pt_times.dart
class PTDayTimes {
  final DateTime? fajr;
  final DateTime? syuruk;
  final DateTime? dhuhr;
  final DateTime? asr;
  final DateTime? maghrib;
  final DateTime? isha;

  const PTDayTimes({
    this.fajr,
    this.syuruk,
    this.dhuhr,
    this.asr,
    this.maghrib,
    this.isha,
  });

  PTDayTimes copyWith({
    DateTime? fajr,
    DateTime? syuruk,
    DateTime? dhuhr,
    DateTime? asr,
    DateTime? maghrib,
    DateTime? isha,
  }) {
    return PTDayTimes(
      fajr: fajr ?? this.fajr,
      syuruk: syuruk ?? this.syuruk,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
    );
  }
}