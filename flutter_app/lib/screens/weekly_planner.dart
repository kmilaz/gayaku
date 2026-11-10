import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../navigation.dart';
import '../state/outfit_store.dart';
import '../state/planner_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/note.dart';
import '../widgets/placeholder_image.dart';

DateTime _mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

class WeeklyPlanner extends StatefulWidget {
  const WeeklyPlanner({super.key});

  @override
  State<WeeklyPlanner> createState() => _WeeklyPlannerState();
}

class _WeeklyPlannerState extends State<WeeklyPlanner> {
  static const _dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _monthNames = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];

  DateTime _weekStart = _mondayOf(DateTime.now());
  int _selectedDay = -1;
  bool _showEmptyDays = true;

  /// The plan as look cards. Rows come from Supabase and are re-rendered when
  /// the plan, the combinations or the catalog change.
  Map<DateTime, _PlannedOutfit> get _outfits => _renderPlan(
    plannerEntries.value,
    savedOutfits.value,
    wardrobeItems.value,
  );

  @override
  void initState() {
    super.initState();
    plannerEntries.addListener(_refresh);
    savedOutfits.addListener(_refresh);
    wardrobeItems.addListener(_refresh);
    unawaited(loadPlannerFromBackend());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    plannerEntries.removeListener(_refresh);
    savedOutfits.removeListener(_refresh);
    wardrobeItems.removeListener(_refresh);
    super.dispose();
  }

  List<DateTime> get _weekDates =>
      List.generate(7, (index) => _weekStart.add(Duration(days: index)));

  int get _plannedCount => _weekDates.where(_outfits.containsKey).length;

  void _changeWeek(int amount) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: amount * 7));
      _selectedDay = -1;
    });
  }

  String _weekHeader(List<DateTime> dates) {
    final start = dates.first;
    final end = dates.last;
    final startMonth = _monthNames[start.month - 1];
    final endMonth = _monthNames[end.month - 1];
    if (start.year == end.year && start.month == end.month) {
      return '$startMonth ${start.year}';
    }
    final startLabel = '$startMonth ${start.year}';
    final endLabel = start.year == end.year
        ? endMonth
        : '$endMonth ${end.year}';
    return '$startLabel - $endLabel';
  }

  Future<void> _editOutfit(DateTime date) async {
    final current = _outfits[date];
    final result = await showDialog<PlannerEntry>(
      context: context,
      builder: (_) => _PlanOutfitDialog(day: date, current: current),
    );
    if (result == null || !mounted) return;
    try {
      await savePlannerEntry(result);
    } on OutfitException catch (e) {
      if (mounted) showNote(context, e.message);
    }
  }

  Future<void> _toggleComplete(DateTime date) async {
    final outfit = _outfits[date];
    if (outfit == null) return;
    try {
      await savePlannerEntry(
        PlannerEntry(
          day: date,
          outfitId: outfit.outfitId,
          occasion: outfit.occasion,
          complete: !outfit.complete,
        ),
      );
    } on OutfitException catch (e) {
      if (mounted) showNote(context, e.message);
    }
  }

  Future<void> _confirmClearOutfit(DateTime date) async {
    final palette = AppColors.of(context);
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.sheet,
        title: Text(
          'Clear this day?',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 24,
            height: 30 / 24,
            fontWeight: FontWeight.bold,
            color: palette.ink,
          ),
        ),
        content: const Text(
          'This will remove the outfit planned for this day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.action,
              foregroundColor: palette.onAction,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) return;
    try {
      await deletePlannerEntry(date);
    } on OutfitException catch (e) {
      if (mounted) showNote(context, e.message);
    }
  }

  Future<void> _showSettings() async {
    final palette = AppColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.sheet,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planner settings',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  height: 30 / 24,
                  fontWeight: FontWeight.bold,
                  color: palette.ink,
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: palette.action,
                title: const Text('Show days without an outfit'),
                value: _showEmptyDays,
                onChanged: (value) {
                  setState(() => _showEmptyDays = value);
                  setSheetState(() {});
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _changeWeek(-1);
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous week'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _changeWeek(1);
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next week'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final dates = _weekDates;
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _weekHeader(dates),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 15 / 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                                color: palette.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Weekly Planner',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 24,
                                height: 30 / 24,
                                fontWeight: FontWeight.bold,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Planner settings',
                        onPressed: _showSettings,
                        style: IconButton.styleFrom(
                          backgroundColor: palette.surface,
                          foregroundColor: palette.ink,
                          fixedSize: const Size(46, 46),
                        ),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _WeekSummary(plannedCount: _plannedCount),
                  const SizedBox(height: 20),
                  for (var dayIndex = 0; dayIndex < 7; dayIndex++)
                    if (_showEmptyDays || _outfits.containsKey(dates[dayIndex]))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDayRow(dayIndex, dates[dayIndex]),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(
                currentIndex: 3,
                onTap: (index) => openNavDestination(context, index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(int dayIndex, DateTime date) {
    final palette = AppColors.of(context);
    final outfit = _outfits[date];
    final isSelected = dayIndex == _selectedDay;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                _dayNames[dayIndex],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? palette.action : palette.inkMuted,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: isSelected
                    ? BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '${date.day}',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    height: 23 / 16,
                    fontWeight: FontWeight.bold,
                    color: palette.ink,
                  ),
                ),
              ),
              if (dayIndex < 6)
                Container(
                  width: 1,
                  height: outfit != null && isSelected ? 300 : 48,
                  color: isSelected
                      ? palette.accent.withValues(alpha: 0.55)
                      : palette.surface,
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: outfit == null
              ? _EmptyDayCard(
                  dayName: _dayNames[dayIndex],
                  onTap: () => _editOutfit(date),
                )
              : isSelected
              ? _FeaturedOutfit(
                  outfit: outfit,
                  onEdit: () => _editOutfit(date),
                  onToggleComplete: () => _toggleComplete(date),
                  onClear: () => _confirmClearOutfit(date),
                )
              : _CompactOutfit(
                  outfit: outfit,
                  onTap: () => setState(() => _selectedDay = dayIndex),
                  onToggleComplete: () => _toggleComplete(date),
                ),
        ),
      ],
    );
  }
}

class _PlanOutfitDialog extends StatefulWidget {
  const _PlanOutfitDialog({required this.day, required this.current});

  final DateTime day;
  final _PlannedOutfit? current;

  @override
  State<_PlanOutfitDialog> createState() => _PlanOutfitDialogState();
}

class _PlanOutfitDialogState extends State<_PlanOutfitDialog> {
  late final TextEditingController _occasionController = TextEditingController(
    text: widget.current?.occasion ?? '',
  );
  String? _selectedOutfitId;

  @override
  void initState() {
    super.initState();
    _selectedOutfitId = widget.current?.outfitId;
    _occasionController.addListener(_refresh);
  }

  void _refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    _occasionController.removeListener(_refresh);
    _occasionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final current = widget.current;
    return AlertDialog(
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      title: Text(
        current == null ? 'Plan outfit' : 'Edit outfit',
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 24,
          height: 30 / 24,
          fontWeight: FontWeight.bold,
          color: palette.ink,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 410,
        child: Column(
          children: [
            TextField(
              controller: _occasionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Occasion',
                hintText: 'e.g. Work, dinner, or weekend',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: savedOutfits.value.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada kombinasi. Simpan satu di tab Kombinasi.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: palette.inkMuted,
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 158,
                          ),
                      itemCount: savedOutfits.value.length,
                      itemBuilder: (context, index) {
                        final outfit = savedOutfits.value[index];
                        final look = lookFromOutfit(
                          outfit,
                          wardrobeItems.value,
                        );
                        final isSelected = _selectedOutfitId == outfit.id;
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? palette.accentInk
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            onTap: () => setState(() {
                              _selectedOutfitId = outfit.id;
                            }),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      PlaceholderImage(
                                        imagePath: look.imagePath,
                                        icon: Icons.checkroom_outlined,
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Icon(
                                            Icons.check_circle,
                                            color: palette.accentInk,
                                            shadows: [
                                              Shadow(
                                                color: palette.ink.withValues(
                                                  alpha: 0.35,
                                                ),
                                                blurRadius: 5,
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    look.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: palette.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: palette.action,
            foregroundColor: palette.onAction,
          ),
          onPressed:
              _selectedOutfitId == null ||
                  _occasionController.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  PlannerEntry(
                    day: widget.day,
                    outfitId: _selectedOutfitId!,
                    occasion: _occasionController.text.trim(),
                    complete: current?.complete ?? false,
                  ),
                ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.plannedCount});

  final int plannedCount;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Week Planned',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: palette.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$plannedCount/7 Days',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: plannedCount / 7,
              minHeight: 8,
              backgroundColor: palette.canvas,
              valueColor: AlwaysStoppedAnimation(palette.action),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            plannedCount == 7
                ? 'Your outfits are ready for the whole week.'
                : "You're on track! Plan ${7 - plannedCount} more outfits to complete your week.",
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: palette.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactOutfit extends StatelessWidget {
  const _CompactOutfit({
    required this.outfit,
    required this.onTap,
    required this.onToggleComplete,
  });

  final _PlannedOutfit outfit;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: PlaceholderImage(
                  imagePath: outfit.look.imagePath,
                  icon: Icons.checkroom_outlined,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.occasion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                        decoration: outfit.complete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      outfit.look.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: outfit.complete ? 'Mark as planned' : 'Mark complete',
                onPressed: onToggleComplete,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  outfit.complete
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: outfit.complete ? palette.accentInk : palette.inkMuted,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedOutfit extends StatefulWidget {
  const _FeaturedOutfit({
    required this.outfit,
    required this.onEdit,
    required this.onToggleComplete,
    required this.onClear,
  });

  final _PlannedOutfit outfit;
  final VoidCallback onEdit;
  final VoidCallback onToggleComplete;
  final VoidCallback onClear;

  @override
  State<_FeaturedOutfit> createState() => _FeaturedOutfitState();
}

class _FeaturedOutfitState extends State<_FeaturedOutfit> {
  bool _showOutfitActions = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final outfit = widget.outfit;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 330,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: PlaceholderImage(
                    imagePath: outfit.look.imagePath,
                    icon: Icons.checkroom_outlined,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, palette.ink],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Outfit options',
                        onPressed: () => setState(
                          () => _showOutfitActions = !_showOutfitActions,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: palette.canvas.withValues(
                            alpha: 0.9,
                          ),
                          foregroundColor: palette.ink,
                        ),
                        icon: const Icon(Icons.more_vert),
                      ),
                      if (_showOutfitActions) ...[
                        const SizedBox(height: 8),
                        IconButton.filledTonal(
                          tooltip: 'Edit outfit',
                          onPressed: () {
                            setState(() => _showOutfitActions = false);
                            widget.onEdit();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: palette.canvas.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: palette.ink,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        const SizedBox(height: 8),
                        IconButton.filledTonal(
                          tooltip: 'Clear schedule',
                          onPressed: () {
                            setState(() => _showOutfitActions = false);
                            widget.onClear();
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: palette.canvas.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: palette.ink,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 34, 70, 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, palette.ink],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLANNED OUTFIT',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.canvas,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outfit.occasion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 22,
                            height: 27 / 22,
                            fontWeight: FontWeight.bold,
                            color: palette.canvas,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outfit.look.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: palette.canvas,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _outfitSlots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 82,
          ),
          itemBuilder: (context, index) {
            final slot = _outfitSlots[index];
            final item = outfit.look.items
                .where((item) => item.type.toLowerCase() == slot.itemType)
                .firstOrNull;
            return _OutfitItemCard(slot: slot, item: item);
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: palette.action,
              foregroundColor: palette.onAction,
            ),
            onPressed: widget.onToggleComplete,
            icon: Icon(
              outfit.complete ? Icons.check_circle : Icons.check_circle_outline,
            ),
            label: Text(outfit.complete ? 'Planned' : 'Mark complete'),
          ),
        ),
      ],
    );
  }
}

class _OutfitItemCard extends StatelessWidget {
  const _OutfitItemCard({required this.slot, required this.item});

  final _OutfitSlot slot;
  final LookItem? item;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final selectedItem = item;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 58,
              child: selectedItem == null
                  ? Container(
                      color: palette.canvas,
                      child: Icon(slot.icon, color: palette.accentInk),
                    )
                  : PlaceholderImage(
                      imagePath: selectedItem.imagePath,
                      icon: slot.icon,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: palette.inkMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item?.name ?? 'Not included',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
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

class _OutfitSlot {
  const _OutfitSlot(this.label, this.itemType, this.icon);

  final String label;
  final String itemType;
  final IconData icon;
}

const _outfitSlots = [
  _OutfitSlot('Tops', 'top', Icons.checkroom_outlined),
  _OutfitSlot('Bottom', 'bottom', Icons.checkroom_outlined),
  _OutfitSlot('Accessories', 'accessory', Icons.diamond_outlined),
  _OutfitSlot('Shoes', 'shoes', Icons.directions_walk_outlined),
];

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.dayName, required this.onTap});

  final String dayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.canvas,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: palette.accentInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Plan outfit for ${dayName.toLowerCase().substring(0, 1)}${dayName.toLowerCase().substring(1)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: palette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannedOutfit {
  const _PlannedOutfit({
    required this.outfitId,
    required this.look,
    required this.occasion,
    required this.complete,
  });

  /// `outfit_looks.id`, the row the plan points at.
  final String outfitId;
  final Look look;
  final String occasion;
  final bool complete;
}

/// Joins planner rows with the combinations they point at. A row whose
/// combination is gone (or not loaded yet) is skipped, not faked.
Map<DateTime, _PlannedOutfit> _renderPlan(
  Map<DateTime, PlannerEntry> entries,
  List<SavedOutfit> outfits,
  List<WardrobeItem> catalog,
) {
  final byId = {for (final outfit in outfits) outfit.id: outfit};
  final plan = <DateTime, _PlannedOutfit>{};
  for (final entry in entries.entries) {
    final outfit = byId[entry.value.outfitId];
    if (outfit == null) continue;
    plan[dayKey(entry.key)] = _PlannedOutfit(
      outfitId: outfit.id,
      look: lookFromOutfit(outfit, catalog),
      occasion: entry.value.occasion,
      complete: entry.value.complete,
    );
  }
  return plan;
}
