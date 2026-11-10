import 'package:flutter/material.dart';

import '../logic/outfit_matcher.dart';
import '../models/wardrobe.dart';
import '../navigation.dart';
import '../state/outfit_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/placeholder_image.dart';
import '../widgets/wardrobe_item_card.dart';
import 'outfit_builder_screen.dart';

/// Wardrobe hub with two tabs: the item catalog and the saved combinations.
///
/// The catalog is the SQLite-backed [wardrobeItems] store (docs/adr/0004);
/// search and filters stay local, and combinations are still session-only.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({
    super.key,
    this.items,
    this.initialTab = 0,
    this.initialFavoritesOnly = false,
  });

  /// Overrides the store with a fixed catalog, for tests. Null — the app's
  /// case — follows [wardrobeItems], so a scanned garment shows up here as
  /// soon as it is saved.
  final List<WardrobeItem>? items;
  final int initialTab;
  final bool initialFavoritesOnly;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final _search = TextEditingController();
  String _category = wardrobeCategories.first;
  String _query = '';
  Set<String> _occasions = {};
  int _minFormality = 1;
  late int _tab;
  late bool _favoritesOnly;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _favoritesOnly = widget.initialFavoritesOnly;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtering => _occasions.isNotEmpty || _minFormality > 1;

  Future<void> _openBuilder({SavedOutfit? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OutfitBuilderScreen(existing: existing, catalog: _catalog),
      ),
    );
  }

  /// The catalog in play: the injected override, else the live store.
  List<WardrobeItem> get _catalog => widget.items ?? wardrobeItems.value;

  /// Occasions present in the catalog, so the filter never offers a dead option.
  List<String> get _availableOccasions =>
      {for (final item in _catalog) ...item.occasions}.toList()..sort();

  Future<void> _openFilters() async {
    final result =
        await showModalBottomSheet<({Set<String> occasions, int minFormality})>(
          context: context,
          backgroundColor: AppColors.of(context).sheet,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
          builder: (context) => _FilterSheet(
            occasions: _availableOccasions,
            selected: _occasions,
            minFormality: _minFormality,
          ),
        );
    if (result == null) return;
    setState(() {
      _occasions = result.occasions;
      _minFormality = result.minFormality;
    });
  }

  Future<void> _confirmDelete(SavedOutfit outfit) async {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.sheet,
        title: Text(
          'Hapus kombinasi?',
          style: textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        content: Text(
          '"${outfit.name}" akan dihapus dari daftar.',
          style: textTheme.labelLarge!.copyWith(
            fontWeight: FontWeight.w500,
            color: palette.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Batal',
              style: textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.actionInk,
              side: BorderSide(color: palette.actionInk),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
            ),
            child: Text(
              'Hapus',
              style: textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _run(() => deleteOutfit(outfit.id));
    }
  }

  /// Runs one backend call and shows its message when it fails, so a rejected
  /// write never leaves the row looking saved.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on OutfitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  List<WardrobeItem> get _visible {
    final query = _query.trim().toLowerCase();
    return _catalog.where((item) {
      if (_category != wardrobeCategories.first && item.category != _category) {
        return false;
      }
      if (item.formality < _minFormality) return false;
      if (_occasions.isNotEmpty && !item.occasions.any(_occasions.contains)) {
        return false;
      }
      if (query.isEmpty) return true;
      return '${item.name} ${item.brand} ${item.category} ${item.colorName}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // The store is the normal path; a test may still hand in a fixed list.
    if (widget.items != null) return _scaffold(context);
    return ValueListenableBuilder<List<WardrobeItem>>(
      valueListenable: wardrobeItems,
      builder: (context, _, _) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(itemCount: _catalog.length),
                    const SizedBox(height: 16),
                    ValueListenableBuilder(
                      valueListenable: savedOutfits,
                      builder: (context, outfits, _) => _TabToggle(
                        tab: _tab,
                        outfitCount: outfits.length,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_tab == 0) ..._catalogTab() else ..._outfitTab(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(
                currentIndex: 1,
                onTap: (index) => openNavDestination(context, index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _catalogTab() {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final items = _visible;
    return [
      _SearchRow(
        controller: _search,
        filtering: _filtering,
        onQuery: (value) => setState(() => _query = value),
        onFilter: _openFilters,
      ),
      const SizedBox(height: 16),
      _CategoryChips(
        selected: _category,
        onSelected: (c) => setState(() => _category = c),
      ),
      const SizedBox(height: 16),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Nothing in this category yet.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge!.copyWith(
                fontWeight: FontWeight.w400,
                color: palette.inkMuted,
              ),
            ),
          ),
        )
      else
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final item in items) WardrobeItemCard(item: item)],
        ),
    ];
  }

  List<Widget> _outfitTab() {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _openBuilder(),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            'Buat Kombinasi',
            style: textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: palette.action,
            foregroundColor: palette.onAction,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.panel),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _SavedOutfitFilters(
        favoritesOnly: _favoritesOnly,
        onFavoritesOnlyChanged: (value) =>
            setState(() => _favoritesOnly = value),
      ),
      const SizedBox(height: 16),
      ValueListenableBuilder(
        valueListenable: savedOutfits,
        builder: (context, outfits, _) {
          final visibleOutfits = _favoritesOnly
              ? outfits.where((outfit) => outfit.favorite).toList()
              : outfits;
          if (visibleOutfits.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  _favoritesOnly
                      ? 'Belum ada favorit tersimpan.'
                      : 'Belum ada kombinasi tersimpan.',
                  style: textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w400,
                    color: palette.inkMuted,
                  ),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final outfit in _favoritesFirst(visibleOutfits)) ...[
                _SavedOutfitCard(
                  outfit: outfit,
                  catalog: _catalog,
                  onEdit: () => _openBuilder(existing: outfit),
                  onDelete: () => _confirmDelete(outfit),
                  onToggleFavorite: () =>
                      _run(() => toggleOutfitFavorite(outfit.id)),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    ];
  }

  /// Favourites first, otherwise the store's newest-first order.
  List<SavedOutfit> _favoritesFirst(List<SavedOutfit> outfits) => [
    ...outfits.where((o) => o.favorite),
    ...outfits.where((o) => !o.favorite),
  ];
}

class _SavedOutfitFilters extends StatelessWidget {
  const _SavedOutfitFilters({
    required this.favoritesOnly,
    required this.onFavoritesOnlyChanged,
  });

  final bool favoritesOnly;
  final ValueChanged<bool> onFavoritesOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label: 'Semua',
          selected: !favoritesOnly,
          onTap: () => onFavoritesOnlyChanged(false),
        ),
        _Chip(
          label: 'Favorit',
          selected: favoritesOnly,
          onTap: () => onFavoritesOnlyChanged(true),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wardrobe',
                style: textTheme.headlineLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total $itemCount items',
                style: textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Add item',
          onPressed: () => openNavDestination(context, 2),
          icon: const Icon(Icons.add, size: 22),
          color: palette.ink,
          style: IconButton.styleFrom(
            backgroundColor: palette.sheet,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }
}

/// Segmented switch between the catalog and the saved combinations.
class _TabToggle extends StatelessWidget {
  const _TabToggle({
    required this.tab,
    required this.outfitCount,
    required this.onChanged,
  });

  final int tab;
  final int outfitCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: AppRadius.panel,
      ),
      child: Row(
        children: [
          _segment(palette, textTheme, 'Katalog', 0),
          _segment(palette, textTheme, 'Kombinasi ($outfitCount)', 1),
        ],
      ),
    );
  }

  Widget _segment(
    AppPalette palette,
    TextTheme textTheme,
    String label,
    int index,
  ) {
    final active = tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: AppMotion.state,
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? palette.action : palette.canvas,
            borderRadius: AppRadius.chip,
          ),
          child: Text(
            label,
            style: textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: active ? palette.onAction : palette.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedOutfitCard extends StatelessWidget {
  const _SavedOutfitCard({
    required this.outfit,
    required this.catalog,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final SavedOutfit outfit;

  /// Catalog the saved ids resolve against; an id with no row is dropped.
  final List<WardrobeItem> catalog;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final items = outfit.itemsOf(catalog);
    final percent = (outfitScore(items) * 100).round();
    final threshold = (outfit.threshold * 100).round();
    final meets = percent >= threshold;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  outfit.name,
                  // Two lines: the three action buttons now share this row,
                  // so a user-named combination would otherwise ellipsize.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: outfit.favorite
                    ? 'Hapus dari favorit'
                    : 'Tandai favorit',
                onPressed: onToggleFavorite,
                icon: Icon(
                  outfit.favorite ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                ),
                color: outfit.favorite ? palette.actionInk : palette.ink,
                style: IconButton.styleFrom(
                  backgroundColor: palette.sheet,
                  minimumSize: const Size(40, 40),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit kombinasi',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: palette.ink,
                style: IconButton.styleFrom(
                  backgroundColor: palette.sheet,
                  minimumSize: const Size(40, 40),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hapus kombinasi',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: palette.ink,
                style: IconButton.styleFrom(
                  backgroundColor: palette.sheet,
                  minimumSize: const Size(40, 40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final item in items) ...[
                ClipRRect(
                  borderRadius: AppRadius.chip,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: PlaceholderImage(
                      imagePath: item.imagePath,
                      icon: Icons.checkroom_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: meets ? palette.action : palette.accentTint,
                  borderRadius: AppRadius.chip,
                ),
                child: Text(
                  '$percent%',
                  style: textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: meets ? palette.onAction : palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meets
                      ? 'Memenuhi batas $threshold%'
                      : 'Di bawah batas $threshold%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w400,
                    color: palette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.filtering,
    required this.onQuery,
    required this.onFilter,
  });

  final TextEditingController controller;
  final bool filtering;
  final ValueChanged<String> onQuery;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: palette.sheet,
              borderRadius: AppRadius.hero,
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 22, color: palette.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onChanged: onQuery,
                    style: textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.ink,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search your clothes...',
                      hintStyle: textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onQuery('');
                    },
                    icon: const Icon(Icons.close, size: 18),
                    color: palette.inkMuted,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Filter',
          onPressed: onFilter,
          icon: const Icon(Icons.tune, size: 22),
          color: filtering ? palette.onAction : palette.ink,
          style: IconButton.styleFrom(
            backgroundColor: filtering ? palette.action : palette.sheet,
            minimumSize: const Size(52, 52),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
          ),
        ),
      ],
    );
  }
}

/// Occasion and formality filter. Pops the chosen filter, or null on dismiss.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.occasions,
    required this.selected,
    required this.minFormality,
  });

  final List<String> occasions;
  final Set<String> selected;
  final int minFormality;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _selected = {...widget.selected};
  late int _minFormality = widget.minFormality;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.accentTint,
                  borderRadius: AppRadius.pill,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Filter',
              style: textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Acara',
              style: textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final occasion in widget.occasions)
                  _Chip(
                    label: occasion,
                    selected: _selected.contains(occasion),
                    onTap: () => setState(() {
                      if (_selected.contains(occasion)) {
                        _selected.remove(occasion);
                      } else {
                        _selected.add(occasion);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Formalitas minimal',
                    style: textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.inkMuted,
                    ),
                  ),
                ),
                Text(
                  '$_minFormality/5',
                  style: textTheme.labelLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
            Slider(
              value: _minFormality.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: palette.actionInk,
              inactiveColor: palette.accentTint,
              label: '$_minFormality',
              onChanged: (v) => setState(() => _minFormality = v.round()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _selected = {};
                      _minFormality = 1;
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.inkMuted),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.panel,
                      ),
                    ),
                    child: Text(
                      'Reset',
                      style: textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((occasions: _selected, minFormality: _minFormality)),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.action,
                      foregroundColor: palette.onAction,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.panel,
                      ),
                    ),
                    child: Text(
                      'Terapkan',
                      style: textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.state,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.action : palette.surfaceMuted,
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          label,
          style: textTheme.labelLarge!.copyWith(
            fontWeight: FontWeight.w500,
            color: selected ? palette.onAction : palette.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: wardrobeCategories.length,
        // Trailing room so the last chip is not flush against the edge when
        // the row is scrolled all the way right.
        padding: const EdgeInsets.only(right: 4),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = wardrobeCategories[index];
          final active = label == selected;
          return GestureDetector(
            onTap: () => onSelected(label),
            child: AnimatedContainer(
              duration: AppMotion.state,
              curve: Curves.easeInOut,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? palette.action : palette.surfaceMuted,
                borderRadius: AppRadius.chip,
              ),
              child: Text(
                label,
                style:
                    (active
                            ? textTheme.labelLarge!.copyWith(
                                fontWeight: FontWeight.w600,
                              )
                            : textTheme.labelLarge!.copyWith(
                                fontWeight: FontWeight.w500,
                              ))
                        .copyWith(
                          color: active ? palette.onAction : palette.inkMuted,
                        ),
              ),
            ),
          );
        },
      ),
    );
  }
}
