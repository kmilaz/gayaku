import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../logic/outfit_matcher.dart';
import '../models/wardrobe.dart';
import '../state/outfit_store.dart';
import '../theme/app_theme.dart';
import '../widgets/placeholder_image.dart';

/// Build or edit one combination by hand, slot per slot.
///
/// A live [outfitScore] meter plus a threshold slider: while the score sits
/// below the threshold, [improveOutfit] proposes swaps that lift it.
class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key, this.existing, this.catalog = wardrobeItems});

  /// Pass a saved outfit to edit it in place; null creates a new one.
  final SavedOutfit? existing;
  final List<WardrobeItem> catalog;

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  late final TextEditingController _name;
  late List<WardrobeItem> _picked;
  late double _threshold;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _picked = existing?.items ?? [];
    _threshold = existing?.threshold ?? 0.80;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<String> get _slots => wardrobeCategories.skip(1).toList();

  double get _score => outfitScore(_picked);

  /// One item per slot; outerwear and accessories are optional layers.
  bool _isOptional(String slot) =>
      slot == 'Outerwear' || slot == 'Accessories';

  WardrobeItem? _at(String slot) => _picked.where((i) => i.category == slot).firstOrNull;

  void _set(String slot, WardrobeItem item) {
    setState(() {
      _picked = [
        ..._picked.where((i) => i.category != slot),
        item,
      ];
    });
  }

  void _remove(String slot) {
    setState(() => _picked = _picked.where((i) => i.category != slot).toList());
  }

  Future<void> _pick(String slot) async {
    final options = widget.catalog.where((i) => i.category == slot).toList();
    if (options.isEmpty) {
      showNote(context, 'Belum ada item $slot');
      return;
    }
    final chosen = await showModalBottomSheet<WardrobeItem>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _PickerSheet(slot: slot, options: options),
    );
    if (chosen != null) _set(slot, chosen);
  }

  void _applySwap(SwapSuggestion swap) {
    setState(() {
      _picked = [..._picked]..[swap.index] = swap.to;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (_picked.length < 2) {
      showNote(context, 'Pilih minimal 2 item dulu');
      return;
    }
    saveOutfit(
      SavedOutfit(
        id: widget.existing?.id ?? newOutfitId(),
        name: name.isEmpty ? 'Kombinasi Baru' : name,
        itemNames: _picked.map((i) => i.name).toList(),
        threshold: _threshold,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final swaps = improveOutfit(
      _picked,
      widget.catalog,
      threshold: _threshold,
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
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
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.espresso,
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
                      const SizedBox(height: 10),
                    ],
                    if (swaps.isNotEmpty) ...[
                      const SizedBox(height: 10),
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
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(
                    widget.existing == null
                        ? 'Simpan Kombinasi'
                        : 'Simpan Perubahan',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    foregroundColor: AppColors.cream,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
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
    return Row(
      children: [
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          color: AppColors.espresso,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(44, 44),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            editing ? 'Edit Kombinasi' : 'Kombinasi Baru',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.espresso,
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
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: AppColors.beige),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.taupe),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.espresso,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Nama kombinasi, mis. Kantor Senin',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.taupe,
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
    final percent = (score * 100).round();
    final meets = score >= threshold;
    final weak = weakest;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: meets ? AppColors.espresso : AppColors.tan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    meets
                        ? 'Memenuhi batas'
                        : 'Di bawah batas ${(threshold * 100).round()}%',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.taupe,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8,
              backgroundColor: AppColors.beige,
              valueColor: AlwaysStoppedAnimation(
                meets ? AppColors.espresso : AppColors.tan,
              ),
            ),
          ),
          if (weak != null && weak.score < 0.6) ...[
            const SizedBox(height: 10),
            Text(
              'Pasangan terlemah: ${weak.a.name} + ${weak.b.name} '
              '(${(weak.score * 100).round()}%)',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.taupe,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Batas minimum',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.espresso,
                ),
              ),
              Expanded(
                child: Slider(
                  value: threshold,
                  min: 0.50,
                  max: 0.95,
                  divisions: 9,
                  activeColor: AppColors.tan,
                  inactiveColor: AppColors.beige,
                  label: '${(threshold * 100).round()}%',
                  onChanged: onThreshold,
                ),
              ),
              Text(
                '${(threshold * 100).round()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.taupe,
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
    final chosen = item;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(
            color: chosen == null ? AppColors.beige : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: SizedBox(
                width: 52,
                height: 52,
                child: chosen == null
                    ? Container(
                        color: AppColors.beige,
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: AppColors.tan,
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.taupe,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chosen?.name ?? 'Pilih item',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: chosen == null
                          ? AppColors.taupe
                          : AppColors.espresso,
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
                color: AppColors.taupe,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rekomendasi Peningkatan',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.espresso,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Skor masih di bawah batas ${(threshold * 100).round()}%. '
          'Ganti salah satu item:',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.taupe),
        ),
        const SizedBox(height: 12),
        for (final swap in swaps) ...[
          GestureDetector(
            onTap: () => onApply(swap),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                border: Border.all(color: AppColors.tan),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.taupe,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          swap.to.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.espresso,
                          ),
                        ),
                        Text(
                          '${swap.to.category} • ${swap.to.colorName}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.taupe,
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
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tan,
                        ),
                      ),
                      Text(
                        'Terapkan',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
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
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Pilih $slot',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.espresso,
              ),
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
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
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
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.espresso,
                    ),
                  ),
                  subtitle: Text(
                    '${item.colorName} • Formalitas ${item.formality}/5',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.taupe,
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
