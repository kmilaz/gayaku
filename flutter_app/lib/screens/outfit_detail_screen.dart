import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/outfit_look.dart';
import '../theme/app_theme.dart';
import '../widgets/placeholder_image.dart';

class OutfitDetailScreen extends StatefulWidget {
  const OutfitDetailScreen({super.key, required this.look});

  final OutfitLook look;

  @override
  State<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends State<OutfitDetailScreen> {
  late bool _isFavorite = true;
  var _selectedItem = 0;

  OutfitLook get look => widget.look;

  void _swapItem() {
    setState(() {
      _selectedItem = (_selectedItem + 1) % look.items.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing another ${look.items[_selectedItem].type}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Look saved to favorites' : 'Look removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.espresso,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.white,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Outfit Detail',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.espresso,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleFavorite,
                      tooltip: _isFavorite
                          ? 'Remove favorite'
                          : 'Save favorite',
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      color: AppColors.tan,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _HeroLook(look: look)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  look.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.espresso,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      look.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.taupe,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      look.styleTag,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Items in this Look',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.espresso,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _LookItems(
                  items: look.items,
                  selectedIndex: _selectedItem,
                  onSelected: (index) => setState(() => _selectedItem = index),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _ColorHarmony(score: look.colorHarmony),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _swapItem,
                        icon: const Icon(Icons.sync),
                        label: const Text('Swap Item'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.espresso,
                          side: const BorderSide(color: AppColors.tan),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _toggleFavorite,
                        icon: Icon(_isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border),
                        label: Text(_isFavorite ? 'Saved Look' : 'Save Look'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.tan,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroLook extends StatelessWidget {
  const _HeroLook({required this.look});

  final OutfitLook look;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PlaceholderImage(
                imagePath: look.imagePath,
                icon: Icons.checkroom,
                color: AppColors.imageSurface,
              ),
              Positioned(
                left: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.espresso.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    look.styleTag,
                    style: GoogleFonts.inter(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _LookItems extends StatelessWidget {
  const _LookItems({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<OutfitLookItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 8),
                child: GestureDetector(
                  onTap: () => onSelected(index),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 62,
                        decoration: BoxDecoration(
                          color: AppColors.imageSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selectedIndex == index
                                ? AppColors.tan
                                : AppColors.white,
                            width: selectedIndex == index ? 2 : 1,
                          ),
                        ),
                        child: PlaceholderImage(
                          imagePath: items[index].imagePath,
                          icon: _iconFor(items[index].icon),
                          color: AppColors.imageSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        items[index].type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: selectedIndex == index
                              ? AppColors.espresso
                              : AppColors.taupe,
                          fontWeight: selectedIndex == index
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  IconData _iconFor(String icon) => switch (icon) {
        'top' => Icons.checkroom,
        'bottom' => Icons.dry_cleaning,
        'shoes' => Icons.directions_run,
        _ => Icons.watch_outlined,
      };
}

class _ColorHarmony extends StatelessWidget {
  const _ColorHarmony({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [AppDecorations.panelShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Color Harmony',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.espresso,
                  ),
                ),
                const Spacer(),
                Text(
                  '$score% Match',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.tan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: AppColors.beige,
                valueColor: const AlwaysStoppedAnimation(AppColors.tan),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The colors create a balanced neutral base with a warm accent.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.taupe),
            ),
          ],
        ),
      );
}
