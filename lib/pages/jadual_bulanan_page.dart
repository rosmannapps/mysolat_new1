// lib/pages/jadual_bulanan_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../zones/zone_store.dart';
import '../services/prayer_times_service.dart';
import 'jadual_bulanan_table_page.dart';

const _bgBlue = Color(0xFFEFF4FF);
const _primaryBlue = Color(0xFF2563EB);
const _labelBlue = Color(0xFF123369);

class JadualBulananPage extends StatefulWidget {
  const JadualBulananPage({super.key});

  @override
  State<JadualBulananPage> createState() => _JadualBulananPageState();
}

class _JadualBulananPageState extends State<JadualBulananPage> {
  final _zones = ZoneStore();                // use your existing ZoneStore
  final _service = PrayerTimesService();

  late final List<String> _stateList;
  late List<Zone> _zoneList;

  String _selectedState = '';
  Zone? _selectedZone;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  bool _loading = false;
  String? _error;

  static const _wholeStateOnly = <String>{
    'Wilayah Persekutuan',
    'Melaka',
    'Perlis',
    'Pulau Pinang',
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _bootstrap() {
    _stateList = List<String>.from(_zones.states)..sort();

    _selectedState =
    _stateList.contains('Pulau Pinang') ? 'Pulau Pinang' : _stateList.first;

    _rebuildZonesForState();
  }

  bool _forceWholeState(String state) => _wholeStateOnly.contains(state);

  void _rebuildZonesForState() {
    _zoneList = _zones.zonesIn(_selectedState);

    if (_selectedZone != null &&
        !_zoneList.any((z) => z.code == _selectedZone!.code)) {
      _selectedZone = null;
    }

    if (_selectedZone == null) {
      if (_forceWholeState(_selectedState)) {
        _selectedZone = _zoneList.firstWhere(
              (z) => z.name.contains('Seluruh Negeri'),
          orElse: () => _zoneList.first,
        );
      } else {
        _selectedZone = _zoneList.first;
      }
    }

    setState(() {});
  }

  List<int> get _yearOptions {
    final nowYear = DateTime.now().year;
    return List<int>.generate(7, (i) => nowYear - 2 + i);
  }

  Future<void> _generate() async {
    if (_selectedZone == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _service.fetchMonth(
        zoneCode: _selectedZone!.code,
        month: _selectedMonth,
        year: _selectedYear,
      );

      if (!mounted) return;

      if (entries.isEmpty) {
        setState(() {
          _error = 'Tiada data jadual solat untuk pilihan ini.';
        });
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JadualBulananTablePage(
            stateName: _selectedState,
            zoneName: _selectedZone!.name,
            month: _selectedMonth,
            year: _selectedYear,
            entries: entries,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlue,
      appBar: AppBar(
        backgroundColor: _bgBlue,
        foregroundColor: _labelBlue,
        elevation: 0,
        title: const Text(
          'Tetapan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _labelBlue,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Jadual Solat Bulanan',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(height: 28),

              _sectionLabel('NEGERI'),
              const SizedBox(height: 8),
              _buildStateDropdown(),
              const SizedBox(height: 20),

              _sectionLabel('BANDAR'),
              const SizedBox(height: 8),
              _buildZoneDropdown(),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('BULAN'),
                        const SizedBox(height: 8),
                        _buildMonthDropdown(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('TAHUN'),
                        const SizedBox(height: 8),
                        _buildYearDropdown(),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart_rounded, size: 22),
                  label: const Text(
                    'Jana Jadual',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _loading ? null : _generate,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(_primaryBlue),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: _labelBlue,
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedState,
          borderRadius: BorderRadius.circular(16),
          iconEnabledColor: _primaryBlue,
          items: _stateList
              .map(
                (s) => DropdownMenuItem<String>(
              value: s,
              child: Text(
                s,
                style: const TextStyle(
                  fontSize: 18,
                  color: _labelBlue,
                ),
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value == null || value == _selectedState) return;
            setState(() {
              _selectedState = value;
            });
            _rebuildZonesForState();
          },
        ),
      ),
    );
  }

  Widget _buildZoneDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Zone>(
          isExpanded: true,
          value: _selectedZone,
          borderRadius: BorderRadius.circular(16),
          iconEnabledColor: _primaryBlue,
          items: _zoneList
              .map(
                (z) => DropdownMenuItem<Zone>(
              value: z,
              child: Text(
                z.name,
                style: const TextStyle(
                  fontSize: 18,
                  color: _labelBlue,
                ),
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value == null || value.code == _selectedZone?.code) return;
            setState(() {
              _selectedZone = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMonthDropdown() {
    final months = List<int>.generate(12, (i) => i + 1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedMonth,
          iconEnabledColor: _primaryBlue,
          borderRadius: BorderRadius.circular(16),
          items: months
              .map(
                (m) => DropdownMenuItem<int>(
              value: m,
              child: Text(
                DateFormat('LLLL', 'ms_MY')
                    .format(DateTime(_selectedYear, m, 1)),
                style: const TextStyle(
                  fontSize: 18,
                  color: _labelBlue,
                ),
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value == null || value == _selectedMonth) return;
            setState(() {
              _selectedMonth = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedYear,
          iconEnabledColor: _primaryBlue,
          borderRadius: BorderRadius.circular(16),
          items: _yearOptions
              .map(
                (y) => DropdownMenuItem<int>(
              value: y,
              child: Text(
                y.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  color: _labelBlue,
                ),
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value == null || value == _selectedYear) return;
            setState(() {
              _selectedYear = value;
            });
          },
        ),
      ),
    );
  }
}