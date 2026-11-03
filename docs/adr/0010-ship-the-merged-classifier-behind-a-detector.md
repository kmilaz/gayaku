# The scanner ships the 18-class classifier behind a detector

**Status**: accepted — withdraws ADR-0003's claim that the 80-class catalogue model is the final classifier. Builds on ADR-0008 (the merged 18-class set) and ADR-0009 (detection before classification).

Three candidate end states were on the table at once: the 80-class catalogue model (ADR-0003), the 18-class merged classifier (ADR-0008), and a detector in front of a classifier (ADR-0009). Two of them pointed at the same app in different shapes, so nobody could say which model deserved the next hour, and the catalogue model had never been trained at all. This ADR settles it.

## Decision

1. **The shipped scanner is the detector plus the 18-class classifier.** `yolov8n` detection answers *where* and a coarse Category; for each box the pipeline crops, mattes, classifies one of the 18 classes, and reads the Dominant colour. `docs/multi-item-scan.md` is the contract for what the screen then shows.
2. **The 18 classes are the product's vocabulary.** Changing or adding one is an ADR, because it changes `garment_labels.dart` and every stored `WardrobeItem` label at once (`gen_dart_labels.py` already refuses a list the asset does not match).
3. **The catalogue pipeline is retired as a target, not deleted.** `scripts/prepare_data.py`, `kaggle/fashion_classifier.ipynb` and `artifacts/classes.json` stay as the documented path to a wider vocabulary if the product ever needs 80 classes; nothing in the app depends on them.
4. **The classifier asset is not swapped on its own.** It becomes the second stage of the two-stage pipeline, so it ships when that pipeline does — a classifier-only swap would lock in the single-item UX this direction replaces.

## Consequences

* **Three model files ship**: `u2netp_320.tflite` (matte), `garment_classifier.tflite` (18 classes), and the detector. The APK budget in ADR-0005 covered one matting model plus one classifier; the third file has to be measured against it.
* **ADR-0003 no longer describes what ships.** The CC0 photographs are not a temporary stand-in any more: they are part of the merged 18-class training set (`docs/adr/0008`), and the coursework-only licence posture carries over unchanged (ADR-0003, ADR-0007).
* **The 80-class artifacts remain evidence, not a plan.** Their `report.md` and confusion matrices still document what the catalogue looked like; they are no longer the next model.
* **Measurement burden moves to the detector.** The classifier's per-class recall is known (81.55 % top-1, macro-F1 0.7968 on 992 photographs); detection's mAP50 per Category is the number the two-stage pipeline now depends on, and it does not exist until the GPU run finishes.
* **Both YOLO models keep the AGPL-3.0 obligation** (ADR-0006): shipping either in a release build requires offering the corresponding source, and this repository still has no `LICENSE` file.

## Considered options

* **The 80-class catalogue model** (ADR-0003): the widest vocabulary, but English labels that would need translating anyway, 41,369 photographs spread over 80 classes, and it was never trained.
* **The 18-class classifier alone**: better naming than the shipped 10-class model (81.55 % versus 45.26 % on the same test photographs), but still one garment per photo.
* **Two classifiers, choose at runtime**: two assets and no signal to choose with before a prediction exists.
* **Keep both directions open**: this is what produced the confusion; rejected because it costs a decision every time someone picks up the work.
