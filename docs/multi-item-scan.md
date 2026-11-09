# Multi-item scan contract

What the scanner owes the app once detection is in front of the classifier. This is a
contract, not an implementation: it fixes the data each item carries, the order the user
sees them in, and what happens when a stage fails, so the screen and the pipeline can be
built separately without drifting.

Decided by ADR-0009 (detection is in scope) and ADR-0010 (the 18-class classifier ships as
the second stage). Numbers marked **pending** come from the detector run and are recorded in
`ml_workspace/yolo/artifacts/detector/report.md` when it finishes — the detector's own
`report.md`, kept in that subfolder so it does not overwrite the classifier's. Nothing here
may be filled in by guesswork.

## Pipeline

One photo in, a list of garments out. Each stage has one job:

| Stage | Answers | Model | Failure mode |
| --- | --- | --- | --- |
| Detect | Where are the garments, and which Category is each? | `yolov8n` detection, 5 Categories | No box above threshold → "no garment" |
| Crop + matte | What pixels are the garment alone? | `u2netp_320.tflite` on the box crop | Empty matte → drop this item, keep the rest |
| Classify | Which of the 18 classes? | `garment_classifier.tflite` | Off-list index → drop this item, keep the rest |
| Read colour | Which Dominant colour, and what is it called? | `color_extraction.dart`, on the matte | Unreadable → keep the item, leave the colour empty |

The order is fixed by ADR-0005 as amended by ADR-0009. Classification never sees the whole
photo: it sees the item's cutout, because that is the framing its training data had.

## What one detected item carries

`ScanResult` today holds exactly one garment. The contract replaces it with a session that
holds many, and each item keeps the same fields plus the two the detector adds:

| Field | Type | Source | Notes |
| --- | --- | --- | --- |
| `box` | `Rect` in photo fractions, 0..1 | detector | Stored so the review screen can outline the item on the photo |
| `detectedCategory` | one of 5 Categories | detector | Coarse; may disagree with the classifier's Category |
| `detectorConfidence` | `double` | detector | Kept for the review screen and for audit, not shown as a percentage |
| `label` | one of 18 class keys | classifier | `garmentCategories` order; never a display name |
| `suggestedName` | `String` | `garmentLabelName[label]` | The only place a display name is derived |
| `category` | one of 5 Categories | `garmentLabelCategory[label]` | Wins over `detectedCategory`: it is the finer model |
| `confidence` | `double` 0..1 | classifier | Softmax of the winning class |
| `cutoutPng` | `Uint8List` | matte | Becomes the `WardrobeItem` image |
| `dominantColor`, `colorName` | `Color`, `String` | colour pass | `colorName` may be empty when the pass failed |

Two Category fields on purpose. The detector only has five outputs, so it cannot tell
`Kaos` from `Kemeja`; the classifier cannot see a second garment. When the two disagree, the
classifier's finer answer is what the `WardrobeItem` stores, and the disagreement is not
surfaced to the user — it is only logged in the review screen's debug view.

## How items are ordered and deduplicated

1. **Order**: descending box area, so the garment that fills the frame comes first. Reading
   order (top-to-bottom, left-to-right) was rejected: a jacket on a hanger and shoes at the
   foot of the bed tie, and the order flips when the photo is retaken.
2. **Containment is allowed.** A jacket over a shirt produces two boxes on purpose; that is
   the product value of the whole change.
3. **Duplicates collapse**: two boxes of the same Category with IoU above 0.85 keep the
   larger one. Detection commonly emits both "the garment" and "the garment plus its
   sleeve" for the same object.
4. **Cap at 6 items.** Items beyond the cap are dropped, largest first, and the review screen
   says how many were left out. 6 keeps the review screen scannable on a 6-inch phone;
   raising it is a UI decision, not a pipeline one.
5. **Maximum overlap of the photo**: at most 3 items may overlap any pixel, otherwise the
   photo is rejected as ambiguous rather than half-read. **pending** — this needs measuring
   on real photos, not on Fashionpedia.

## What the review screen shows

**One item at a time, as a carousel** (the owner's choice over a vertical list). The photo fills
the top with the current item's box outlined, and the card below it carries the cutout, the
suggested name, its Category, the colour swatch with `colorName`, and the confidence as a
percentage. Swiping, or the previous/next buttons, moves to the next item in pipeline order;
the last screen holds the save action and the "n of m" indicator. The trade-off is deliberate:
three garments cost three swipes, and the screen stays readable on a phone where three stacked
cards would not. Copy comes from `design/`; this contract does not invent user-facing wording.

Three states per item, and the card is the same in all of them. A fourth trigger marks an item
whatever the classifier said: **`detectedCategory == Accessories` is flagged by default**, because
the detector cannot tell a bag from a belt (0.382 AP50 against 0.78-0.80 for the garment slots) and
the 18 classes have no bag at all, so its name is the least trustworthy on the screen.

* **Classified** — `confidence` at or above the flag threshold.
* **Flagged** — `confidence` below it. The card says the name may be wrong, offers the label
  picker, **and still lets the user save**. Saving is the owner's decision: forcing the picker
  on every uncertain item would turn a three-garment scan into three dialogs. The warning is
  not dismissed with the screen — the saved `WardrobeItem` keeps a badge, and the wardrobe
  tells the user the name and Category can be changed at any time. **pending**: threshold,
  from the classifier's per-class recall in `ml_workspace/yolo/artifacts/report.md`; a single
  global cut is wrong because `Kaos_Lengan_Panjang` (33.3 % recall) and `Sepatu` (98.6 %)
  cannot share one.
* **Unclassified** — classification failed but the cutout exists. The name field is empty,
  the picker is required before saving, and the item is saved only if the user chooses a
  label. Dropping it silently is rejected: a cutout the detector found is real even when the
  classifier cannot name it.

Actions per card: change the label (picker over all 18), change the name (free text), delete
the item. **Delete before save, not "ignore after save"** — a wrongly named garment in the
wardrobe is worse than one the user threw away.

## Session-level states

| State | Trigger | What the user sees |
| --- | --- | --- |
| No garment | Every box below the detector threshold | The existing "no garment" message; no review screen |
| Too many | More than 6 boxes above threshold | Review screen with the 6 largest, plus the count left out |
| Partial | Some items dropped by matte/classify failure | Review screen with the survivors and a count of the ones dropped |
| Detector unavailable | Detector asset missing or its tensors do not match | Falls back to the single-item pipeline (whole-photo matte, one classification) so the app stays usable; the review screen shows one item |
| Everything failed | No cutout survived | The existing model-unavailable message |

The fallback exists because the detector is the newest model in the build. A build without
it must still scan, and the fallback is the code path that ships today.

## What changes in code

Types only; no implementation in this document.

* `ScanResult` becomes `ScanSession { photoBytes, items: List<ScanResult> }`, and `ScanResult`
  gains `box`, `detectedCategory` and `detectorConfidence`.
* `ScanPipeline` gains a detector interpreter and a list-returning `scan()`; the current
  single-item `scan()` survives as the fallback path.
* `WardrobeItem` does not change: one item per garment, one row per item. Saving a session
  writes N rows in one transaction.
* `checkContracts()` gains the detector's tensor contract, in the same style as the two models
  it already checks: input `[1,3,640,640]` float32 **NCHW**, output `[1,9,8400]` float32 (four
  box coordinates and five class scores, no objectness). Both come from the exported
  `garment_detector.tflite` (12,767,821 bytes, sha256 `72d2ba68â€¦`), not from the documentation.

## What the first detector measured

`test` split, 2,000 photographs and 6,970 boxes (`docs/adr/0009`):

| Category | mAP50 | recall | consequence for this contract |
|---|---|---|---|
| Tops | 0.792 | 0.661 | boxes are reliable; classification decides the name |
| Bottoms | 0.787 | 0.870 | highest recall of the five |
| Outerwear | 0.781 | 0.853 | containment with Tops works, as designed |
| Shoes | 0.800 | 0.754 | best AP of the five |
| Accessories | **0.382** | **0.343** | treat these boxes as advisory, or split the Category later |

`Accessories` merges thirteen unrelated item categories, so a bag and a belt compete for one class. Until
that slot splits, an `Accessories` box that never reaches the review screen costs the user an accessory
rather than a garment; that is the acceptable failure mode for this version, and it is the reason the item cap
exists at all.

## Not covered

* **Worn garments.** The detector's training data is Fashionpedia, which is worn fashion, so
  it will fire on a person. Phase 2 is flat-lay photographs of single garments on a plain
  background, which is what the training data looks like. Do not claim worn-photo support
  until a run measures it.
* **A second item of the same Category in one photo** (two shirts side by side). Allowed by
  the contract, likely misnamed by the classifier; measure before promising it.
* **Labels outside the 18 classes.** Sunglasses, bags and belts will be forced into one of
  the 18. The picker lets the user fix it; auto-detecting "not a garment" is phase 3.
* **Thresholds themselves.** They are the detector's and the classifier's, not the UI's; the
  UI reads them from one place so a re-trained model does not need a screen change.

## Settled by the owner

* **Cap: 6 items per scan**, largest boxes first, with a count of what was left out.
* **Carousel review**: one item at a time over the photo, not a vertical list.
* **A flagged item may be saved** with a visible warning; the `WardrobeItem` keeps the badge and a
  note that the name and Category can be edited later.
* **`Accessories` stays one Category** for now and is flagged by default rather than split. It
  splits only when bag detection arrives as a class of its own.
* **`Kaos_Lengan_Panjang` stays as trained** (33.3 % recall, 9 of 21 test photographs predicted
  `Sweter`). Flipping the source preference trades one problem for another without new data, so
  the decision waits for what the owner sees on a phone.
