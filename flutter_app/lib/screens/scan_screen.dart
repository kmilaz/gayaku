import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../logic/color_extraction.dart';
import '../logic/garment_defaults.dart';
import '../logic/scan_pipeline.dart';
import '../models/wardrobe.dart';
import '../services/wardrobe_service.dart';
import '../state/wardrobe_store.dart';
import '../state/wardrobe_sync.dart';
import '../theme/app_theme.dart';

/// Runs the models over one photo. Injectable so widget tests can drive the
/// screen without loading real `.tflite` files.
typedef GarmentScanner = Future<ScanResult> Function(Uint8List photoBytes);

/// Gets photo bytes from the camera or the gallery.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Turns one photo of a garment into a wardrobe entry.
///
/// Mirrors the intended flow in `design/scanning_page.png`: pick a photo, watch
/// the matte and the classifier run, correct Category / Dominant colour / name,
/// then save the Cutout into the wardrobe (see docs/adr/0005-classify-the-cutout.md).
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.scanner,
    this.picker,
    this.documentsDirectory,
  });

  /// Defaults to the real on-device pipeline.
  final GarmentScanner? scanner;
  final PhotoPicker? picker;

  /// Where Cutouts are written. Injectable so tests do not need the platform
  /// channel behind `getApplicationDocumentsDirectory`.
  final Future<Directory> Function()? documentsDirectory;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// Models are loaded once per process: both are bundled assets, and loading
  /// them per scan would add a visible stall to every photo.
  static ScanPipeline? _pipeline;

  final _name = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _photo;
  ScanResult? _result;
  String? _error;

  String _category = wardrobeSlots.first;
  Color _color = const Color(0xFFD3A277);
  String _colorName = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<ScanResult> _scan(Uint8List bytes) async {
    final injected = widget.scanner;
    if (injected != null) return injected(bytes);
    final pipeline = _pipeline ??= await ScanPipeline.load();
    return pipeline.scan(bytes);
  }

  Future<Uint8List?> _pick(ImageSource source) async {
    final injected = widget.picker;
    if (injected != null) return injected(source);
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 92,
    );
    return file?.readAsBytes();
  }

  Future<void> _capture(ImageSource source) async {
    try {
      final bytes = await _pick(source);
      if (bytes == null) return;
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _result = null;
        _error = null;
      });
      await _run(bytes);
    } on ScanFailure catch (failure) {
      _fail(failure.message);
    } on Exception {
      _fail('Foto gagal dibuka. Coba pilih foto lain.');
    }
  }

  Future<void> _run(Uint8List bytes) async {
    try {
      final result = await _scan(bytes);
      if (!mounted) return;
      setState(() {
        _result = result;
        _category = result.category;
        _color = result.dominantColor;
        _colorName = result.colorName;
        _name.text = result.suggestedName;
      });
    } on ScanFailure catch (failure) {
      _fail(failure.message);
    } on Object catch (error, stack) {
      // A genuine defect rather than a user-actionable state: keep the trace in
      // the logs, show the user something honest.
      debugPrint('Scan failed: $error');
      debugPrint('$stack');
      _fail('Pemindaian gagal. Coba lagi.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _result = null;
    });
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) return;
    final name = _name.text.trim().isEmpty
        ? result.suggestedName
        : _name.text.trim();

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final id = newWardrobeItemId();
      final directory =
          await (widget.documentsDirectory ??
              getApplicationDocumentsDirectory)();
      final folder = Directory('${directory.path}/garments');
      await folder.create(recursive: true);
      final cutout = File('${folder.path}/$id.png');
      await cutout.writeAsBytes(result.cutoutPng);

      await saveWardrobeItem(
        WardrobeItem(
          id: id,
          name: name,
          category: _category,
          subcategory: result.label,
          imagePath: cutout.path,
          colorName: _colorName,
          color: _color,
          formality: defaultFormality(_category),
          occasions: defaultOccasions(_category),
        ),
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$name tersimpan di Wardrobe')),
      );
    } on FileSystemException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan gambar potongan.')),
      );
    } on WardrobeException catch (e) {
      // Backend menolak (RLS, sesi habis): jangan pura-pura tersimpan.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.of(context).sheet,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => _OptionSheet<String>(
        title: 'Pilih category',
        options: [for (final slot in wardrobeSlots) (label: slot, value: slot)],
        selected: _category,
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _editColor() async {
    final picked = await showModalBottomSheet<(String, Color)>(
      context: context,
      backgroundColor: AppColors.of(context).sheet,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => _OptionSheet<(String, Color)>(
        title: 'Pilih warna',
        options: [
          for (final (name, color) in colorNames)
            (label: name, value: (name, color)),
        ],
        selected: (_colorName, _color),
        swatches: true,
      ),
    );
    if (picked != null) {
      setState(() {
        _colorName = picked.$1;
        _color = picked.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final result = _result;

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
                    _TopBar(title: 'Add New Item'),
                    const SizedBox(height: 16),
                    _ScanCard(
                      photo: _photo,
                      cutoutPng: result?.cutoutPng,
                      status: _status(result),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PickButton(
                          icon: Icons.photo_camera_outlined,
                          tooltip: 'Ambil foto',
                          onTap: () => _capture(ImageSource.camera),
                        ),
                        const SizedBox(width: 16),
                        _PickButton(
                          icon: Icons.photo_library_outlined,
                          tooltip: 'Pilih dari galeri',
                          onTap: () => _capture(ImageSource.gallery),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorNote(message: _error!),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        'AI DETECTED DETAILS',
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          letterSpacing: 1.1,
                          color: palette.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: palette.sheet,
                          borderRadius: AppRadius.panel,
                          boxShadow: const [AppDecorations.panelShadow],
                        ),
                        child: Column(
                          children: [
                            _DetailRow(
                              icon: Icons.checkroom_outlined,
                              label: 'Category',
                              value: _category,
                              onEdit: _editCategory,
                            ),
                            Divider(height: 1, color: palette.canvas),
                            _DetailRow(
                              icon: Icons.palette_outlined,
                              label: 'Warna',
                              value: _colorName,
                              swatch: _color,
                              onEdit: _editColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Nama item',
                          filled: true,
                          fillColor: palette.sheet,
                          border: const OutlineInputBorder(
                            borderRadius: AppRadius.field,
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Terdeteksi: ${result.label} • '
                        '${(result.confidence * 100).round()}% yakin',
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(color: palette.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (result != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Simpan ke Wardrobe'),
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

  String _status(ScanResult? result) {
    if (_error != null) return 'Pemindaian gagal';
    if (result != null) return 'Pakaian terdeteksi';
    if (_photo != null) return 'Memindai item...';
    return 'Siap memindai';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
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
            title,
            style: Theme.of(context).textTheme.titleLarge!
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// The photo under the corner guides, swapping to the Cutout once it exists.
class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.photo,
    required this.cutoutPng,
    required this.status,
  });

  final Uint8List? photo;
  final Uint8List? cutoutPng;
  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final image = cutoutPng ?? photo;

    return Container(
      height: 306,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: AppRadius.hero,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: AppRadius.panel,
            child: image == null
                ? Center(
                    child: Icon(
                      Icons.checkroom_outlined,
                      size: 120,
                      color: palette.accentInk,
                    ),
                  )
                : Image.memory(image, fit: BoxFit.cover),
          ),
          if (photo != null) const CustomPaint(painter: _CornerGuides()),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xCC000000),
                borderRadius: AppRadius.pill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four L-shaped brackets, as drawn in the scanning mockup.
class _CornerGuides extends CustomPainter {
  const _CornerGuides();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const arm = 22.0;
    final w = size.width;
    final h = size.height;
    for (final (corner, dx, dy) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(w, 0), -1.0, 1.0),
      (Offset(0, h), 1.0, -1.0),
      (Offset(w, h), -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner.translate(arm * dx, 0), paint);
      canvas.drawLine(corner, corner.translate(0, arm * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerGuides oldDelegate) => false;
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 26),
      color: palette.ink,
      style: IconButton.styleFrom(
        backgroundColor: palette.sheet,
        minimumSize: const Size(56, 56),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: palette.actionInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium!
                  .copyWith(color: palette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
    this.swatch,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? swatch;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accentTint,
            child: Icon(icon, size: 19, color: palette.accentInk),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.labelSmall!.copyWith(color: palette.inkMuted),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (swatch != null) ...[
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: swatch,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.inkMuted,
                            width: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
        ],
      ),
    );
  }
}

/// Bottom sheet of single-choice options, radio styled like the wardrobe's.
class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    this.swatches = false,
  });

  final String title;
  final List<({String label, T value})> options;
  final T selected;
  final bool swatches;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
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
                  title,
                  style: Theme.of(context).textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option.value == selected;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(option.value),
                  leading: swatches
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: (option.value as (String, Color)).$2,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.inkMuted),
                          ),
                        )
                      : Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? palette.actionInk
                              : palette.inkMuted,
                        ),
                  title: Text(option.label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
