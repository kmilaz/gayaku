# A detector finds the garments, the classifier names each one

**Status**: accepted — supersedes ADR-0005, which assumed one garment per photo. ADR-0001 (on-device inference), ADR-0003 (training data) and ADR-0006 (YOLOv8, AGPL-3.0) stand.

ADR-0005 opened with "the scanner accepts a single flat-lay or hanger photo, so it runs no object detector". That assumption is wrong for the product: a normal photo can hold a shirt, trousers and shoes at once, and the owner's reason for choosing YOLO was to handle exactly that. With today's pipeline a photo with two garments produces **one** item: the matting model merges the two silhouettes into a single cutout and the classifier answers one label for the pair. What ADR-0005 recorded as a scope line is a defect once the photo contains more than one item.

## Decision

Two models, two jobs, and neither one absorbs the other's:

1. **A YOLOv8 detector finds boxes.** It answers *where* and a coarse **Category** — one of the five from `CONTEXT.md` (Tops, Bottoms, Outerwear, Shoes, Accessories), which is exactly the vocabulary `labels.json` already uses. It does not predict the fine class.
2. **The 18-class classifier names the crop inside each box** — the model measured at 81.55 % top-1 on the merged test split (`docs/adr/0008`) is reused unchanged as this stage.
3. **Per box, the existing steps follow**: crop the photo to the box with a margin, matte the crop with `u2netp`, read the Dominant colour from that cutout. The order becomes detect → crop → matte + classify + colour, instead of matte → classify on a single cutout.

The coarse Category is what keeps the detector cheap. Naming a box `Polo` requires box annotations for all 18 classes, and no public dataset has them; naming it `Tops` is what Fashionpedia, DeepFashion2 and ModaNet all already annotate, so the detector can be trained from whichever of them the licence allows — and several can be merged, the way `merge_datasets.py` merged the classification sources.

## Training data

`Fashionpedia` (Kaggle/HuggingFace mirrors of the ECCV 2020 release): 46,781 photographs, 342,182 bounding boxes, **annotations licensed CC BY 4.0**, images stay under the terms of the sites they came from (Flickr, Unsplash, Burst, Pexels, …). Its categories cover what the app needs, including `shoe`, `hat`, `bag, wallet`, `watch`, `glasses`, and the garments; its 19 *garment part* categories (`hood`, `collar`, `sleeve`, `pocket`, `zipper`, …) are **parts of an item, not items**, and a conversion must drop them or the detector learns to box sleeves.

The mapping onto the five Categories follows `labels.json`, not intuition — `sweater` and `cardigan` are Outerwear there, `dress` and `jumpsuit` are Tops, `vest` is Outerwear (Waistcoat). The conversion script writes the table it applied into its manifest, as `merge_datasets.py` does, so the detector's classes can be audited against the label table.

## Consequences

* **The scan produces a list, not an item.** `ScanResult` becomes several results; the review screen shows every detected garment with its own crop, label, confidence and colour; one photo can add several `WardrobeItem`s. This is a product change the owner has asked for, and it changes the UI contract, not just the model.
* **NMS and thresholds become product behaviour.** A jacket worn over a shirt is legitimately two boxes, so the overlap rule has to allow containment rather than suppressing one of the two. The Correction step is still what fixes a wrong split.
* **Detection accuracy and naming accuracy are reported separately**: mAP50 on the boxes, then the classifier's per-class recall on the crops. Neither number hides the other.
* **A second model in the APK.** `yolov8n` detection at 640 px is a few MB, which the ADR-0005 budget (u2netp 5–9 MB) has to absorb; the asset table in `ml_workspace/README.md` gains a row.
* **Training that stage on this CPU has not been measured.** Classification was 67 ms per photograph at 224 px; detection trains at 640 px over 46k images, and it will not be 2.3 hours. Measure before promising a date, and expect the GPU question (Kaggle, whose notebook already exists for the classifier) to return for this stage only.
* **Garments worn on a body stay hard.** The detector will find the box; matting a worn garment still cuts the wrong silhouette, which is what the `pleated_midi_skirt` sweep photograph shows. Detection does not fix that, and the Correction step remains the answer.
* **Licence posture**: Ultralytics-trained weights are AGPL-3.0 (ADR-0006); Fashionpedia's annotations are CC BY 4.0 and need attribution if the annotations are redistributed; its photographs keep their source terms. Weights and builds stay coursework artifacts (ADR-0003, ADR-0007).

## Result (the first run)

Trained on a Kaggle T4 from the capped tree (`--max-boxes-per-category 2000`, `docs/adr/0011`): 4,030 train
photographs and 10,000 boxes, with validation (1,158) and test (2,000) kept whole so the numbers measure
the model rather than the cap. About 2.5 minutes per epoch at 640 px for 40 epochs; early stopping never
fired.

| `test` | all | Tops | Bottoms | Outerwear | Shoes | Accessories |
|---|---|---|---|---|---|---|
| mAP50 | 0.7081 | 0.792 | 0.787 | 0.781 | 0.800 | **0.382** |
| mAP50-95 | 0.5417 | 0.625 | 0.657 | 0.657 | 0.538 | 0.223 |
| recall | 0.696 | 0.661 | 0.870 | 0.853 | 0.754 | **0.343** |

* **`Accessories` is the weak slot, and the merge is why.** Thirteen unrelated item categories (bag, belt, tie, hat, sock, watch, glasses, umbrella, â€¦) share one output, so a bag competes with a belt for the same class. Merging them was right for the app's five Categories and wrong for the detector's signal: 0.382 AP50 against 0.78-0.80 everywhere else. Either the slot splits into Bag/Hat/Other later, or the review screen treats its boxes as advisory.
* **Export contract**: `garment_detector.tflite`, 12,767,821 bytes, input `[1,3,640,640]` float32 **NCHW**, output `[1,9,8400]` float32 (4 box coordinates and 5 class scores, no objectness), 256 operators. `scan_pipeline.dart` already packs NCHW through `rgbaToNchwFloats`, so the detector needs no new layout work on the Dart side. The copy produced by the commit run has sha256 `72d2ba68â€¦`; a retrain re-exports different weights, so the hash identifies the file, not the recipe.
* **A capped tree was enough for a first detector.** 4,030 photographs reached mAP50 0.7081 and cost 35 minutes of T4 time, which is what makes iterating on the Category list affordable at all.

## Measured on flat-lays, which is what the app asks the user for

The detector learned from Fashionpedia, whose photographs are garments worn by people. Run on the
app's own flat-lay assets, with the same letterbox and the same `[1,9,8400]` decode the app uses
(`.amp/in/check_detector.py`, `ai-edge-litert`):

| photo | boxes above 0.25 | what survives the same-Category rule |
|---|---|---|
| one jacket (`beige_trench.jpg`) | 10, all `Outerwear` on the same spot | 1 item, correct |
| one pair of shoes (`classic_sneakers.jpg`) | 4, all labelled `Tops` | 1 item, **wrong Category** |
| one bag (`tote_bag_canvas.jpg`) | **0**; the best score is 0.191, labelled `Tops` | no item at all |

So a flat-lay holding several garments yields one item: the big outerwear scores 0.86-0.89 and
survives, while the rest fall under the threshold or carry the wrong Category. This is a domain
gap, not a threshold to tune — lowering the cut-off to 0.15 makes the bag appear as `Tops` at 0.191.
Fixing it means training the detector on flat-lay photographs, which is a data decision, not a
parameter.

## Considered options

* **Keep ADR-0005** (one garment per photo, no detector): the pipeline already works and the classifier is measured, but the product cannot accept a normal photo. Rejected by the owner: it contradicts why YOLO was chosen.
* **One detector with all 18 fine classes**: the app would need no second stage, but it needs box annotations for 18 classes that no public dataset has, and it would discard the classifier we just trained and measured.
* **A single-class "garment" detector**: avoids the Category mapping, but the app could not tell shoes from a jacket before classifying a crop, so matting and outfit matching would lose the signal they already have. The five slots cost almost nothing more.
* **ModaNet first**: 55k street photographs with polygons, but CC BY-NC 4.0 — non-commercial — and street scenes are the hardest case for matting.
* **DeepFashion2 first**: 491k images and 801k boxes, the most complete option, but access runs through a request form, and 491k images is far more than a first detector needs.

## Open

* **`Accessories` stays one slot for now** (settled): 0.382 AP50 against 0.78-0.80 for the garment slots is the evidence for splitting it into Bag, Hat and Other, but the 18 classes have no bag to classify a detected bag as, so splitting the detector alone would not fix the name. It is flagged by default in the review screen (`docs/multi-item-scan.md`) and splits when bag detection arrives as a class of its own.
* **The confidence and IoU thresholds the app uses.** The training run reports AP, not the operating point the review screen should adopt; they come from a sweep on real photographs, and `docs/multi-item-scan.md` keeps them marked pending until then.
* **The multi-item review UI**, which is the owner's design decision, not a model one; the contract is written and its open questions are listed there.

Settled since this ADR was accepted: the first detector trains on Fashionpedia, and it trained on a GPU (Kaggle T4) rather than this CPU.
