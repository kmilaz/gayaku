import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../navigation.dart';
import '../state/outfit_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/placeholder_image.dart';
import 'outfit_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const filters = ['All', 'Casual', 'Office'];
  var selectedFilter = 'All';
  var selectedSort = LookSortOption.newest;

  /// The combinations the user starred, rendered with the look cards. Empty
  /// until something is saved: there is no demo shelf any more.
  List<Look> get savedLooks => [
    for (final outfit in savedOutfits.value)
      if (outfit.favorite) lookFromOutfit(outfit, wardrobeItems.value),
  ];

  @override
  void initState() {
    super.initState();
    savedOutfits.addListener(_refresh);
    wardrobeItems.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    savedOutfits.removeListener(_refresh);
    wardrobeItems.removeListener(_refresh);
    super.dispose();
  }

  List<Look> get visibleLooks {
    final filtered = selectedFilter == 'All'
        ? [...savedLooks]
        : savedLooks.where((look) => look.styleTag == selectedFilter).toList();
    filtered.sort(
      (a, b) => switch (selectedSort) {
        LookSortOption.newest => (b.savedAt ?? DateTime(0)).compareTo(
          a.savedAt ?? DateTime(0),
        ),
        LookSortOption.oldest => (a.savedAt ?? DateTime(0)).compareTo(
          b.savedAt ?? DateTime(0),
        ),
        LookSortOption.titleAscending => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        LookSortOption.titleDescending => b.title.toLowerCase().compareTo(
          a.title.toLowerCase(),
        ),
      },
    );
    return filtered;
  }

  String get selectedSortLabel => switch (selectedSort) {
    LookSortOption.newest => 'Newest',
    LookSortOption.oldest => 'Oldest',
    LookSortOption.titleAscending => 'A-Z',
    LookSortOption.titleDescending => 'Z-A',
  };

  Future<void> removeFavorite(Look look) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${look.title} removed from favorites'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    try {
      await toggleOutfitFavorite(look.id);
    } on OutfitException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> openLook(Look look) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => OutfitDetailScreen(look: look)),
    );
  }

  void showSortOptions() {
    final palette = AppColors.of(context);
    showModalBottomSheet<LookSortOption>(
      context: context,
      backgroundColor: palette.sheet,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort Favorite Looks',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                height: 30 / 24,
                fontWeight: FontWeight.bold,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 14),
            const _SortSectionLabel(label: 'Saved time'),
            _SortOptionTile(
              label: 'Newest first',
              icon: Icons.schedule,
              selected: selectedSort == LookSortOption.newest,
              onTap: () =>
                  Navigator.of(sheetContext).pop(LookSortOption.newest),
            ),
            _SortOptionTile(
              label: 'Oldest first',
              icon: Icons.history,
              selected: selectedSort == LookSortOption.oldest,
              onTap: () =>
                  Navigator.of(sheetContext).pop(LookSortOption.oldest),
            ),
            const SizedBox(height: 8),
            const _SortSectionLabel(label: 'Title'),
            _SortOptionTile(
              label: 'A-Z',
              icon: Icons.sort_by_alpha,
              selected: selectedSort == LookSortOption.titleAscending,
              onTap: () =>
                  Navigator.of(sheetContext).pop(LookSortOption.titleAscending),
            ),
            _SortOptionTile(
              label: 'Z-A',
              icon: Icons.sort_by_alpha,
              selected: selectedSort == LookSortOption.titleDescending,
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(LookSortOption.titleDescending),
            ),
          ],
        ),
      ),
    ).then((sort) {
      if (sort != null && mounted) setState(() => selectedSort = sort);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final looks = visibleLooks;
    return Scaffold(
      backgroundColor: palette.sheet,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Favorite Looks',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 20,
                                height: 26 / 20,
                                fontWeight: FontWeight.bold,
                                color: palette.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${looks.length} looks',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 15 / 11,
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _FilterBar(
                        selectedFilter: selectedFilter,
                        onFilterChanged: (filter) =>
                            setState(() => selectedFilter = filter),
                        selectedSortLabel: selectedSortLabel,
                        onSortTap: showSortOptions,
                      ),
                    ),
                  ),
                  if (looks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyLooks(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      sliver: SliverList.builder(
                        itemCount: looks.length,
                        itemBuilder: (context, index) {
                          final look = looks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _LookCard(
                              look: look,
                              onTap: () => openLook(look),
                              onFavoriteTap: () => removeFavorite(look),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(
                currentIndex: 0,
                onTap: (index) => openNavDestination(context, index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.selectedSortLabel,
    required this.onSortTap,
  });

  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final String selectedSortLabel;
  final VoidCallback onSortTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _FavoritesScreenState.filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: selectedFilter == filter,
                onSelected: (_) => onFilterChanged(filter),
                selectedColor: palette.action,
                backgroundColor: palette.sheet,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w600,
                  color: selectedFilter == filter
                      ? palette.onAction
                      : palette.ink,
                ),
                side: BorderSide.none,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          IconButton(
            onPressed: onSortTap,
            tooltip: 'Sort favorites',
            icon: const Icon(Icons.tune, size: 22),
            color: palette.ink,
            style: IconButton.styleFrom(backgroundColor: palette.sheet),
          ),
          const SizedBox(width: 6),
          Text(
            selectedSortLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 15 / 11,
              fontWeight: FontWeight.w600,
              color: palette.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortSectionLabel extends StatelessWidget {
  const _SortSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          height: 15 / 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: palette.inkMuted,
        ),
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: selected ? palette.sheet : palette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: selected ? palette.sheet : palette.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, size: 22, color: palette.accentInk),
          title: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 23 / 16,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 22,
            color: selected ? palette.accentInk : palette.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({
    required this.look,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Look look;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: palette.sheet,
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          boxShadow: const [AppDecorations.cardShadow],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlaceholderImage(
                    imagePath: look.imagePath,
                    icon: Icons.checkroom,
                    color: palette.surfaceMuted,
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _Tag(label: look.styleTag),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      onPressed: onFavoriteTap,
                      tooltip: 'Remove favorite',
                      icon: const Icon(Icons.favorite, size: 22),
                      color: palette.accentInk,
                      style: IconButton.styleFrom(
                        backgroundColor: palette.sheet,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Text(
                      look.subtitle,
                      style: GoogleFonts.inter(
                        color: palette.onAction,
                        fontSize: 11,
                        height: 15 / 11,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: palette.canvas, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 17),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      look.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 20,
                        height: 26 / 20,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${look.colorHarmony}% match',
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
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.sheet.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          height: 15 / 11,
          fontWeight: FontWeight.w600,
          color: palette.ink,
        ),
      ),
    );
  }
}

class _EmptyLooks extends StatelessWidget {
  const _EmptyLooks();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 28, color: palette.accentInk),
            const SizedBox(height: 14),
            Text(
              'No favorite looks yet',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 20,
                height: 26 / 20,
                fontWeight: FontWeight.bold,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Save a complete outfit recommendation to see it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 23 / 16,
                color: palette.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
