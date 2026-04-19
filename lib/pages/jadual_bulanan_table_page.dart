// lib/pages/jadual_bulanan_table_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/monthly_prayer_entry.dart';

const _tableBg = Color(0xFFF4F6FB);
const _headerGrey = Color(0xFFE5E7EB);
const _textDark = Color(0xFF111827);
const _rowAlt = Color(0xFFF1F5F9); // alternating row colour

class JadualBulananTablePage extends StatelessWidget {
  final String stateName;
  final String zoneName;
  final int month;
  final int year;
  final List<MonthlyPrayerEntry> entries;

  const JadualBulananTablePage({
    super.key,
    required this.stateName,
    required this.zoneName,
    required this.month,
    required this.year,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final monthName =
    DateFormat('LLLL', 'ms_MY').format(DateTime(year, month, 1));

    // ✅ Dark-mode friendly colors (keep layout exactly the same)
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? cs.surface : _tableBg;
    final appBarBg = isDark ? cs.surface : Colors.white;
    final fg = isDark ? cs.onSurface : _textDark;

    final headerBg = isDark ? cs.surfaceVariant : _headerGrey;
    final headerText = isDark ? cs.onSurfaceVariant : _textDark;

    final rowEven = isDark ? cs.surface : Colors.white;
    final rowOdd = isDark
        ? cs.surfaceVariant.withOpacity(0.55)
        : _rowAlt;

    final cellText = isDark ? cs.onSurface : _textDark;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Jadual'),
        centerTitle: true,
        backgroundColor: appBarBg,
        foregroundColor: fg,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Nanti boleh tambah fungsi share PDF/CSV.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fungsi kongsi akan ditambah kemudian.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        // tighter padding (more rows visible, closer to iOS feel)
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$stateName  •  $zoneName  •  $monthName $year',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: fg,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all<Color>(headerBg),

                    // make header row shorter
                    headingRowHeight: 26,

                    headingTextStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: headerText,
                      height: 1.0,
                    ),

                    // ✅ ensure cell text is visible in dark mode
                    dataTextStyle: TextStyle(
                      fontSize: 11,
                      height: 1.0,
                      color: cellText,
                    ),

                    // tighter spacing so everything fits
                    columnSpacing: 8,
                    horizontalMargin: 6,

                    // tighter rows (more days visible)
                    dataRowMinHeight: 22,
                    dataRowMaxHeight: 22,

                    columns: const [
                      DataColumn(
                        label: SizedBox(
                          width: 40,
                          child: Text(
                            'Tarikh',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      DataColumn(label: Text('Subuh')),
                      DataColumn(label: Text('Syuruk')),
                      DataColumn(label: Text('Zohor')),
                      DataColumn(label: Text('Asar')),
                      DataColumn(
                        label: Expanded(
                          child: Text(
                            'Maghrib',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      DataColumn(label: Text('Isyak')),
                    ],
                    rows: List<DataRow>.generate(
                      entries.length,
                          (index) {
                        final e = entries[index];
                        final isEven = index.isEven;
                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color?>(
                                (states) => isEven ? rowEven : rowOdd,
                          ),
                          cells: [
                            DataCell(
                              Center(
                                child: Text(
                                  e.date.day.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                    color: cellText,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(_timeText(_formatTime(e.subuh), cellText)),
                            DataCell(_timeText(_formatTime(e.syuruk), cellText)),
                            DataCell(_timeText(_formatTime(e.zohor), cellText)),
                            DataCell(_timeText(_formatTime(e.asar), cellText)),
                            DataCell(
                              Center(
                                child: _timeText(_formatTime(e.maghrib), cellText),
                              ),
                            ),
                            DataCell(_timeText(_formatTime(e.isyak), cellText)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _timeText(String s, Color color) {
    return Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11, // smaller to match iOS density
        height: 1.0,
        color: color, // ✅ visible in dark mode
      ),
    );
  }

  static String _formatTime(String raw) {
    // cuba convert ke 12 jam, tapi kalau fail, pulangkan original
    final cleaned = raw.replaceAll('.', ':');
    final fmts = ['HH:mm:ss', 'HH:mm', 'H:mm', 'HH.mm.ss'];

    for (final f in fmts) {
      try {
        final t = DateFormat(f, 'en_US').parseLoose(cleaned);
        return DateFormat('h:mm', 'en_US').format(t);
      } catch (_) {
        // teruskan cuba format lain
      }
    }
    return raw;
  }
}