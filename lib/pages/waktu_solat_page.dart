import '../services/prefs_service.dart';
// lib/pages/waktu_solat_page.dart
import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri_date_time/hijri_date_time.dart';
import 'package:intl/intl.dart';

import '../models/prayer_times.dart';
import '../services/prayer_times_service.dart';
import '../zones/zone_store.dart';
import '../services/azan_audio_service.dart';
import '../services/notification_service.dart';

class WaktuSolatPage extends StatefulWidget {
  const WaktuSolatPage({super.key});

  @override
  State<WaktuSolatPage> createState() => _WaktuSolatPageState();
}

class _WaktuSolatPageState extends State<WaktuSolatPage> {
  final _service = PrayerTimesService();
  final ZoneStore _zones = ZoneStore();

  static const String _kLastState = 'last_state';
  static const String _kLastZoneCode = 'last_zone_code';
  static const String _kHasInitializedZone = 'has_initialized_zone';

  String? _selectedState;
  List<String> _stateList = [];
  List<Zone> _zoneList = [];
  Zone? _selectedZone;

  PrayerTimes? _times;
  bool _loading = false;
  bool _booting = true;
  String? _error;

  late DateTime _today;
  String _gregDisplay = '';
  String _hijriDisplay = '';

  String _nextName = '';
  DateTime? _nextAt;
  final _countdownNotifier = ValueNotifier<String>('—');
  Timer? _ticker;

  DateTime _lastTickDay = DateTime.now();

  static const Set<String> _singleZoneStates = {
    'Pulau Pinang',
    'Perlis',
    'Melaka',
  };

  static const Color _primary = Color(0xFF1F5E3E);
  static const Color _bg = Color(0xFFEAF6EE);
  static const Color _surface = Color(0xFFF7FBF8);
  static const Color _surface2 = Color(0xFFF2F8F3);
  static const Color _border = Color(0xFFD2E2D7);
  static const Color _muted = Color(0xFF5B6B63);
  static const Color _dangerText = Color(0xFFB42318);

  static const Color _gold = Color(0xFFB68D40);

  static const Color _rowHighlight = Color(0xFFDDEFE4);
  static const Color _rowHighlightBorder = Color(0xFF9FC9B4);

  static const List<BoxShadow> _softShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 14,
      offset: Offset(0, 8),
    ),
  ];

  static const double _titleSize = 36;
  static const double _dateSize = 15;
  static const double _labelSize = 14.5;
  static const double _pillTextSize = 16;
  static const double _bannerTextSize = 22;
  static const double _rowLabelSize = 26;
  static const double _rowTimeSize = 26;
  static const double _ampmSize = 16;
  static const double _sourceSize = 12;

  @override
  void initState() {
    super.initState();
    _init();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _countdownNotifier.dispose();
    AzanAudioService.instance.dispose();
    super.dispose();
  }


  Future<void> _playPrayerSound() async {
    final mode = await AzanAudioService.instance.getSoundMode();
    switch (mode) {
      case AzanSoundMode.none:
        break;
      case AzanSoundMode.azanOnly:
        await AzanAudioService.instance.playAzan();
        break;
      case AzanSoundMode.beepOnly:
        await NotificationService.instance.showSimpleNotification(
          title: 'Waktu Solat',
          body: 'Masuk waktu ' + _nextName,
        );
        break;
      case AzanSoundMode.beepAndAzan:
        await AzanAudioService.instance.playAzan();
        await NotificationService.instance.showSimpleNotification(
          title: 'Waktu Solat',
          body: 'Masuk waktu ' + _nextName,
        );
        break;
    }
  }

  Future<void> _saveSelection({
    required String state,
    required String zoneCode,
  }) async {
    final prefs = PrefsService.instance;
    await prefs.setString(_kLastState, state);
    await prefs.setString(_kLastZoneCode, zoneCode);
    await prefs.setBool(_kHasInitializedZone, true);
  }

  bool _forceSingleZone(String state) => _singleZoneStates.contains(state);

  Zone _pickDefaultZoneFor(String state, List<Zone> zones) {
    if (zones.isEmpty) return const Zone(code: '', name: '—');
    return zones.first;
  }

  Future<Position> _getPrecisePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception(
        'Location Services OFF.\n\nPergi Settings > Privacy & Security > Location Services dan ON.',
      );
    }

    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied) {
      throw Exception(
        'Permission lokasi ditolak.\n\nPergi Settings > MySolat > Location > While Using.',
      );
    }
    if (p == LocationPermission.deniedForever) {
      throw Exception(
        'Permission lokasi “Denied Forever”.\n\nPergi Settings > MySolat > Location dan benarkan semula.',
      );
    }

    Position? pos = await Geolocator.getLastKnownPosition();

    pos ??= await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: const Duration(seconds: 20),
    );

    if (pos.accuracy > 60) {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 20),
      );
    }

    return pos;
  }

  String _norm(String s) => s.trim().toLowerCase();

  String? _mapAdministrativeAreaToState(String? admin) {
    if (admin == null || admin.trim().isEmpty) return null;
    final a = _norm(admin);

    if (a == 'penang' || a.contains('penang')) return 'Pulau Pinang';
    if (a.contains('pulau pinang')) return 'Pulau Pinang';

    if (a.contains('kuala lumpur') ||
        a.contains('putrajaya') ||
        a.contains('labuan') ||
        a.contains('wilayah persekutuan') ||
        a.contains('federal territory')) {
      return 'Wilayah Persekutuan';
    }

    const states = <String>[
      'Selangor',
      'Perlis',
      'Kedah',
      'Perak',
      'Melaka',
      'Negeri Sembilan',
      'Johor',
      'Pahang',
      'Terengganu',
      'Kelantan',
      'Sabah',
      'Sarawak',
    ];

    for (final s in states) {
      if (a == _norm(s) || a.contains(_norm(s))) return s;
    }

    for (final s in _stateList) {
      if (_norm(s) == a) return s;
    }

    return null;
  }

  Zone? _pickZoneByDistrictHeuristic({
    required String state,
    required List<Zone> zones,
    String? district,
    String? subAdmin,
    String? locality,
  }) {
    if (zones.isEmpty) return null;

    if (_forceSingleZone(state)) {
      return zones.first;
    }

    final candidates = <String>[
      if (district != null) district,
      if (subAdmin != null) subAdmin,
      if (locality != null) locality,
    ].where((e) => e.trim().isNotEmpty).toList();

    if (candidates.isEmpty) return null;

    bool nameContains(String zoneName, String token) {
      final z = _norm(zoneName);
      final t = _norm(token);
      if (t.length < 3) return false;
      return z.contains(t);
    }

    for (final cand in candidates) {
      final match = zones.where((z) => nameContains(z.name, cand)).toList();
      if (match.isNotEmpty) return match.first;

      final parts = cand
          .split(RegExp(r'[,/]|(\s+)'))
          .map((e) => e.trim())
          .where((e) => e.length >= 4)
          .toList();

      for (final p in parts) {
        final m = zones.where((z) => nameContains(z.name, p)).toList();
        if (m.isNotEmpty) return m.first;
      }
    }

    return null;
  }

  Future<({String state, Zone zone})> _detectZoneFromCurrentLocation() async {
    final pos = await _getPrecisePosition();
    final lat = pos.latitude;
    final lon = pos.longitude;

    List<Placemark> marks = const [];
    try {
      marks = await placemarkFromCoordinates(lat, lon);
    } catch (_) {
      throw Exception(
        'Lokasi berjaya dikesan, tetapi gagal baca nama negeri.\n\n'
            'Cuba lagi. Pastikan internet OK & Location “Precise” ON.',
      );
    }

    final pm = marks.isNotEmpty ? marks.first : null;

    final detectedState = _mapAdministrativeAreaToState(pm?.administrativeArea);
    if (detectedState == null || !_stateList.contains(detectedState)) {
      throw Exception(
        'Lokasi berjaya dikesan (±${pos.accuracy.toStringAsFixed(0)}m), tetapi sistem tidak dapat tentukan negeri.\n\n'
            'Tip: Pastikan “Precise Location” ON (Settings > MySolat > Location).',
      );
    }

    final zones = _zones.zonesIn(detectedState);
    if (zones.isEmpty) {
      throw Exception('Negeri dikesan: $detectedState, tetapi tiada zon dalam app.');
    }

    final picked = _pickZoneByDistrictHeuristic(
      state: detectedState,
      zones: zones,
      district: pm?.subAdministrativeArea,
      subAdmin: pm?.administrativeArea,
      locality: pm?.locality,
    );

    final finalZone = picked ?? _pickDefaultZoneFor(detectedState, zones);

    return (state: detectedState, zone: finalZone);
  }

  Future<void> _init() async {
    _today = DateTime.now();
    _gregDisplay = DateFormat('EEEE, d MMMM yyyy', 'ms_MY').format(_today);
    _hijriDisplay = _buildHijriDate(_today);

    _stateList = List<String>.from(_zones.states)..sort();

    final prefs = PrefsService.instance;
    final savedState = prefs.getString(_kLastState);
    final savedZoneCode = prefs.getString(_kLastZoneCode);
    final hasInitialized = prefs.getBool(_kHasInitializedZone) ?? false;

    if (savedState != null &&
        _stateList.contains(savedState) &&
        savedZoneCode != null &&
        savedZoneCode.isNotEmpty) {
      _selectedState = savedState;
      _zoneList = _zones.zonesIn(_selectedState!);
      _selectedZone = _zoneList.firstWhere(
            (z) => z.code == savedZoneCode,
        orElse: () => _pickDefaultZoneFor(_selectedState!, _zoneList),
      );
    } else {
      ({String state, Zone zone})? autoPick;
      if (!hasInitialized) {
        try {
          autoPick = await _detectZoneFromCurrentLocation();
        } catch (_) {
          autoPick = null;
        }
      }

      if (autoPick != null && _stateList.contains(autoPick.state)) {
        _selectedState = autoPick.state;
        _zoneList = _zones.zonesIn(_selectedState!);
        _selectedZone = _zoneList.firstWhere(
              (z) => z.code == autoPick!.zone.code,
          orElse: () => _pickDefaultZoneFor(_selectedState!, _zoneList),
        );
      } else {
        final fallbackState = _stateList.contains('Pulau Pinang')
            ? 'Pulau Pinang'
            : (_stateList.isNotEmpty ? _stateList.first : null);

        _selectedState = fallbackState;
        if (_selectedState != null) {
          _zoneList = _zones.zonesIn(_selectedState!);
          _selectedZone = _pickDefaultZoneFor(_selectedState!, _zoneList);
        }
      }

      if (_selectedState != null &&
          _selectedZone != null &&
          _selectedZone!.code.isNotEmpty) {
        await _saveSelection(
          state: _selectedState!,
          zoneCode: _selectedZone!.code,
        );
      } else {
        await prefs.setBool(_kHasInitializedZone, true);
      }
    }

    if (!mounted) return;
    setState(() => _booting = false);

    await _load();
  }

  Future<void> _applyStateChange(String newState) async {
    _selectedState = newState;
    _zoneList = _zones.zonesIn(_selectedState!);

    if (_selectedZone != null &&
        !_zoneList.any((z) => z.code == _selectedZone!.code)) {
      _selectedZone = null;
    }

    _selectedZone ??= _pickDefaultZoneFor(_selectedState!, _zoneList);

    if (mounted) setState(() {});
    if (_selectedZone != null && _selectedZone!.code.isNotEmpty) {
      await _saveSelection(
        state: _selectedState!,
        zoneCode: _selectedZone!.code,
      );
    }
    await _load();
  }

  Future<void> _applyZoneChange(Zone newZone) async {
    _selectedZone = newZone;
    if (mounted) setState(() {});
    await _saveSelection(
      state: _selectedState!,
      zoneCode: _selectedZone!.code,
    );
    await _load();
  }

  Future<void> _useCurrentLocationNow() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final autoPick = await _detectZoneFromCurrentLocation();

      _selectedState = autoPick.state;
      _zoneList = _zones.zonesIn(_selectedState!);
      _selectedZone = _zoneList.firstWhere(
            (z) => z.code == autoPick.zone.code,
        orElse: () => _pickDefaultZoneFor(_selectedState!, _zoneList),
      );

      await _saveSelection(
        state: _selectedState!,
        zoneCode: _selectedZone!.code,
      );
      if (!mounted) return;

      setState(() {});
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    if (_selectedZone == null || _selectedZone!.code.isEmpty) return;

    final zoneCode = _selectedZone!.code;
    final today = DateTime.now();
    PrayerTimes? cached;

    try {
      cached = await _service.readCachedDay(zoneCode, today);
      if (cached != null && mounted) {
        setState(() {
          _times = cached;
          _error = null;
        });
        _computeNextPrayer();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result = await _service.fetchDay(zoneCode, today);
      if (!mounted) return;
      setState(() {
        _times = result;
        _error = null;
      });
      _computeNextPrayer();
      if (_selectedZone != null) {
        await NotificationService.instance.schedulePrayerNotifications(
          subuh: result.subuh,
          zohor: result.zohor,
          asar: result.asar,
          maghrib: result.maghrib,
          isyak: result.isyak,
          zoneName: _selectedZone!.name,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (cached != null || _times != null) {
        setState(() { _error = null; });
      } else {
        setState(() { _error = e.toString(); });
      }
    } finally {
      if (mounted) {
        setState(() { _loading = false; });
      }
    }
  }

    void _computeNextPrayer() {
    final pt = _times;
    if (pt == null) return;

    final now = DateTime.now();
    final List<(String, DateTime)> list = [];

    void add(String name, String raw) {
      final d = _parseToday(raw);
      if (d != null) list.add((name, d));
    }

    add('Subuh', pt.subuh);
    add('Syuruk', pt.syuruk);
    add('Zohor', pt.zohor);
    add('Asar', pt.asar);
    add('Maghrib', pt.maghrib);
    add('Isyak', pt.isyak);

    list.sort((a, b) => a.$2.compareTo(b.$2));

    (String, DateTime)? next =
    list.firstWhere((e) => e.$2.isAfter(now), orElse: () => ('', now));

    if (next.$1.isEmpty) {
      final fajr = _parseToday(pt.subuh);
      if (fajr != null) {
        next = ('Subuh', fajr.add(const Duration(days: 1)));
      } else {
        next = null;
      }
    }

    if (!mounted) return;

    if (next == null) {
      setState(() {
        _nextName = '';
        _nextAt = null;
        _countdownNotifier.value = '—';
      });
    } else {
      setState(() {
        _nextName = next!.$1;
        _nextAt = next!.$2;
        _countdownNotifier.value = _formatCountdown(next!.$2, now);
      });
    }
  }

  void _tick() {
    if (!mounted) return;

    final now = DateTime.now();
    final dayChanged = now.year != _lastTickDay.year ||
        now.month != _lastTickDay.month ||
        now.day != _lastTickDay.day;

    if (dayChanged) {
      _lastTickDay = now;
      _today = now;
      _gregDisplay = DateFormat('EEEE, d MMMM yyyy', 'ms_MY').format(_today);
      _hijriDisplay = _buildHijriDate(_today);
      _load();
      _computeNextPrayer();
      return;
    }

    final target = _nextAt;

    if (target == null) {
      if (_times != null) _computeNextPrayer();
      return;
    }

    final secondsLeft = target.difference(now).inSeconds;

    if (secondsLeft <= 0) {
      _playPrayerSound();
      _computeNextPrayer();

      final newTarget = _nextAt;
      if (newTarget != null) {
        setState(() {
          _countdownNotifier.value = _formatCountdown(target, now);
        });
      }
      return;
    }

    _countdownNotifier.value = _formatCountdown(target, now);
  }

  static const int _hijriOffsetDays = -1;

  String _buildHijriDate(DateTime date) {
    final adjusted = date.add(const Duration(days: _hijriOffsetDays));
    final hijri = HijriDateTime.fromGregorian(adjusted);

    const monthNames = <String>[
      '',
      'Muharam',
      'Safar',
      'Rabiulawal',
      'Rabiulakhir',
      'Jamadilawal',
      'Jamadilakhir',
      'Rejab',
      'Syaaban',
      'Ramadan',
      'Syawal',
      'Zulkaedah',
      'Zulhijjah',
    ];

    final monthName =
    (hijri.month >= 1 && hijri.month <= 12) ? monthNames[hijri.month] : '';

    return '${hijri.day} $monthName ${hijri.year}';
  }

  DateTime? _parseToday(String s) {
    const fmts = ['HH:mm:ss', 'HH:mm', 'h:mm a', 'h:mm:ss a', 'HH.mm.ss'];
    final now = DateTime.now();
    for (final f in fmts) {
      final df = DateFormat(f, 'en_US');
      try {
        final t = df.parseLoose(s);
        return DateTime(
          now.year,
          now.month,
          now.day,
          t.hour,
          t.minute,
          t.second,
        );
      } catch (_) {}
    }
    return null;
  }

  String _formatTime(String raw) {
    final d = _parseToday(raw);
    if (d == null) return '—';
    return DateFormat('h:mm a', 'en_US').format(d);
  }

  String _formatCountdown(DateTime target, DateTime now) {
    int total = target.difference(now).inSeconds;
    if (total < 0) total = 0;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openStatePicker() async {
    if (_stateList.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet<String>(
        title: 'Pilih Negeri',
        items: _stateList,
        selected: _selectedState,
        itemLabel: (s) => s,
      ),
    );

    if (picked == null) return;
    if (picked == _selectedState) return;
    await _applyStateChange(picked);
  }


  Future<void> _openZonePicker() async {
    if (_zoneList.isEmpty) return;

    final picked = await showModalBottomSheet<Zone>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PickerSheet<Zone>(
        title: 'Pilih Bandar / Zon',
        items: _zoneList,
        selected: _selectedZone,
        itemLabel: (z) => z.name,
      ),
    );

    if (picked == null) return;
    if (picked.code == _selectedZone?.code) return;
    await _applyZoneChange(picked);
  }

  String _zoneDisplayName() {
    if (_selectedZone == null) return 'Tekan untuk pilih bandar';

    final full = _selectedZone!.name.trim();

    if (full.toLowerCase().startsWith('seluruh negeri')) {
      return 'Seluruh Negeri';
    }

    final cities = full
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cities.isEmpty) return full;

    final firstCity = cities.first;

    if (cities.length >= 4 || full.length > 45) {
      return '$firstCity dan kawasan sewaktu dengannya';
    }

    return full;
  }

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.05);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(ts)),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _booting
              ? const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_primary),
            ),
          )
              : Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 2),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Waktu Solat',
                      style: const TextStyle(
                        fontSize: _titleSize,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: _primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _gregDisplay,
                      style: const TextStyle(
                        fontSize: _dateSize,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _hijriDisplay,
                      style: TextStyle(
                        fontSize: _dateSize,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: _primary.withOpacity(0.78),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _labelPillRow(
                  label: 'NEGERI',
                  child: _buildStatePill(),
                ),
                const SizedBox(height: 8),
                _labelPillRow(
                  label: 'BANDAR',
                  child: _buildZonePill(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _loading ? null : _useCurrentLocationNow,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _softShadow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 22,
                                color: _loading
                                    ? Colors.white54
                                    : Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _loading
                                    ? 'Mencari zon solat...'
                                    : 'Cari Zon Solat Saya',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _loading
                                      ? Colors.white54
                                      : Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (!_loading) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ],
                              if (_loading) ...[
                                const SizedBox(width: 10),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white54,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_nextAt != null && _nextName.isNotEmpty)
                  _buildNextBannerIOS(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _ErrorCard(message: _error!, onRetry: _load),
                ],
                if (_loading && _error == null) ...[
                  const SizedBox(height: 6),
                  const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(_primary),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildPrayerList()),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Sumber: Portal e-Solat JAKIM',
                              style: TextStyle(
                                fontSize: _sourceSize,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                color: _primary.withOpacity(0.70),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _labelPillRow({required String label, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 4,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: _labelSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: _primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 9, child: child),
      ],
    );
  }

  Widget _buildStatePill() {
    final selected =
        _selectedState ?? (_stateList.isNotEmpty ? _stateList.first : '—');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openStatePicker,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: _softShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: _pillTextSize,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down, color: _primary.withOpacity(0.85)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZonePill() {
    final currentState = _selectedState;
    final displayName = _zoneDisplayName();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: currentState == null || _zoneList.isEmpty ? null : _openZonePicker,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: _softShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: _selectedZone == null ? _muted : _primary,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down, color: _primary.withOpacity(0.85)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextBannerIOS() {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 42,
      decoration: BoxDecoration(
        color: _rowHighlight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _rowHighlightBorder, width: 1),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
              color: _gold,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _nextName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: _bannerTextSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            flex: 3,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'lagi...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primary,
                    fontSize: _bannerTextSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 7,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<String>(
                  valueListenable: _countdownNotifier,
                  builder: (_, val, __) => Text(
                    val,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPrayerList() {
    final pt = _times;

    final items = <(String, String?)>[
      ('Subuh', pt?.subuh),
      ('Syuruk', pt?.syuruk),
      ('Zohor', pt?.zohor),
      ('Asar', pt?.asar),
      ('Maghrib', pt?.maghrib),
      ('Isyak', pt?.isyak),
    ];

    return Column(

    mainAxisAlignment: MainAxisAlignment.start,
      children: items.map((item) {
        final label = item.$1;
        final raw = item.$2;
        final highlight = (label == _nextName);

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: SizedBox(
            height: 42,
            child: _timeRowIOS(label, raw, highlight),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeRowIOS(String label, String? raw, bool highlight) {
    final timeStr = raw == null ? '—' : _formatTime(raw);

    String mainPart = timeStr;
    String? ampm;
    if (timeStr.endsWith('AM') || timeStr.endsWith('PM')) {
      ampm = timeStr.substring(timeStr.length - 2);
      mainPart = timeStr.substring(0, timeStr.length - 2).trimRight();
    }

    return Container(
      decoration: BoxDecoration(
        color: highlight ? _rowHighlight : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight ? _rowHighlightBorder : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: highlight ? _gold : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: _rowLabelSize,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: _primary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: mainPart,
                        style: const TextStyle(
                          fontSize: _rowTimeSize,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: _primary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (ampm != null) ...[
                        const WidgetSpan(child: SizedBox(width: 4)),
                        TextSpan(
                          text: ampm,
                          style: TextStyle(
                            fontSize: _ampmSize,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            color: highlight ? _gold : _primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T item) itemLabel;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.itemLabel,
  });

  bool _isSame(T a, T? b) {
    if (b == null) return false;
    return a == b;
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1F5E3E);
    const surface = Color(0xFFF7FBF8);
    const border = Color(0xFFD2E2D7);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _isSame(item, selected);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFDDEFE4)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF9FC9B4)
                                  : border,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  itemLabel(item),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: primary,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    const dangerBg = Color(0xFFFFEAEA);
    const dangerText = Color(0xFFB42318);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF7B6B0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: dangerText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: dangerText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text(
              'Cuba Lagi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}