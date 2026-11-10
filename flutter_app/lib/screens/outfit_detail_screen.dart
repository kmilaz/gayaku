import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import '../widgets/placeholder_image.dart';

class OutfitDetailScreen extends StatefulWidget {
  const OutfitDetailScreen({super.key, required this.look});

  final Look look;

  @override
  State<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends State<OutfitDetailScreen> {
  late bool _isFavorite = true;
  var _selectedItem = 0;

  Look get look => widget.look;

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
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.sheet,
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
                      icon: const Icon(Icons.arrow_back, size: 22),
                      color: palette.ink,
                      style: IconButton.styleFrom(
                        backgroundColor: palette.sheet,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Outfit Detail',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 20,
                            height: 26 / 20,
                            fontWeight: FontWeight.bold,
                            color: palette.ink,
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
                        size: 22,
                      ),
                      color: palette.accentInk,
                      style: IconButton.styleFrom(
                        backgroundColor: palette.sheet,
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
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
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
                        fontSize: 11,
                        height: 15 / 11,
                        color: palette.inkMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      look.styleTag,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 15 / 11,
                        fontWeight: FontWeight.w600,
                        color: palette.actionInk,
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
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
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
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(
                          'Swap Item',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.ink,
                          side: BorderSide(color: palette.accentInk),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                        ),
                        label: Text(
                          _isFavorite ? 'Saved Look' : 'Save Look',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 18 / 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.action,
                          foregroundColor: palette.onAction,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
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

  final Look look;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(32)),
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlaceholderImage(
              imagePath: look.imagePath,
              icon: Icons.checkroom,
              color: palette.surfaceMuted,
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
                  color: palette.canvas.withValues(alpha: 0.78),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  look.styleTag,
                  style: GoogleFonts.inter(
                    color: palette.onAction,
                    fontSize: 11,
                    height: 15 / 11,
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
}

class _LookItems extends StatelessWidget {
  const _LookItems({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<LookItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 8,
              ),
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 62,
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selectedIndex == index
                              ? palette.accentInk
                              : palette.sheet,
                          width: selectedIndex == index ? 2 : 1,
                        ),
                      ),
                      child: PlaceholderImage(
                        imagePath: items[index].imagePath,
                        icon: _iconFor(items[index].icon),
                        color: palette.surfaceMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      items[index].type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 15 / 11,
                        color: selectedIndex == index
                            ? palette.ink
                            : palette.inkMuted,
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
  }

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
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.sheet,
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
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              const Spacer(),
              Text(
                '$score% Match',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  height: 15 / 11,
                  fontWeight: FontWeight.w600,
                  color: palette.actionInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: palette.surface,
              valueColor: AlwaysStoppedAnimation(palette.actionInk),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'The colors create a balanced neutral base with a warm accent.',
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 15 / 11,
              color: palette.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
