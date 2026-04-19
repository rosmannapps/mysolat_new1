// lib/pages/doa_list_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class DoaListPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const DoaListPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<DoaListPage> createState() => _DoaListPageState();
}

class _DoaListPageState extends State<DoaListPage> {
  late Future<List<_DoaItem>> _future;
  double _arabicFontSize = 32;
  double _translationFontSize = 16;

  @override
  void initState() {
    super.initState();
    _future = _loadDoa();
  }

  Future<List<_DoaItem>> _loadDoa() async {
    final raw = await rootBundle.loadString(widget.assetPath);
    final data = jsonDecode(raw);

    if (data is List) {
      return data
          .map<_DoaItem>(
            (e) => _DoaItem.fromJson(e as Map<String, dynamic>),
      )
          .toList();
    }
    return const <_DoaItem>[];
  }

  void _changeFontSize() async {
    // Simple bottom sheet to adjust font size (Aa button)
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Saiz Teks',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Laraskan saiz teks Arab dan terjemahan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Arab',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Slider(
                    min: 24,
                    max: 40,
                    divisions: 16,
                    value: _arabicFontSize,
                    label: _arabicFontSize.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _arabicFontSize = v),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Terjemahan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Slider(
                    min: 14,
                    max: 22,
                    divisions: 16,
                    value: _translationFontSize,
                    label: _translationFontSize.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _translationFontSize = v),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = theme.scaffoldBackgroundColor;
    final card = cs.surface;
    final border = cs.outlineVariant.withOpacity(isDark ? 0.55 : 0.65);

    final titleColor = cs.primary;
    final arabicColor = cs.primary;
    final translationColor = theme.textTheme.bodyLarge?.color ?? cs.onSurface;
    final referenceColor = (theme.textTheme.bodyMedium?.color ?? cs.onSurface)
        .withOpacity(isDark ? 0.72 : 0.65);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _changeFontSize,
            icon: const Icon(Icons.text_fields_rounded),
            tooltip: 'Saiz teks',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<_DoaItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Gagal memuatkan doa.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final list = snap.data ?? const <_DoaItem>[];
          if (list.isEmpty) {
            return const Center(child: Text('Tiada data doa.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final d = list[i];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.30 : 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.title != null && d.title!.isNotEmpty) ...[
                      Text(
                        d.title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (d.arabic != null && d.arabic!.isNotEmpty) ...[
                      Text(
                        d.arabic!,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: _arabicFontSize,
                          height: 1.6,
                          color: arabicColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (d.translation != null && d.translation!.isNotEmpty) ...[
                      Text(
                        d.translation!,
                        style: TextStyle(
                          fontSize: _translationFontSize,
                          height: 1.6,
                          color: translationColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (d.reference != null && d.reference!.isNotEmpty)
                      Text(
                        d.reference!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: referenceColor,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DoaItem {
  final int? id;
  final String? title;
  final String? arabic;
  final String? translation;
  final String? reference;

  const _DoaItem({
    this.id,
    this.title,
    this.arabic,
    this.translation,
    this.reference,
  });

  factory _DoaItem.fromJson(Map<String, dynamic> json) {
    return _DoaItem(
      id: json['id'] as int?,
      title: json['title']?.toString(),
      arabic: json['arabic']?.toString(),
      translation: json['translation']?.toString(),
      reference: json['reference']?.toString(),
    );
  }
}