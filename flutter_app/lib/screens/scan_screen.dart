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

/// Runs the models over one photo and returns every garment the detector found.
typedef GarmentScannerAll = Future<List<ScanResult>> Function(
  Uint8List photoBytes,
);

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
    this.scannerAll,
    this.picker,
    this.documentsDirectory,
  });

  /// Defaults to the real on-device pipeline.
  final GarmentScanner? scanner;

  /// Preferred over [scanner]: one photo, several garments. [scanner] stays for the
  /// single-item tests that predate detection.
  final GarmentScannerAll? scannerAll;
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

  final _picker = ImagePicker();

  Uint8List? _photo;

  /// One entry per garment the detector found, in the order the pipeline returned it:
  /// largest box first (`docs/multi-item-scan.md`).
  final List<_Draft> _drafts = [];
  int _index = 0;
  String? _error;

  _Draft? get _current =>
      _drafts.isEmpty ? null : _drafts[_index.clamp(0, _drafts.length - 1)];

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<List<ScanResult>> _scan(Uint8List bytes) async {
    final many = widget.scannerAll;
    if (many != null) return many(bytes);
    final single = widget.scanner;
    if (single != null) return [await single(bytes)];
    final pipeline = _pipeline ??= await ScanPipeline.load();
    return pipeline.scanAll(bytes);
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
        for (final draft in _drafts) {
          draft.dispose();
        }
        _drafts.clear();
        _index = 0;
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
      final results = await _scan(bytes);
      if (!mounted) return;
      setState(() {
        for (final draft in _drafts) {
          draft.dispose();
        }
        _drafts
          ..clear()
          ..addAll(results.map(_Draft.new));
        _index = 0;
        _error = null;
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
      for (final draft in _drafts) {
        draft.dispose();
      }
      _drafts.clear();
      _index = 0;
    });
  }

  /// Writes every remaining item: one cutout file and one row each, in the order the
  /// carousel showed them. Deleting an item first is the way to leave one out
  /// (`docs/multi-item-scan.md`).
  Future<void> _save() async {
    if (_drafts.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final label = _drafts.length == 1
        ? _nameOf(_drafts.single)
        : '${_drafts.length} item';
    try {
      final directory =
          await (widget.documentsDirectory ??
              getApplicationDocumentsDirectory)();
      final folder = Directory('${directory.path}/garments');
      await folder.create(recursive: true);
      for (final draft in _drafts) {
        final id = newWardrobeItemId();
        final cutout = File('${folder.path}/$id.png');
        await cutout.writeAsBytes(draft.result.cutoutPng);

        await saveWardrobeItem(
          WardrobeItem(
            id: id,
            name: _nameOf(draft),
            category: draft.category,
            subcategory: draft.result.label,
            imagePath: cutout.path,
            colorName: draft.colorName,
            color: draft.color,
            formality: defaultFormality(draft.category),
            occasions: defaultOccasions(draft.category),
          ),
        );
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$label tersimpan di Wardrobe')),
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

  String _nameOf(_Draft draft) {
    final typed = draft.name.text.trim();
    return typed.isEmpty ? draft.result.suggestedName : typed;
  }

  Future<void> _editCategory() async {
    final draft = _current;
    if (draft == null) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.of(context).sheet,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => _OptionSheet<String>(
        title: 'Pilih category',
        options: [for (final slot in wardrobeSlots) (label: slot, value: slot)],
        selected: draft.category,
      ),
    );
    if (picked != null) setState(() => draft.category = picked);
  }

  Future<void> _editColor() async {
    final draft = _current;
    if (draft == null) return;
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
        selected: (draft.colorName, draft.color),
        swatches: true,
      ),
    );
    if (picked != null) {
      setState(() {
        draft.colorName = picked.$1;
        draft.color = picked.$2;
      });
    }
  }

  /// Drops the garment on screen. Only possible before saving: a wrongly named row in the
  /// wardrobe is worse than one the user threw away.
  void _deleteCurrent() {
    final draft = _current;
    if (draft == null) return;
    setState(() {
      _drafts.remove(draft);
      draft.dispose();
      if (_index >= _drafts.length) {
        _index = _drafts.isEmpty ? 0 : _drafts.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final draft = _current;

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
                      cutoutPng: draft?.result.cutoutPng,
                      box: draft?.result.box,
                      status: _status(),
                    ),
                    if (draft != null && _drafts.length > 1) ...[
                      const SizedBox(height: 10),
                      _CarouselBar(
                        index: _index,
                        total: _drafts.length,
                        onPrevious: _index == 0
                            ? null
                            : () => setState(() => _index -= 1),
                        onNext: _index >= _drafts.length - 1
                            ? null
                            : () => setState(() => _index += 1),
                      ),
                    ],
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
                    if (draft != null) ...[
                      const SizedBox(height: 20),
                      if (draft.flagged) ...[
                        _FlagNote(name: _nameOf(draft)),
                        const SizedBox(height: 10),
                      ],
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
                              value: draft.category,
                              onEdit: _editCategory,
                            ),
                            Divider(height: 1, color: palette.canvas),
                            _DetailRow(
                              icon: Icons.palette_outlined,
                              label: 'Warna',
                              value: draft.colorName,
                              swatch: draft.color,
                              onEdit: _editColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: draft.name,
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
                        'Terdeteksi: ${draft.result.label} • '
                        '${(draft.result.confidence * 100).round()}% yakin',
                        style: Theme.of(context).textTheme.labelMedium!
                            .copyWith(color: palette.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _deleteCurrent,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Hapus item ini'),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (draft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      _drafts.length == 1
                          ? 'Simpan ke Wardrobe'
                          : 'Simpan ${_drafts.length} item',
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

  String _status() {
    if (_error != null) return 'Pemindaian gagal';
    if (_drafts.length > 1) return '${_drafts.length} pakaian terdeteksi';
    if (_drafts.length == 1) return 'Pakaian terdeteksi';
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
    this.box,
  });

  final Uint8List? photo;
  final Uint8List? cutoutPng;

  /// The garment on screen, in fractions of [photo]. Present once the detector has run;
  /// the photo stays visible so the user can see which garment the carousel is on.
  final Rect? box;
  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final image = box == null ? (cutoutPng ?? photo) : photo;

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
                : _BoxedPhoto(photo: image, box: box),
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

/// The photo with the current garment outlined, so a multi-item scan shows which box the
/// details below belong to.
class _BoxedPhoto extends StatelessWidget {
  const _BoxedPhoto({required this.photo, required this.box});

  final Uint8List photo;
  final Rect? box;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final rect = box;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(photo, fit: BoxFit.cover),
            if (rect != null)
              Positioned(
                left: rect.left * width,
                top: rect.top * height,
                width: rect.width * width,
                height: rect.height * height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.accentInk, width: 3),
                    borderRadius: AppRadius.field,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One scanned garment plus the edits the user is making before saving.
class _Draft {
  _Draft(this.result)
    : name = TextEditingController(text: result.suggestedName),
      category = result.category,
      color = result.dominantColor,
      colorName = result.colorName;

  final ScanResult result;
  final TextEditingController name;
  String category;
  Color color;
  String colorName;

  /// Worth a second look: the classifier was unsure, or the detector called it an accessory.
  ///
  /// Accessories are flagged whatever the score says, because the detector cannot tell a bag
  /// from a belt and the class list holds no bag (`docs/multi-item-scan.md`).
  bool get flagged =>
      result.confidence < flagConfidenceThreshold ||
      result.detectedCategory == 'Accessories';

  void dispose() => name.dispose();
}

/// Provisional, and deliberately conservative: the contract keeps the real threshold pending
/// until it is measured per class on a phone.
const flagConfidenceThreshold = 0.6;

/// Previous / next through the scanned garments, with "n of m" between them.
class _CarouselBar extends StatelessWidget {
  const _CarouselBar({
    required this.index,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Item sebelumnya',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: 22),
          color: palette.ink,
          style: IconButton.styleFrom(
            backgroundColor: palette.sheet,
            minimumSize: const Size(40, 40),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '${index + 1} dari $total',
            style: Theme.of(context).textTheme.labelMedium!
                .copyWith(color: palette.inkMuted),
          ),
        ),
        IconButton(
          tooltip: 'Item berikutnya',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, size: 22),
          color: palette.ink,
          style: IconButton.styleFrom(
            backgroundColor: palette.sheet,
            minimumSize: const Size(40, 40),
          ),
        ),
      ],
    );
  }
}

/// Says the name may be wrong without blocking the save, per the review contract.
class _FlagNote extends StatelessWidget {
  const _FlagNote({required this.name});

  final String name;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: palette.accentInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nama "$name" mungkin belum tepat. Kamu tetap bisa menyimpannya, dan '
              'mengubah nama atau Category-nya nanti di Wardrobe.',
              style: Theme.of(context).textTheme.labelMedium!
                  .copyWith(color: palette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
