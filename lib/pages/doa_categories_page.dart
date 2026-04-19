import 'package:flutter/material.dart';
import 'doa_detail_page.dart';
import '../theme/app_theme.dart';

class DoaCategoriesPage extends StatelessWidget {
  const DoaCategoriesPage({super.key});

  static const List<_DoaCategory> _categories = <_DoaCategory>[
    _DoaCategory(
      title: 'Doa Harian',
      icon: Icons.menu_book_rounded,
      assetPath: 'assets/doa/doa_harian.json',
    ),
    _DoaCategory(
      title: 'Doa Perlindungan',
      icon: Icons.shield_rounded,
      assetPath: 'assets/doa/doa_perlindungan.json',
    ),
    _DoaCategory(
      title: 'Doa Kesembuhan',
      icon: Icons.medical_services_rounded,
      assetPath: 'assets/doa/doa_kesembuhan.json',
    ),
    _DoaCategory(
      title: 'Doa Musafir',
      icon: Icons.directions_car_filled_rounded,
      assetPath: 'assets/doa/doa_musafir.json',
    ),
    _DoaCategory(
      title: 'Doa Ramadan',
      icon: Icons.nights_stay_rounded,
      assetPath: 'assets/doa/doa_ramadan.json',
    ),
    _DoaCategory(
      title: 'Doa Haji & Umrah',
      icon: Icons.directions_walk_rounded,
      assetPath: 'assets/doa/doa_haji_umrah.json',
    ),
    _DoaCategory(
      title: 'Doa Ruqyah',
      icon: Icons.auto_fix_high_rounded,
      assetPath: 'assets/doa/doa_ruqyah.json',
    ),
    _DoaCategory(
      title: 'Doa Terapi Jiwa',
      icon: Icons.favorite_rounded,
      assetPath: 'assets/doa/doa_terapi_jiwa.json',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Normalise text size a bit smaller on this page
    final mq = MediaQuery.of(context);
    final fixedMq = mq.copyWith(textScaleFactor: 0.9);

    return MediaQuery(
      data: fixedMq,
      child: Scaffold(
        backgroundColor: AppTheme.bgOf(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Doa',
                  style: TextStyle(
                    fontSize: 36,            // a bit smaller than 40
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                // 4 rows that fit nicely on screen (no scroll)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const int crossAxisCount = 2;
                      const int rows = 4;
                      const double mainAxisSpacing = 18;
                      const double crossAxisSpacing = 18;

                      final double totalVerticalSpacing =
                          mainAxisSpacing * (rows - 1);
                      final double totalHorizontalSpacing =
                          crossAxisSpacing * (crossAxisCount - 1);

                      final double itemWidth = (constraints.maxWidth -
                          totalHorizontalSpacing) /
                          crossAxisCount;

                      final double itemHeight =
                          (constraints.maxHeight - totalVerticalSpacing) / rows;

                      final double aspectRatio = itemWidth / itemHeight;

                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _categories.length,
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: mainAxisSpacing,
                          crossAxisSpacing: crossAxisSpacing,
                          childAspectRatio: aspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          final c = _categories[index];
                          return _DoaCategoryCard(category: c);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoaCategory {
  final String title;
  final IconData icon;
  final String assetPath;

  const _DoaCategory({
    required this.title,
    required this.icon,
    required this.assetPath,
  });
}

class _DoaCategoryCard extends StatelessWidget {
  final _DoaCategory category;

  const _DoaCategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final Color activeIcon = AppTheme.primaryOf(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DoaDetailPage(
              categoryTitle: category.title,
              assetPath: category.assetPath,
            ),
          ),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          // slightly tighter vertical padding to fit 4 rows
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Smaller icon in smaller rounded square
              Container(
                height: 52,                 // was 64
                width: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  category.icon,
                  color: activeIcon,
                  size: 26,                // was 34
                ),
              ),
              const SizedBox(height: 10),   // was 18
              // Title, centered, up to 2 lines, smaller font
              Text(
                category.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,            // was 20
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}