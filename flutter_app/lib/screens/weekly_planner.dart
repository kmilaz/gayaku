import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import 'add_item_stub.dart';

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

  DateTime _weekStart = DateTime(2026, 1, 1);
  int _selectedDay = -1;
  bool _showEmptyDays = true;
  final Map<int, _PlannedOutfit> _outfits = {};

  List<DateTime> get _weekDates =>
      List.generate(7, (index) => _weekStart.add(Duration(days: index)));

  int get _plannedCount => _outfits.length;

  void _changeWeek(int amount) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: amount * 7));
    });
  }

  Future<void> _editOutfit(int dayIndex) async {
    final current = _outfits[dayIndex];
    final result = await showDialog<_PlannedOutfit>(
      context: context,
      builder: (_) => _PlanOutfitDialog(current: current),
    );
    if (result != null && mounted) {
      setState(() => _outfits[dayIndex] = result);
    }
  }

  void _toggleComplete(int dayIndex) {
    final outfit = _outfits[dayIndex];
    if (outfit == null) return;
    setState(() {
      _outfits[dayIndex] = outfit.copyWith(complete: !outfit.complete);
    });
  }

  Future<void> _confirmClearOutfit(int dayIndex) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text(
          'Clear this day?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.espresso,
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.tan),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear == true && mounted) {
      setState(() => _outfits.remove(dayIndex));
    }
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planner settings',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.espresso,
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.tan,
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
    final dates = _weekDates;
    final month = _monthNames[dates[0].month - 1];
    return Scaffold(
      backgroundColor: AppColors.cream,
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
                              '$month ${dates[0].year}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                                color: AppColors.taupe,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Weekly Planner',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                                color: AppColors.espresso,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Planner settings',
                        onPressed: _showSettings,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.beige,
                          foregroundColor: AppColors.espresso,
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
                    if (_showEmptyDays || _outfits.containsKey(dayIndex))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildDayRow(dayIndex, dates[dayIndex]),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(currentIndex: 3, onTap: _onNavigationTap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(int dayIndex, DateTime date) {
    final outfit = _outfits[dayIndex];
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
                  color: isSelected ? AppColors.tan : AppColors.taupe,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: isSelected
                    ? const BoxDecoration(
                        color: AppColors.beige,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '${date.day}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.espresso,
                  ),
                ),
              ),
              if (dayIndex < 6)
                Container(
                  width: 1,
                  height: outfit != null && isSelected ? 300 : 48,
                  color: isSelected
                      ? AppColors.tan.withValues(alpha: 0.55)
                      : AppColors.beige,
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: outfit == null
              ? _EmptyDayCard(
                  dayName: _dayNames[dayIndex],
                  onTap: () => _editOutfit(dayIndex),
                )
              : isSelected
              ? _FeaturedOutfit(
                  outfit: outfit,
                  onEdit: () => _editOutfit(dayIndex),
                  onToggleComplete: () => _toggleComplete(dayIndex),
                  onClear: () => _confirmClearOutfit(dayIndex),
                )
              : _CompactOutfit(
                  outfit: outfit,
                  onTap: () => setState(() => _selectedDay = dayIndex),
                  onToggleComplete: () => _toggleComplete(dayIndex),
                ),
        ),
      ],
    );
  }

  void _onNavigationTap(int index) {
    if (index == 2) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const AddItemStub()));
      return;
    }
    if (index == 0 && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    final labels = ['Home', 'Wardrobe', 'Scan', 'Planner', 'Profile'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${labels[index]} is not available yet')),
    );
  }
}

class _PlanOutfitDialog extends StatefulWidget {
  const _PlanOutfitDialog({required this.current});

  final _PlannedOutfit? current;

  @override
  State<_PlanOutfitDialog> createState() => _PlanOutfitDialogState();
}

class _PlanOutfitDialogState extends State<_PlanOutfitDialog> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.current?.title ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.current?.description ?? '');

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return AlertDialog(
      backgroundColor: AppColors.cream,
      title: Text(
        current == null ? 'Plan outfit' : 'Edit outfit',
        style: GoogleFonts.playfairDisplay(
          fontWeight: FontWeight.bold,
          color: AppColors.espresso,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes'),
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.tan),
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              _PlannedOutfit(
                title: title,
                description: _descriptionController.text.trim(),
                icon: current?.icon ?? Icons.checkroom_rounded,
                complete: current?.complete ?? false,
              ),
            );
          },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(30),
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
                  color: AppColors.espresso,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$plannedCount/7 Days',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.espresso,
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
              backgroundColor: AppColors.cream,
              valueColor: const AlwaysStoppedAnimation(AppColors.tan),
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
              color: AppColors.taupe,
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
    return Material(
      color: AppColors.beige,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(outfit.icon, size: 30, color: AppColors.tan),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.espresso,
                        decoration: outfit.complete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      outfit.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.taupe,
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
                  color: outfit.complete ? AppColors.tan : AppColors.taupe,
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
  static const _categories = [
    _OutfitCategory('Tops', Icons.checkroom_outlined),
    _OutfitCategory('Bottom', Icons.checkroom_outlined),
    _OutfitCategory('Shoes', Icons.checkroom_outlined),
    _OutfitCategory('Accessories', Icons.checkroom_outlined),
  ];

  late final PageController _pageController = PageController();
  int _selectedCategory = 0;
  bool _showOutfitActions = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.beige,
                  ),
                ),
                Positioned(
                  top: 58,
                  left: 0,
                  right: 0,
                  bottom: 112,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _categories.length,
                    onPageChanged: (index) {
                      setState(() => _selectedCategory = index);
                    },
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category.icon,
                            size: 132,
                            color: AppColors.espresso.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${category.label.toUpperCase()}  ${index + 1}/${_categories.length}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.espresso,
                            ),
                          ),
                        ],
                      );
                    },
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
                          backgroundColor: AppColors.cream.withValues(
                            alpha: 0.9,
                          ),
                          foregroundColor: AppColors.espresso,
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
                            backgroundColor: AppColors.cream.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: AppColors.espresso,
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
                            backgroundColor: AppColors.cream.withValues(
                              alpha: 0.9,
                            ),
                            foregroundColor: AppColors.espresso,
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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.espresso],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TODAY'S LOOK",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outfit.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (outfit.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            outfit.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < _categories.length; index++)
              Expanded(
                child: IconButton.filledTonal(
                  tooltip: _categories[index].label,
                  onPressed: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: _selectedCategory == index
                        ? AppColors.tan
                        : AppColors.beige,
                    foregroundColor: _selectedCategory == index
                        ? AppColors.cream
                        : AppColors.taupe,
                  ),
                  icon: Icon(_categories[index].icon),
                ),
              ),
            IconButton(
              tooltip: outfit.complete ? 'Mark as planned' : 'Mark complete',
              onPressed: widget.onToggleComplete,
              icon: Icon(
                outfit.complete
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: AppColors.tan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutfitCategory {
  const _OutfitCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({required this.dayName, required this.onTap});

  final String dayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.beige,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppColors.tan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Plan outfit for ${dayName.toLowerCase().substring(0, 1)}${dayName.toLowerCase().substring(1)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.taupe,
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
    required this.title,
    required this.description,
    required this.icon,
    required this.complete,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool complete;

  _PlannedOutfit copyWith({bool? complete}) => _PlannedOutfit(
    title: title,
    description: description,
    icon: icon,
    complete: complete ?? this.complete,
  );
}
