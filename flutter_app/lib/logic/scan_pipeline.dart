/// The Smart Scanner pipeline: photo in, detected garment out.
///
/// Order is frozen by docs/adr/0005-classify-the-cutout.md — matte, then
/// classify the Cutout, then read its Dominant colour. Everything runs
/// on-device; the photo never leaves the phone (docs/adr/0001).
///
/// Both models are ordinary `.tflite` files driven through `tflite_flutter`:
/// - matting: U-2-Net small (`u2netp_320.tflite`), `[1,320,320,3]` NHWC RGB in
///   `[0,1]`, first output is the `[1,320,320,1]` mask;
/// - classifier: our own export, `[1,224,224,3]` NHWC RGB in `[0,1]` with
///   normalisation baked in, softmax output in `garmentCategories` order.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'color_extraction.dart';
import 'garment_defaults.dart';
import 'garment_labels.dart';

/// Square size the matting model expects.
const mattingInputSize = 320;

/// Square size the classifier expects.
const classifierInputSize = 224;

/// Square size the detector expects, and what its output is shaped like.
///
/// `garment_detector.tflite` takes `[1,3,640,640]` float32 NCHW and returns `[1,9,8400]`
/// float32: four box coordinates followed by five Category scores, no objectness term.
/// The numbers are read from the exported file, not assumed (`docs/adr/0009`).
const detectorInputSize = 640;
const detectorClassCount = 5;
const detectorAnchors = 8400;
const detectorAttributes = 4 + detectorClassCount;

/// Below this score a box is not worth a crop; above this overlap two boxes of the *same*
/// Category are the same garment seen twice.
///
/// Starting values from the detection contract, not a sweep on real photographs yet: the
/// contract keeps both marked pending until they are measured on a phone (`docs/multi-item-scan.md`).
const detectorScoreThreshold = 0.25;

/// Two boxes of the same Category overlapping more than this are the same garment.
///
/// Set from a measurement, not a round number: on a seated person the model produced two
/// `Bottoms` boxes over the same lap at IoU 0.79, and both reached the review screen.
const detectorDuplicateIou = 0.85;

/// Most garments one scan shows; the rest are dropped from the smallest (`docs/multi-item-scan.md`).
const maxScanItems = 6;

/// Longest edge of the photo we decode. A 12 MP phone photo costs ~48 MB of
/// RGBA and buys no accuracy these models can use, so we downscale on ingest.
const maxDecodeEdge = 1600;

/// Raised for anything the user can act on: no garment in frame, missing model.
class ScanFailure implements Exception {
  const ScanFailure(this.message);

  /// Indonesian, shown to the user as-is.
  final String message;

  @override
  String toString() => 'ScanFailure: $message';
}

/// Everything one Scan produced, ready for the review screen.
class ScanResult {
  const ScanResult({
    required this.cutoutPng,
    required this.dominantColor,
    required this.colorName,
    required this.label,
    required this.category,
    required this.suggestedName,
    required this.confidence,
    this.box,
    this.detectedCategory,
  });

  /// PNG with a transparent background — becomes the WardrobeItem's image.
  final Uint8List cutoutPng;
  final Color dominantColor;
  final String colorName;

  /// Fine garment type the classifier predicted, e.g. `Jeans`.
  final String label;

  /// The one Category the fine [label] maps down to.
  final String category;

  /// Indonesian name suggested for the item's name field.
  final String suggestedName;

  /// Softmax score of the winning class, 0..1.
  final double confidence;

  /// Where the detector found this garment, in fractions of the photo.
  ///
  /// Null on the single-item fallback, where the crop comes from the matte instead.
  final Rect? box;

  /// The detector's coarse Category, which may disagree with the classifier's [category].
  ///
  /// The classifier wins when they do: it saw the cutout, the detector saw the whole photo
  /// (`docs/multi-item-scan.md`).
  final String? detectedCategory;

  /// Formality the item starts with, from its Category.
  int get formality => defaultFormality(category);

  /// Occasions the item starts with, from its Category.
  List<String> get occasions => defaultOccasions(category);
}

/// Runs both models over one photo.
///
/// Use [load] in the app; construct directly in tests to inject interpreters
/// pointing at fixture models.
class ScanPipeline {
  ScanPipeline({
    required this.matting,
    required this.classifier,
    this.detector,
  });

  final Interpreter matting;
  final Interpreter classifier;

  /// Finds the garments. Optional: a build without the asset falls back to the single-item
  /// matte-then-classify path, which is what shipped before detection existed.
  final Interpreter? detector;

  /// Loads the bundled models and checks they match the generated label list.
  ///
  /// A missing or unreadable asset surfaces as its own [ScanFailure]: it is a
  /// build problem, not something the user can retry away.
  static Future<ScanPipeline> load() async {
    try {
      final pipeline = ScanPipeline(
        matting: await Interpreter.fromAsset('assets/models/u2netp_320.tflite'),
        classifier: await Interpreter.fromAsset(
          'assets/models/garment_classifier.tflite',
        ),
        detector: await _loadDetector(),
      );
      pipeline.checkContracts();
      return pipeline;
    } on ScanFailure {
      rethrow;
    } on Object {
      throw const ScanFailure(
        'Model pemindai tidak tersedia di build ini. Ekspor model dari '
        'ml_workspace/ lalu build ulang aplikasi.',
      );
    }
  }

  void close() {
    matting.close();
    classifier.close();
    detector?.close();
  }

  /// The detector asset is optional by contract, so a missing one means "single-item path"
  /// rather than a build error. A present but incompatible one still fails [checkContracts].
  static Future<Interpreter?> _loadDetector() async {
    try {
      return await Interpreter.fromAsset(
        'assets/models/garment_detector.tflite',
      );
    } on Object {
      return null;
    }
  }

  /// Fails loudly rather than mislabelling every garment by one index.
  void checkContracts() {
    final classes = classifier.getOutputTensor(0).shape.last;
    if (classes != garmentCategories.length) {
      throw ScanFailure(
        'Model klasifikasi punya $classes kelas, label aplikasi punya '
        '${garmentCategories.length}. Jalankan ulang '
        'ml_workspace/scripts/gen_dart_labels.py.',
      );
    }
    for (final (name, tensor, size) in [
      ('matting', matting.getInputTensor(0), mattingInputSize),
      ('classifier', classifier.getInputTensor(0), classifierInputSize),
    ]) {
      requireSquareRgbInput(tensor, size, name);
    }
    for (final (name, type) in [
      ('matting input', matting.getInputTensor(0).type),
      ('matting output', matting.getOutputTensor(0).type),
      ('classifier input', classifier.getInputTensor(0).type),
      ('classifier output', classifier.getOutputTensor(0).type),
    ]) {
      if (type != TensorType.float32 && type != TensorType.float16) {
        // Quantised IO would silently produce garbage through the byte path.
        throw ScanFailure('$name bertipe $type, bukan float.');
      }
    }

    final localDetector = detector;
    if (localDetector == null) return;
    requireSquareRgbInput(
      localDetector.getInputTensor(0),
      detectorInputSize,
      'detector',
    );
    final output = localDetector.getOutputTensor(0).shape;
    final expected = [1, detectorAttributes, detectorAnchors];
    if (output.length != 3 ||
        output[0] != expected[0] ||
        output[1] != expected[1] ||
        output[2] != expected[2]) {
      throw ScanFailure(
        'Output detektor berbentuk $output, kontraknya $expected. Ekspor ulang '
        'garment_detector.tflite dari ml_workspace/yolo/.',
      );
    }
    for (final (name, type) in [
      ('detector input', localDetector.getInputTensor(0).type),
      ('detector output', localDetector.getOutputTensor(0).type),
    ]) {
      if (type != TensorType.float32 && type != TensorType.float16) {
        throw ScanFailure('$name bertipe $type, bukan float.');
      }
    }
  }

  /// Runs the detector, then the per-garment steps, and returns every garment it could
  /// read. Empty when the detector finds nothing above its score threshold.
  ///
  /// Each item costs its own crop, matte and classification pass, which is why the list is
  /// capped by [maxScanItems] rather than left open-ended.
  Future<List<ScanResult>> scanAll(Uint8List photoBytes) async {
    final photo = await _decode(photoBytes, maxEdge: maxDecodeEdge);
    final boxes = await _detect(photoBytes);
    final results = <ScanResult>[];
    for (final detected in selectScanBoxes(boxes)) {
      final item = await _itemFor(photo, detected.box, detected.category);
      // One unreadable crop drops that garment, not the scan (`docs/multi-item-scan.md`).
      if (item != null) results.add(item);
    }
    return results;
  }

  /// Runs the whole pipeline over [photoBytes] (JPEG or PNG) and returns the largest garment.
  ///
  /// With a detector this is [scanAll] without the list; without one it is the single-item
  /// path that shipped before detection.
  Future<ScanResult> scan(Uint8List photoBytes) async {
    if (detector != null) {
      final items = await scanAll(photoBytes);
      if (items.isEmpty) {
        throw const ScanFailure(
          'Pakaian tidak terdeteksi. Coba foto ulang dengan latar yang lebih polos.',
        );
      }
      return items.first;
    }

    final photo = await _decode(photoBytes, maxEdge: maxDecodeEdge);
    final mask = await _matte(photoBytes);
    final box = maskBoundingBox(mask, mattingInputSize);
    if (box == null) {
      throw const ScanFailure(
        'Pakaian tidak terdeteksi. Coba foto ulang dengan latar yang lebih polos.',
      );
    }
    final item = await _itemFor(
      photo,
      Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      null,
      mask: mask,
    );
    if (item == null) {
      throw const ScanFailure(
        'Warna pakaian tidak terbaca. Coba foto dengan pencahayaan lebih terang.',
      );
    }
    return item;
  }

  /// One box through crop, matte, colour and classifier. Null when the crop yields nothing
  /// usable, so a bad box cannot take the rest of the scan down with it.
  Future<ScanResult?> _itemFor(
    ({Uint8List rgba, int width, int height}) photo,
    Rect box,
    String? detectedCategory, {
    Float32List? mask,
  }) async {
    final crop = cropRgba(photo.rgba, photo.width, photo.height, (
      left: box.left,
      top: box.top,
      right: box.right,
      bottom: box.bottom,
    ));
    final cropPng = await _encodePng(crop.rgba, crop.width, crop.height);
    final usedMask = mask ?? await _matte(cropPng);
    final cutoutPng = await _encodePng(
      premultipliedCutout(
        crop.rgba,
        crop.width,
        crop.height,
        usedMask,
        mattingInputSize,
      ),
      crop.width,
      crop.height,
    );
    final dominant = dominantColorFromRgba(
      garmentPixels(
        crop.rgba,
        crop.width,
        crop.height,
        usedMask,
        mattingInputSize,
      ),
    );
    if (dominant == null) return null;

    final prediction = await _classifyCutout(cutoutPng);
    if (prediction.index >= garmentCategories.length) {
      throw ScanFailure(
        'Model mengembalikan kelas ${prediction.index} di luar daftar label.',
      );
    }
    final label = garmentCategories[prediction.index];
    final fromClassifier = garmentLabelCategory[label];
    if (fromClassifier == null) {
      throw ScanFailure(
        'Label "$label" belum dipetakan ke Category. Perbarui '
        'ml_workspace/labels.json lalu jalankan ulang generatornya.',
      );
    }
    // The detector saw the whole photo and boxed one garment; the classifier saw only this
    // crop. When they disagree the detector wins the Category, because a wrong Category moves
    // the item to the wrong wardrobe tab and changes the outfit rules, while the classifier's
    // contribution is the name (`docs/multi-item-scan.md`).
    final category = detectedCategory ?? fromClassifier;

    return ScanResult(
      cutoutPng: cutoutPng,
      dominantColor: dominant.color,
      colorName: dominant.name,
      label: label,
      category: category,
      suggestedName: garmentLabelName[label] ?? label,
      confidence: prediction.confidence,
      box: box,
      detectedCategory: detectedCategory,
    );
  }

  /// The detector over a letterboxed copy of the photo, decoded into boxes in photo fractions.
  Future<List<DetectedBox>> _detect(Uint8List photoBytes) async {
    final localDetector = detector;
    if (localDetector == null) return const [];

    final probe = await _decode(photoBytes);
    final canvas = letterboxDetectorInput(
      probe.rgba,
      probe.width,
      probe.height,
    );
    final inputTensor = localDetector.getInputTensor(0);
    final outputTensor = localDetector.getOutputTensor(0);
    final sink = Uint8List(outputTensor.numBytes());
    runModel(
      localDetector,
      floatsToInputBytes(
        rgbaToInputFloats(canvas.rgba, detectorInputSize, inputTensor.shape),
        inputTensor.type,
      ),
      sink,
    );
    final boxes = decodeDetectorOutput(outputFloats(sink, outputTensor.type));
    return [
      for (final detected in boxes)
        DetectedBox(
          box: detectorBoxToPhoto(detected.box, canvas),
          categoryIndex: detected.categoryIndex,
          score: detected.score,
        ),
    ];
  }

  /// Matting mask in `[0,1]`, `mattingInputSize * mattingInputSize` values.
  ///
  /// The photo is squashed to a square first: that is what U-2-Net was trained
  /// on, and the bounding box is mapped back onto the un-squashed photo.
  Future<Float32List> _matte(Uint8List photoBytes) async {
    final small = await _decode(
      photoBytes,
      width: mattingInputSize,
      height: mattingInputSize,
    );
    final inputTensor = matting.getInputTensor(0);
    final outputTensor = matting.getOutputTensor(0);
    final sink = Uint8List(outputTensor.numBytes());
    runModel(
      matting,
      floatsToInputBytes(
        rgbaToInputFloats(small.rgba, mattingInputSize, inputTensor.shape),
        inputTensor.type,
      ),
      sink,
    );
    return outputFloats(sink, outputTensor.type);
  }

  /// Classifies the Cutout: the model sees a background-free garment, which is
  /// exactly the framing its training data had.
  Future<({int index, double confidence})> _classifyCutout(
    Uint8List cutoutPng,
  ) async {
    final square = await _decode(
      cutoutPng,
      width: classifierInputSize,
      height: classifierInputSize,
    );
    final outputTensor = classifier.getOutputTensor(0);
    final inputTensor = classifier.getInputTensor(0);
    final classes = garmentCategories.length;
    final input = rgbaToInputFloats(
      square.rgba,
      classifierInputSize,
      inputTensor.shape,
    );
    final sink = Uint8List(outputTensor.numBytes());
    runModel(classifier, floatsToInputBytes(input, inputTensor.type), sink);

    final scores = probabilitiesFrom(
      outputFloats(sink, outputTensor.type),
      classes,
    );
    var best = 0;
    for (var i = 1; i < classes; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return (index: best, confidence: scores[best].toDouble());
  }

  Future<({Uint8List rgba, int width, int height})> _decode(
    Uint8List bytes, {
    int? width,
    int? height,
    int? maxEdge,
  }) async {
    var targetWidth = width;
    if (maxEdge != null) {
      final probe = await ui.instantiateImageCodec(bytes);
      final frame = await probe.getNextFrame();
      final longest = math.max(frame.image.width, frame.image.height);
      frame.image.dispose();
      probe.dispose();
      if (longest > maxEdge) targetWidth = maxEdge;
    }

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final decodedWidth = image.width;
    final decodedHeight = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    codec.dispose();
    image.dispose();
    if (data == null) {
      throw const ScanFailure('Foto tidak bisa dibaca. Coba pilih foto lain.');
    }
    return (
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: decodedWidth,
      height: decodedHeight,
    );
  }

  Future<Uint8List> _encodePng(Uint8List rgba, int width, int height) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw const ScanFailure('Hasil potongan gagal disimpan.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

// ---------------------------------------------------------------------------
// Pure helpers — unit-tested directly, no models needed.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Detector output — pure helpers, unit-tested with synthetic tensors.
// ---------------------------------------------------------------------------

/// The five Categories the detector's output indices mean, in output order.
///
/// Same vocabulary as `CONTEXT.md`, and the same order the conversion script writes into the
/// model's manifest, so index 0 is always Tops.
const detectorCategories = [
  'Tops',
  'Bottoms',
  'Outerwear',
  'Shoes',
  'Accessories',
];

/// One garment the detector found, as a rectangle in fractions of the photo (0..1).
class DetectedBox {
  const DetectedBox({
    required this.box,
    required this.categoryIndex,
    required this.score,
  });

  final Rect box;

  /// Index into [detectorCategories].
  final int categoryIndex;
  final double score;

  String get category => detectorCategories[categoryIndex];

  double get area => box.width * box.height;
}

/// Reads the detector's `[9, 8400]` output into boxes, largest first.
///
/// Layout read from the exported file: one row per attribute (centre x, centre y, width,
/// height, then one score per Category), column per anchor, all already normalised and
/// sigmoid-applied. Boxes below [scoreThreshold] are dropped, and boxes of the *same*
/// Category overlapping more than [overlapThreshold] collapse to the higher score — a garment
/// worn under another one is a different Category, so it survives.
List<DetectedBox> decodeDetectorOutput(
  Float32List raw, {
  double scoreThreshold = detectorScoreThreshold,
  double overlapThreshold = detectorDuplicateIou,
  int classCount = detectorClassCount,
  int anchors = detectorAnchors,
}) {
  if (raw.length < anchors * (4 + classCount)) {
    throw ScanFailure(
      'Output detektor berisi ${raw.length} nilai, diminta ${anchors * (4 + classCount)}.',
    );
  }

  final candidates = <DetectedBox>[];
  for (var anchor = 0; anchor < anchors; anchor++) {
    var bestClass = -1;
    var bestScore = 0.0;
    for (var cls = 0; cls < classCount; cls++) {
      final score = raw[(4 + cls) * anchors + anchor];
      if (score > bestScore) {
        bestScore = score;
        bestClass = cls;
      }
    }
    if (bestClass < 0 || bestScore < scoreThreshold) continue;

    final centerX = raw[anchor];
    final centerY = raw[anchors + anchor];
    final width = raw[anchors * 2 + anchor];
    final height = raw[anchors * 3 + anchor];
    if (width <= 0 || height <= 0) continue;

    final left = (centerX - width / 2).clamp(0.0, 1.0);
    final top = (centerY - height / 2).clamp(0.0, 1.0);
    final right = (centerX + width / 2).clamp(0.0, 1.0);
    final bottom = (centerY + height / 2).clamp(0.0, 1.0);
    if (right - left <= 0 || bottom - top <= 0) continue;

    candidates.add(
      DetectedBox(
        box: Rect.fromLTRB(left, top, right, bottom),
        categoryIndex: bestClass,
        score: bestScore,
      ),
    );
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final kept = <DetectedBox>[];
  for (final candidate in candidates) {
    var duplicate = false;
    for (final survivor in kept) {
      if (survivor.categoryIndex != candidate.categoryIndex) continue;
      if (boxIou(survivor.box, candidate.box) > overlapThreshold) {
        duplicate = true;
        break;
      }
    }
    if (!duplicate) kept.add(candidate);
  }

  kept.sort((a, b) => b.area.compareTo(a.area));
  return kept;
}

/// A 640 px canvas the detector can read, with the photo scaled to fit and centred.
///
/// Ultralytics trained on letterboxed images, so squashing the photo to a square would feed
/// the model a shape it never saw. The padding is what [detectorBoxToPhoto] undoes.
({
  Uint8List rgba,
  int contentLeft,
  int contentTop,
  int contentWidth,
  int contentHeight,
})
letterboxDetectorInput(Uint8List rgba, int width, int height) {
  final scale = detectorInputSize / (width > height ? width : height);
  final contentWidth = (width * scale).round().clamp(1, detectorInputSize);
  final contentHeight = (height * scale).round().clamp(1, detectorInputSize);
  final padLeft = (detectorInputSize - contentWidth) ~/ 2;
  final padTop = (detectorInputSize - contentHeight) ~/ 2;

  final canvas = Uint8List(detectorInputSize * detectorInputSize * 4);
  // Ultralytics pads with grey 114; matching it keeps the border neutral instead of bright.
  for (var i = 0; i < canvas.length; i += 4) {
    canvas[i] = 114;
    canvas[i + 1] = 114;
    canvas[i + 2] = 114;
    canvas[i + 3] = 255;
  }
  for (var y = 0; y < contentHeight; y++) {
    final sourceY = (y * height) ~/ contentHeight;
    for (var x = 0; x < contentWidth; x++) {
      final sourceX = (x * width) ~/ contentWidth;
      final from = (sourceY * width + sourceX) * 4;
      final to = ((y + padTop) * detectorInputSize + (x + padLeft)) * 4;
      canvas[to] = rgba[from];
      canvas[to + 1] = rgba[from + 1];
      canvas[to + 2] = rgba[from + 2];
      canvas[to + 3] = 255;
    }
  }
  return (
    rgba: canvas,
    contentLeft: padLeft,
    contentTop: padTop,
    contentWidth: contentWidth,
    contentHeight: contentHeight,
  );
}

/// A box in canvas fractions, mapped back onto the photo it was letterboxed from.
Rect detectorBoxToPhoto(
  Rect box,
  ({
    Uint8List rgba,
    int contentLeft,
    int contentTop,
    int contentWidth,
    int contentHeight,
  })
  canvas,
) {
  double map(double value, int offset, int size) =>
      ((value * detectorInputSize - offset) / size).clamp(0.0, 1.0);
  return Rect.fromLTRB(
    map(box.left, canvas.contentLeft, canvas.contentWidth),
    map(box.top, canvas.contentTop, canvas.contentHeight),
    map(box.right, canvas.contentLeft, canvas.contentWidth),
    map(box.bottom, canvas.contentTop, canvas.contentHeight),
  );
}

/// Intersection over union of two boxes in the same coordinate space.
double boxIou(Rect a, Rect b) {
  final overlap = a.intersect(b);
  if (overlap.width <= 0 || overlap.height <= 0) return 0;
  final intersection = overlap.width * overlap.height;
  final union = a.width * a.height + b.width * b.height - intersection;
  return union <= 0 ? 0 : intersection / union;
}

/// The boxes one scan shows: largest first, at most [maxItems].
List<DetectedBox> selectScanBoxes(
  List<DetectedBox> boxes, {
  int maxItems = maxScanItems,
}) {
  final ordered = [...boxes]..sort((a, b) => b.area.compareTo(a.area));
  return ordered.take(maxItems).toList(growable: false);
}

/// RGBA bytes to interleaved NHWC floats in `[0,1]`.
Float32List rgbaToNhwcFloats(Uint8List rgba, int size) {
  final pixels = size * size;
  final out = Float32List(pixels * 3);
  for (var i = 0; i < pixels; i++) {
    out[i * 3] = rgba[i * 4] / 255;
    out[i * 3 + 1] = rgba[i * 4 + 1] / 255;
    out[i * 3 + 2] = rgba[i * 4 + 2] / 255;
  }
  return out;
}

/// RGBA bytes to planar NCHW floats in `[0,1]` — the layout some exporters
/// (LiteRT's PyTorch-tracing path among them) produce.
Float32List rgbaToNchwFloats(Uint8List rgba, int size) {
  final plane = size * size;
  final out = Float32List(plane * 3);
  for (var i = 0; i < plane; i++) {
    out[i] = rgba[i * 4] / 255;
    out[plane + i] = rgba[i * 4 + 1] / 255;
    out[plane * 2 + i] = rgba[i * 4 + 2] / 255;
  }
  return out;
}

/// RGBA to floats in whichever square-RGB layout [shape] declares, so a model
/// exported as NHWC or NCHW both work without touching this file.
Float32List rgbaToInputFloats(Uint8List rgba, int size, List<int> shape) {
  if (shape.length == 4 && shape[3] == 3) return rgbaToNhwcFloats(rgba, size);
  if (shape.length == 4 && shape[1] == 3) return rgbaToNchwFloats(rgba, size);
  throw ScanFailure('Bentuk input $shape bukan NHWC atau NCHW RGB.');
}

/// Rejects a model whose input is not a square RGB image of [size] in either
/// layout, naming the model so the message points at the right file.
void requireSquareRgbInput(Tensor tensor, int size, String model) {
  final shape = tensor.shape;
  final nhwc =
      shape.length == 4 &&
      shape[1] == size &&
      shape[2] == size &&
      shape[3] == 3;
  final nchw =
      shape.length == 4 &&
      shape[1] == 3 &&
      shape[2] == size &&
      shape[3] == size;
  if (!nhwc && !nchw) {
    throw ScanFailure(
      'Input model $model bukan ${size}x$size RGB NHWC/NCHW (bentuk: $shape).',
    );
  }
}

/// Tightest box holding every mask value at or above [threshold], as fractions
/// of [size] so it maps onto any resolution. Null when the matte is empty —
/// i.e. the photo held no salient garment.
({double left, double top, double right, double bottom})? maskBoundingBox(
  Float32List mask,
  int size, {
  double threshold = 0.5,
  double margin = 0.03,
}) {
  var minX = size, minY = size, maxX = -1, maxY = -1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (mask[y * size + x] < threshold) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0 || maxY < 0) return null;

  return (
    left: math.max(0.0, minX / size - margin),
    top: math.max(0.0, minY / size - margin),
    right: math.min(1.0, (maxX + 1) / size + margin),
    bottom: math.min(1.0, (maxY + 1) / size + margin),
  );
}

/// Cuts the mask's box out of a full-resolution RGBA image.
({Uint8List rgba, int width, int height}) cropRgba(
  Uint8List rgba,
  int width,
  int height,
  ({double left, double top, double right, double bottom}) box,
) {
  final x0 = (box.left * width).round().clamp(0, width - 1);
  final y0 = (box.top * height).round().clamp(0, height - 1);
  final x1 = (box.right * width).round().clamp(x0 + 1, width);
  final y1 = (box.bottom * height).round().clamp(y0 + 1, height);
  final cropWidth = x1 - x0;
  final cropHeight = y1 - y0;
  final out = Uint8List(cropWidth * cropHeight * 4);
  for (var y = 0; y < cropHeight; y++) {
    out.setRange(
      y * cropWidth * 4,
      (y + 1) * cropWidth * 4,
      rgba,
      ((y0 + y) * width + x0) * 4,
    );
  }
  return (rgba: out, width: cropWidth, height: cropHeight);
}

/// Writes the matte into the crop's alpha channel and premultiplies the colour,
/// because `ui.PixelFormat.rgba8888` expects premultiplied bytes. Used only for
/// the PNG we save.
Uint8List premultipliedCutout(
  Uint8List cropRgba,
  int cropWidth,
  int cropHeight,
  Float32List mask,
  int maskSize,
) {
  final out = Uint8List(cropRgba.length);
  for (var y = 0; y < cropHeight; y++) {
    final maskRow =
        math.min(maskSize - 1, (y * maskSize) ~/ cropHeight) * maskSize;
    for (var x = 0; x < cropWidth; x++) {
      final alpha =
          mask[maskRow + math.min(maskSize - 1, (x * maskSize) ~/ cropWidth)]
              .clamp(0.0, 1.0);
      final i = (y * cropWidth + x) * 4;
      out[i] = (cropRgba[i] * alpha).round();
      out[i + 1] = (cropRgba[i + 1] * alpha).round();
      out[i + 2] = (cropRgba[i + 2] * alpha).round();
      out[i + 3] = (alpha * 255).round();
    }
  }
  return out;
}

/// Straight RGB with alpha 255 where the matte claims the pixel and alpha 0
/// elsewhere — the input for [dominantColorFromRgba], which ignores transparent
/// pixels. Kept separate from [premultipliedCutout] so the premultiplication
/// above cannot darken the sampled colours.
Uint8List garmentPixels(
  Uint8List cropRgba,
  int cropWidth,
  int cropHeight,
  Float32List mask,
  int maskSize, {
  double threshold = 0.5,
}) {
  final out = Uint8List(cropRgba.length);
  for (var y = 0; y < cropHeight; y++) {
    final maskRow =
        math.min(maskSize - 1, (y * maskSize) ~/ cropHeight) * maskSize;
    for (var x = 0; x < cropWidth; x++) {
      final inside =
          mask[maskRow + math.min(maskSize - 1, (x * maskSize) ~/ cropWidth)] >=
          threshold;
      final i = (y * cropWidth + x) * 4;
      out[i] = cropRgba[i];
      out[i + 1] = cropRgba[i + 1];
      out[i + 2] = cropRgba[i + 2];
      out[i + 3] = inside ? 255 : 0;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// tflite_flutter plumbing: models differ in tensor dtypes, so every buffer is
// allocated from the tensor itself rather than assumed.
// ---------------------------------------------------------------------------

/// Runs [interpreter] on raw [input] bytes and copies its first output into
/// [outputSink], which must be `tensor.numBytes()` long.
///
/// `Interpreter.run` is deliberately not used: it infers the input shape from
/// the object you hand it, so a flat typed list reads as shape `[n]`, and the
/// binding then tries to *resize* the model's fixed input tensor and fails.
/// Handing over bytes skips shape inference entirely.
void runModel(Interpreter interpreter, Uint8List input, Uint8List outputSink) {
  final expected = interpreter.getInputTensor(0).numBytes();
  if (input.length != expected) {
    throw ScanFailure(
      'Input model butuh $expected byte, dikirim ${input.length} byte.',
    );
  }
  interpreter.getInputTensor(0).setTo(input);
  interpreter.invoke();
  interpreter.getOutputTensor(0).copyTo(outputSink);
}

/// Float input as raw bytes in the tensor's dtype.
Uint8List floatsToInputBytes(Float32List values, TensorType type) {
  if (type == TensorType.float32) return float32Bytes(values);
  if (type == TensorType.float16) {
    final half = Uint16List(values.length);
    for (var i = 0; i < values.length; i++) {
      half[i] = floatToHalf(values[i]);
    }
    return half.buffer.asUint8List(half.offsetInBytes, half.lengthInBytes);
  }
  throw ScanFailure('Input model bertipe $type, bukan float.');
}

/// Raw bytes of a float buffer, without copying.
Uint8List float32Bytes(Float32List values) =>
    values.buffer.asUint8List(values.offsetInBytes, values.lengthInBytes);

/// Raw float bytes read back as floats, per the tensor's dtype.
Float32List outputFloats(Uint8List bytes, TensorType type) {
  if (type == TensorType.float32) return bytesToFloat32(bytes);
  if (type == TensorType.float16) {
    final half = bytes.buffer.asUint16List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    final out = Float32List(half.length);
    for (var i = 0; i < half.length; i++) {
      out[i] = halfToFloat(half[i]);
    }
    return out;
  }
  throw ScanFailure('Output model bertipe $type, bukan float.');
}

/// Raw float32 bytes as a view — no copy, so [bytes] must outlive the view.
Float32List bytesToFloat32(Uint8List bytes) =>
    bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);

/// The first [classes] scores as probabilities.
///
/// A model that exports logits instead of a softmax still has the right argmax
/// but meaningless confidence numbers, and the review screen prints that number
/// as a percentage — so anything that is not already a distribution is
/// normalised here rather than shown to the user as "1237%".
Float32List probabilitiesFrom(Float32List scores, int classes) {
  if (scores.length < classes) {
    throw ScanFailure(
      'Model mengembalikan ${scores.length} nilai untuk $classes kelas.',
    );
  }

  var sum = 0.0;
  var inRange = true;
  var max = scores[0];
  for (var i = 0; i < classes; i++) {
    final value = scores[i];
    if (value < -1e-6 || value > 1.0 + 1e-6) inRange = false;
    if (value > max) max = value;
    sum += value;
  }
  if (inRange && (sum - 1.0).abs() <= 0.2) {
    return Float32List.sublistView(scores, 0, classes);
  }

  final out = Float32List(classes);
  var total = 0.0;
  for (var i = 0; i < classes; i++) {
    final e = math.exp(scores[i] - max);
    out[i] = e;
    total += e;
  }
  if (total <= 0) {
    throw ScanFailure('Skor model tidak bisa dinormalkan.');
  }
  for (var i = 0; i < classes; i++) {
    out[i] = out[i] / total;
  }
  return out;
}

/// Float32 bits to IEEE-754 half precision.
int floatToHalf(double value) {
  final bits = (Float32List(1)..[0] = value).buffer.asUint32List()[0];
  final sign = (bits >> 16) & 0x8000;
  final exponent = ((bits >> 23) & 0xff) - 127 + 15;
  final mantissa = bits & 0x7fffff;
  if (exponent <= 0) return sign; // underflows to zero
  if (exponent >= 31) return sign | 0x7c00; // inf / nan
  return sign | (exponent << 10) | (mantissa >> 13);
}

double halfToFloat(int half) {
  final sign = (half & 0x8000) << 16;
  var exponent = (half >> 10) & 0x1f;
  var mantissa = half & 0x3ff;
  if (exponent == 0) {
    if (mantissa == 0) return _bitsToFloat(sign);
    while ((mantissa & 0x400) == 0) {
      mantissa <<= 1;
      exponent--;
    }
    exponent++;
    mantissa &= ~0x400;
  } else if (exponent == 31) {
    return _bitsToFloat(sign | 0x7f800000 | (mantissa << 13));
  }
  return _bitsToFloat(sign | ((exponent + 127 - 15) << 23) | (mantissa << 13));
}

double _bitsToFloat(int bits) =>
    Float32List.view(Uint32List.fromList([bits]).buffer)[0];
