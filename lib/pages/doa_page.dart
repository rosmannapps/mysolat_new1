import 'package:flutter/material.dart';

// If you already have a central theme file, keep this import.
// If the path differs in your project, adjust accordingly.
import '../theme/app_theme.dart';

class DoaPage extends StatelessWidget {
  const DoaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-driven surfaces
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = cs.surface;

    // Premium accent (matches your icon / emerald+gold vibe)
    final emerald = AppTheme.primary;
    final gold = const Color(0xFFD6B35B);

    // Simple grid menu for Doa categories
    final items = <_DoaMenuItem>[
      _DoaMenuItem(icon: Icons.wb_sunny_outlined, title: 'Pagi & Petang'),
      _DoaMenuItem(icon: Icons.nights_stay_outlined, title: 'Sebelum Tidur'),
      _DoaMenuItem(icon: Icons.mosque_outlined, title: 'Masuk/ Keluar Rumah'),
      _DoaMenuItem(icon: Icons.restaurant_outlined, title: 'Makan & Minum'),
      _DoaMenuItem(icon: Icons.directions_car_outlined, title: 'Musafir'),
      _DoaMenuItem(icon: Icons.favorite_border, title: 'Kesihatan'),
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Doa'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small “exclusive” header line
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: gold.withOpacity(isDark ? 0.85 : 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pilih kategori doa',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withOpacity(isDark ? 0.80 : 0.70),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: GridView.builder(
                  itemCount: items.length,
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.12,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _DoaTile(
                      icon: item.icon,
                      title: item.title,
                      emerald: emerald,
                      gold: gold,
                      cardColor: card,
                      onTap: () {
                        // TODO: navigate to doa list / category
                        // Example:
                        // Navigator.push(context, MaterialPageRoute(
                        //   builder: (_) => DoaListPage(category: item.title),
                        // ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Open: ${item.title}')),
                        );
                      },
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

class _DoaMenuItem {
  final IconData icon;
  final String title;
  const _DoaMenuItem({required this.icon, required this.title});
}

class _DoaTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  final Color emerald;
  final Color gold;
  final Color cardColor;

  const _DoaTile({
    required this.icon,
    required this.title,
    required this.emerald,
    required this.gold,
    required this.cardColor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final border = isDark
        ? cs.outline.withOpacity(0.28)
        : cs.outlineVariant.withOpacity(0.55);

    final shadow = isDark
        ? Colors.black.withOpacity(0.55)
        : Colors.black.withOpacity(0.10);

    final iconBg = isDark
        ? emerald.withOpacity(0.18)
        : AppTheme.primarySoft; // soft mint from your theme

    final iconColor = emerald;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + gold dot (premium accent)
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: gold.withOpacity(isDark ? 0.30 : 0.25),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 24, color: iconColor),
                    ),
                    const Spacer(),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: gold.withOpacity(isDark ? 0.85 : 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),

                // Small helper line for polish (optional)
                Text(
                  'Buka',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withOpacity(isDark ? 0.55 : 0.45),
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