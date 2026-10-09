import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';

class AddItemStub extends StatefulWidget {
  const AddItemStub({super.key});

  @override
  State<AddItemStub> createState() => _AddItemStubState();
}

class _AddItemStubState extends State<AddItemStub> {
  final _nameController = TextEditingController(text: 'Summer Blouse');
  var _category = 'Tops';
  var _color = 'Beige';
  var _isScanning = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _editCategory() async {
    final value = await _chooseValue('Category', [
      'Tops',
      'Bottoms',
      'Outerwear',
      'Shoes',
      'Accessories',
    ], _category);
    if (value != null) setState(() => _category = value);
  }

  Future<void> _editColor() async {
    final value = await _chooseValue('Color', [
      'Beige',
      'Black',
      'White',
      'Brown',
      'Blue',
      'Green',
    ], _color);
    if (value != null) setState(() => _color = value);
  }

  Future<String?> _chooseValue(
    String title,
    List<String> values,
    String selected,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.warmBackground,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.espresso,
                )),
              ),
            ),
            for (final value in values)
              ListTile(
                leading: Icon(
                  value == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: value == selected ? AppColors.tan : AppColors.taupe,
                ),
                title: Text(value),
                onTap: () => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _saveItem() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an item name first')),
      );
      return;
    }
    Navigator.of(context).pop(
      WardrobeItem(
        name: name,
        category: _category,
        imagePath: 'assets/images/scanned_item.jpg',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  const Expanded(
                    child: Center(child: _PageTitle()),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              _ScannerFrame(
                isScanning: _isScanning,
                onCapture: () => setState(() => _isScanning = !_isScanning),
              ),
              const SizedBox(height: 28),
              Text(
                'AI DETECTED DETAILS',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  letterSpacing: 1.1,
                  color: AppColors.taupe,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  boxShadow: [AppDecorations.panelShadow],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.checkroom,
                      label: 'Category',
                      value: _category,
                      onEdit: _editCategory,
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.palette_outlined,
                      label: 'Color',
                      value: _color,
                      onEdit: _editColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                style: GoogleFonts.inter(color: AppColors.espresso),
                decoration: InputDecoration(
                  labelText: 'Item name',
                  labelStyle: GoogleFonts.inter(color: AppColors.taupe),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveItem,
                  icon: const Icon(Icons.check),
                  label: const Text('Save to Wardrobe'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.tan,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
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

class _PageTitle extends StatelessWidget {
  const _PageTitle();

  @override
  Widget build(BuildContext context) => Text(
        'Add New Item',
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.espresso,
        ),
      );
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({required this.isScanning, required this.onCapture});

  final bool isScanning;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Container(
        height: 306,
        decoration: BoxDecoration(
          color: AppColors.imageSurface,
          borderRadius: BorderRadius.circular(34),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.scannerSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.white, width: 4),
              ),
              child: const Center(
                child: Icon(Icons.checkroom, size: 150, color: AppColors.tan),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.espresso.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  isScanning ? 'Scanning item...' : 'Ready to scan',
                  style: GoogleFonts.inter(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: IconButton(
                onPressed: onCapture,
                tooltip: 'Capture item',
                icon: const Icon(Icons.camera_alt_outlined, size: 28),
                color: AppColors.espresso,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.white,
                  minimumSize: const Size(68, 68),
                ),
              ),
            ),
            const Positioned(
              left: 16,
              bottom: 18,
              child: Icon(Icons.flash_off_outlined, color: AppColors.espresso),
            ),
            const Positioned(
              right: 16,
              bottom: 18,
              child: Icon(Icons.flip_camera_android_outlined,
                  color: AppColors.espresso),
            ),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.accentSurface,
              child: Icon(icon, color: AppColors.tan, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.taupe,
                  )),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.espresso,
                  )),
                ],
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: Text('Edit', style: GoogleFonts.inter(color: AppColors.tan)),
            ),
          ],
        ),
      );
}
