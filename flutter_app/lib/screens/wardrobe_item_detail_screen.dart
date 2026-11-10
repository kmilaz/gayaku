import 'package:flutter/material.dart';

import '../logic/outfit_matcher.dart';
import '../models/wardrobe.dart';
import '../state/outfit_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/placeholder_image.dart';
import '../widgets/note.dart';

/// Detail of one wardrobe item plus the pieces it pairs with.
///
/// The ranking comes from [outfitFor] (color harmony, formality, occasion);
/// saving the suggestion writes a row through the outfit backend.
class WardrobeItemDetailScreen extends StatelessWidget {
  const WardrobeItemDetailScreen({super.key, required this.item, this.catalog});

  final WardrobeItem item;

  /// Partner pieces: the live catalog, or an injected one under test.
  final List<WardrobeItem>? catalog;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final catalog = this.catalog ?? wardrobeItems.value;
    final matches = outfitFor(item, catalog);
    final alternatives =
        recommendMatches(item, catalog).length - matches.length;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(name: item.name),
              const SizedBox(height: 16),
              _Hero(item: item),
              const SizedBox(height: 16),
              _AttributeRow(item: item),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Cocok Dipadukan Dengan',
                subtitle: matches.isEmpty
                    ? 'Belum ada item lain di lemarimu.'
                    : 'Diurutkan dari harmoni warna, formalitas, dan acara.',
              ),
              const SizedBox(height: 16),
              for (final match in matches) ...[
                _MatchCard(match: match),
                const SizedBox(height: 12),
              ],
              if (alternatives > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+$alternatives pilihan lain dengan skor lebih rendah',
                    style: textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: palette.inkMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _CombineButton(item: item, matches: matches),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 22),
          color: palette.ink,
          style: IconButton.styleFrom(
            backgroundColor: palette.sheet,
            minimumSize: const Size(44, 44),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.hero,
        boxShadow: const [AppDecorations.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.panel,
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: PlaceholderImage(
                imagePath: item.imagePath,
                icon: Icons.checkroom_outlined,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.brand.isEmpty
                      ? item.category
                      : '${item.category} • ${item.brand}',
                  style: textTheme.labelLarge!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Color swatch, formality dots and occasion pills for the selected item.
class _AttributeRow extends StatelessWidget {
  const _AttributeRow({required this.item});

  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (item.colorName.isNotEmpty)
          _Pill(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
                border: Border.all(color: palette.inkMuted),
              ),
            ),
            label: item.colorName,
          ),
        _Pill(
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: i <= item.formality
                        ? palette.ink
                        : palette.surfaceMuted,
                  ),
                ),
            ],
          ),
          label: 'Formalitas ${item.formality}/5',
        ),
        for (final occasion in item.occasions) _Pill(label: occasion),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Text(
            label,
            style: textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w400,
            color: palette.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// One recommended partner: thumbnail, name, reason chips, score badge.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final MatchSuggestion match;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final item = match.item;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.panel,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.field,
            child: SizedBox(
              width: 72,
              height: 72,
              child: PlaceholderImage(
                imagePath: item.imagePath,
                icon: Icons.checkroom_outlined,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} • ${item.colorName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium!.copyWith(
                    fontWeight: FontWeight.w400,
                    color: palette.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final reason in match.reasons)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accentTint,
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          reason,
                          style: textTheme.labelMedium!.copyWith(
                            fontWeight: FontWeight.w400,
                            color: palette.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: palette.accentTint,
              borderRadius: AppRadius.chip,
            ),
            child: Text(
              '${match.percent}%',
              style: textTheme.labelMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CombineButton extends StatelessWidget {
  const _CombineButton({required this.item, required this.matches});

  final WardrobeItem item;
  final List<MatchSuggestion> matches;

  /// Stores the base item plus its recommended partners as a saved combination.
  Future<void> _save(BuildContext context) async {
    if (matches.isEmpty) {
      showNote(context, 'Belum ada item untuk dikombinasikan');
      return;
    }
    try {
      await saveOutfit(
        SavedOutfit(
          id: newOutfitId(),
          name: 'Setelan ${item.name}',
          itemIds: [item.id, ...matches.map((m) => m.item.id)],
          threshold: 0.80,
        ),
      );
      if (context.mounted) {
        showNote(context, 'Kombinasi tersimpan di tab Kombinasi');
      }
    } on OutfitException catch (e) {
      if (context.mounted) showNote(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _save(context),
        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        label: Text(
          'Simpan Kombinasi',
          style: textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: palette.action,
          foregroundColor: palette.onAction,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.panel),
        ),
      ),
    );
  }
}
