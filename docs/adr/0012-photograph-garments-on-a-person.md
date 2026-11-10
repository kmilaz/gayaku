# The scanner takes photos of garments on a person

**Status**: accepted — changes the input contract that ADR-0005 and `docs/multi-item-scan.md` assumed. Builds on ADR-0009 (detector first) and ADR-0011 (the models that ship).

The app has been asking for a flat-lay — one garment laid out on a plain background — while the detector was trained on Fashionpedia, whose photographs are garments on people. Measured on the app's own flat-lay assets, the detector finds one box or none; measured on Fashionpedia-style photographs, it finds three to six. The owner's decision is to follow the model that works in the app's own training domain: **a photo of a person wearing the garments**.

## Decision

1. **The scan contract is a photograph of a person.** The UI guidance, the empty states and the demo photographs describe persons wearing clothes, not garments laid out.
2. **The classifier is retrained on boxes, not on whole photographs.** Its training set is built from the detector's own source: every Fashionpedia item box becomes one crop, labelled with the class its category maps to. Splitting is per photograph, so a person cannot appear in both train and test.
3. **The class list shrinks to what those boxes can label.** Fashionpedia carries no `Polo`, `Jeans`, `Blazer`, `Jaket_Denim`, `Jaket_Olahraga`, `Hoodie` or `Kaos_Lengan_Panjang` category, so those classes cannot be taught from it; the merges are listed below. This is a product-visible change and belongs in the same decision.
4. **`Accessories` boxes stay advisory.** Fashionpedia labels bags, belts, ties, glasses, watches and scarves separately, and the app's vocabulary holds none of them, so those boxes are not classified into a garment name.

## What the boxes can teach (train split, `--min-box-px 8`)

| Proposed class | Boxes | Fashionpedia categories folded in |
|---|---|---|
| Sepatu | 46,374 | `shoe` |
| Gaun | 19,661 | `dress`, `jumpsuit` |
| Kaos | 16,548 | `top, t-shirt, sweatshirt` (sweatshirt and hoodie included) |
| Celana_Panjang | 12,414 | `pants` (jeans included) |
| Jaket | 7,833 | `jacket` |
| Kemeja | 6,161 | `shirt, blouse` |
| Rok | 5,046 | `skirt` |
| Mantel | 3,276 | `coat`, `cape` |
| Celana_Pendek | 2,756 | `shorts` |
| Sweter | 2,601 | `sweater`, `cardigan` |
| Topi | 2,518 | `hat` |
| Rompi | 719 | `vest` |
| **Total** | **125,907** | |

Dropped on purpose: the 19 part categories (`sleeve`, `collar`, `pocket`, `zipper`, …) and every
accessory category, because neither has a garment class in the app.

## What was actually cut

`ml_workspace/scripts/fashionpedia_crops.py` caps every class at **2,000 crops** (1,600 / 200 / 200
across train / val / test) so the twelve classes weigh the same in training and no class can fill
`val` or `test` by itself. On the 45,623 training photographs that yields **22,719 crops**:

| Class | train | val | test | total |
|---|---|---|---|---|
| Celana_Panjang | 1,600 | 200 | 200 | 2,000 |
| Celana_Pendek | 1,600 | 200 | 200 | 2,000 |
| Gaun | 1,600 | 200 | 200 | 2,000 |
| Jaket | 1,600 | 200 | 200 | 2,000 |
| Kaos | 1,600 | 200 | 200 | 2,000 |
| Kemeja | 1,600 | 200 | 200 | 2,000 |
| Mantel | 1,600 | 200 | 200 | 2,000 |
| Rok | 1,600 | 200 | 200 | 2,000 |
| Rompi | 557 | 86 | 76 | 719 |
| Sepatu | 1,600 | 200 | 200 | 2,000 |
| Sweter | 1,600 | 200 | 200 | 2,000 |
| Topi | 1,600 | 200 | 200 | 2,000 |
| **Total** | **18,157** | **2,286** | **2,276** | **22,719** |

`Rompi` is the only class that cannot reach the cap: the whole set holds 719 vest boxes. Splits are
assigned per photograph, so the 76 test crops of a class come from 76 photographs no training crop
touches.

## Consequences

* **The 18-class model is replaced by a smaller vocabulary**, so `garment_labels.dart` and the Dart contract change with it, and stored `WardrobeItem`s may carry labels the new model no longer produces. Reading an old label stays possible; predicting it does not.
* **Flat-lay support is dropped**, not hidden: the empty state and the copy say what to photograph. A flat-lay still scans — the pipeline does not refuse it — but the results are as weak as measured in ADR-0009.
* **The matte is the next weak stage.** On a worn garment it includes hands, hair and background, which is why a black pair of trousers reads as `Beige`. That is a separate decision (crop-tightening, skin masking, or a different matting model), and it is not solved by this ADR.
* **Colour names become the least reliable field on the card**, so the review screen must keep the manual colour picker reachable and treat a detected colour as a suggestion.
* **The detector's per-Category accuracy stays as measured** (mAP50 0.7081, `Accessories` 0.382) because its training data does not change.
