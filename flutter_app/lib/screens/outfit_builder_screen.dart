import 'package:flutter/material.dart';

import '../logic/outfit_matcher.dart';
import '../models/wardrobe.dart';
import '../state/outfit_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/placeholder_image.dart';
import '../widgets/note.dart';

/// Build or edit one combination by hand, slot per slot.
///
/// A live [outfitScore] meter plus a threshold slider: while the score sits
/// below the threshold, [improveOutfit] proposes swaps that lift it.
class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key, this.existing, this.catalog});

  /// Pass a saved outfit to edit it in place; null creates a new one.
  final SavedOutfit? existing;

  /// Overrides the store with a fixed catalog, for tests. Null — the app's
  /// case — follows [wardrobeItems].
  final List<WardrobeItem>? catalog;

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  late final TextEditingController _name;
  late List<WardrobeItem> _picked;
  late double _threshold;

  /// The garments offered per slot: the injected override, else the live store.
  List<WardrobeItem> get _catalog => widget.catalog ?? wardrobeItems.value;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _picked = existing?.itemsOf(_catalog) ?? [];
    _threshold = existing?.threshold ?? 0.80;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<String> get _slots => wardrobeSlots;

  double get _score => outfitScore(_picked);

  /// One item per slot; outerwear and accessories are optional layers.
  bool _isOptional(String slot) => slot == 'Outerwear' || slot == 'Accessories';

  WardrobeItem? _at(String slot) =>
      _picked.where((i) => i.category == slot).firstOrNull;

  void _set(String slot, WardrobeItem item) {
    setState(() {
      _picked = [..._picked.where((i) => i.category != slot), item];
    });
  }

  void _remove(String slot) {
    setState(() => _picked = _picked.where((i) => i.category != slot).toList());
  }

  Future<void> _pick(String slot) async {
    final options = _catalog.where((i) => i.category == slot).toList();
    if (options.isEmpty) {
      showNote(context, 'Belum ada item $slot');
      return;
    }
    final chosen = await showModalBottomSheet<WardrobeItem>(
      context: context,
      backgroundColor: AppColors.of(context).sheet,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => _PickerSheet(slot: slot, options: options),
    );
    if (chosen != null) _set(slot, chosen);
  }

  void _applySwap(SwapSuggestion swap) {
    setState(() {
      _picked = [..._picked]..[swap.index] = swap.to;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_picked.length < 2) {
      showNote(context, 'Pilih minimal 2 item dulu');
      return;
    }
    try {
      await saveOutfit(
        SavedOutfit(
          id: widget.existing?.id ?? newOutfitId(),
          name: name.isEmpty ? 'Kombinasi Baru' : name,
          itemIds: _picked.map((i) => i.id).toList(),
          threshold: _threshold,
          favorite: widget.existing?.favorite ?? false,
          createdAt: widget.existing?.createdAt,
        ),
      );
    } on OutfitException catch (e) {
      if (mounted) showNote(context, e.message);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final swaps = improveOutfit(_picked, _catalog, threshold: _threshold);

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
                    _TopBar(editing: widget.existing != null),
                    const SizedBox(height: 16),
                    _NameField(controller: _name),
                    const SizedBox(height: 16),
                    _ScoreCard(
                      score: _score,
                      threshold: _threshold,
                      weakest: weakestPair(_picked),
                      onThreshold: (v) => setState(() => _threshold = v),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Susun Kombinasi',
                      style: textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final slot in _slots) ...[
                      _SlotRow(
                        slot: slot,
                        item: _at(slot),
                        optional: _isOptional(slot),
                        onPick: () => _pick(slot),
                        onClear: () => _remove(slot),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (swaps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ImproveSection(
                        swaps: swaps,
                        threshold: _threshold,
                        onApply: _applySwap,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    widget.existing == null
                        ? 'Simpan Kombinasi'
                        : 'Simpan Perubahan',
                    style: textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.action,
                    foregroundColor: palette.onAction,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.panel,
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.editing});

  final bool editing;

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
            editing ? 'Edit Kombinasi' : 'Kombinasi Baru',
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

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 18, color: palette.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: textTheme.labelLarge!.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.ink,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Nama kombinasi, mis. Kantor Senin',
                hintStyle: textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live match meter + the threshold slider that drives the suggestions.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.threshold,
    required this.weakest,
    required this.onThreshold,
  });

  final double score;
  final double threshold;
  final ({WardrobeItem a, WardrobeItem b, double score})? weakest;
  final ValueChanged<double> onThreshold;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final percent = (score * 100).round();
    final meets = score >= threshold;
    final weak = weakest;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: textTheme.headlineLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    meets
                        ? 'Memenuhi batas'
                        : 'Di bawah batas ${(threshold * 100).round()}%',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: palette.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.chip,
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8,
              backgroundColor: palette.accentTint,
              valueColor: AlwaysStoppedAnimation(palette.actionInk),
            ),
          ),
          if (weak != null && weak.score < 0.6) ...[
            const SizedBox(height: 12),
            Text(
              'Pasangan terlemah: ${weak.a.name} + ${weak.b.name} '
              '(${(weak.score * 100).round()}%)',
              style: textTheme.labelMedium!.copyWith(
                fontWeight: FontWeight.w400,
                color: palette.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Batas minimum',
                style: textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              Expanded(
                child: Slider(
                  value: threshold,
                  min: 0.50,
                  max: 0.95,
                  divisions: 9,
                  activeColor: palette.actionInk,
                  inactiveColor: palette.accentTint,
                  label: '${(threshold * 100).round()}%',
                  onChanged: onThreshold,
                ),
              ),
              Text(
                '${(threshold * 100).round()}%',
                style: textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.item,
    required this.optional,
    required this.onPick,
    required this.onClear,
  });

  final String slot;
  final WardrobeItem? item;
  final bool optional;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chosen = item;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.sheet,
          borderRadius: AppRadius.field,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.chip,
              child: SizedBox(
                width: 52,
                height: 52,
                child: chosen == null
                    ? Container(
                        color: palette.surfaceMuted,
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: palette.inkMuted,
                        ),
                      )
                    : PlaceholderImage(
                        imagePath: chosen.imagePath,
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
                    slot + (optional ? ' · opsional' : ''),
                    style: textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: palette.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chosen?.name ?? 'Pilih item',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: chosen == null ? palette.inkMuted : palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (chosen != null)
              IconButton(
                tooltip: 'Hapus dari kombinasi',
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
                color: palette.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown only while the score is under the threshold.
class _ImproveSection extends StatelessWidget {
  const _ImproveSection({
    required this.swaps,
    required this.threshold,
    required this.onApply,
  });

  final List<SwapSuggestion> swaps;
  final double threshold;
  final ValueChanged<SwapSuggestion> onApply;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rekomendasi Peningkatan',
          style: textTheme.headlineSmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Skor masih di bawah batas ${(threshold * 100).round()}%. '
          'Ganti salah satu item:',
          style: textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w400,
            color: palette.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        for (final swap in swaps) ...[
          GestureDetector(
            onTap: () => onApply(swap),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.sheet,
                borderRadius: AppRadius.field,
                border: Border.all(color: palette.inkMuted),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.chip,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: PlaceholderImage(
                        imagePath: swap.to.imagePath,
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
                          'Ganti ${swap.from.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium!.copyWith(
                            fontWeight: FontWeight.w400,
                            color: palette.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          swap.to.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          '${swap.to.category} • ${swap.to.colorName}',
                          style: textTheme.labelMedium!.copyWith(
                            fontWeight: FontWeight.w400,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${swap.gainPercent}%',
                        style: textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      Text(
                        'Terapkan',
                        style: textTheme.labelMedium!.copyWith(
                          fontWeight: FontWeight.w400,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Bottom sheet listing every catalog item of one slot.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.slot, required this.options});

  final String slot;
  final List<WardrobeItem> options;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
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
                  'Pilih $slot',
                  style: textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final item = options[index];
                return ListTile(
                  onTap: () => Navigator.of(context).pop(item),
                  leading: ClipRRect(
                    borderRadius: AppRadius.chip,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: PlaceholderImage(
                        imagePath: item.imagePath,
                        icon: Icons.checkroom_outlined,
                      ),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${item.colorName} • Formalitas ${item.formality}/5',
                    style: textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.inkMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
