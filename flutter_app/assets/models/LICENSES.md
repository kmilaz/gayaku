# Model licences

Every model bundled in the APK must be Apache-2.0, MIT or BSD (see
`docs/adr/0002-permissive-model-licences.md`). This file records what each shipped `.tflite`
is, where it came from, and what it hashes to. Regenerate the numbers with
`python ml_workspace/scripts/tflite_io.py <file>`.

## `u2netp_320.tflite` — matting

| | |
|---|---|
| Model | U²-Net small (`u2netp`), salient-object / background-removal matting, 320×320 |
| Licence | **Apache-2.0** — © the U²-Net authors |
| Upstream project | https://github.com/xuebinqin/U-2-Net (Apache-2.0) |
| Downloaded from | https://huggingface.co/abhimanyu666/u2nettflite/resolve/main/u2netp.tflite (repository declares `license: apache-2.0`; a format conversion of the upstream weights, no architectural change) |
| sha256 | `558136589a47e97f53944ac3f65ba56f4efb5f6bae8e92b573e7c463d20fdb58` |
| Size | 4,575,464 bytes (4.6 MB) |
| Flatbuffer | TFL3, schema v3, producer `MLIR Converted.`, subgraph 0, 274 operators |
| Input | `serving_default_input.1:0` — `[1, 320, 320, 3]` float32, NHWC RGB in `[0, 1]` |
| Outputs | 7 tensors, all `[1, 320, 320, 1]` float32; output 0 `PartitionedCall:1` is the fused saliency mask in `[0, 1]` |

Get it with `python ml_workspace/scripts/fetch_matting_model.py`. A GitHub-only mirror of
the same conversion: https://github.com/PINTO0309/PINTO_model_zoo (061_U-2-Net).

## `garment_classifier.tflite` — garment classifier

Names the garment inside a box the detector found. **Shipped today is the 12-class
worn-garment model** (`docs/adr/0012`): it was trained on Fashionpedia item crops, the same
photographs the detector saw, so both stages agree about what a scan looks like. The 18-class
merged model (`docs/adr/0008`) it replaced is still in `ml_workspace/yolo/artifacts/` as the
previous generation.

| | |
|---|---|
| Model | Ultralytics YOLOv8n-cls fine-tuned to 12 classes at 224×224 |
| Licence | **AGPL-3.0** — Ultralytics weights trained by us (`docs/adr/0006`); coursework artifact, not for redistribution |
| Training data | `detection-datasets/fashionpedia` item boxes cut by `ml_workspace/scripts/fashionpedia_crops.py`: 22,719 crops, capped at 2,000 per class, split per photograph 18,157 / 2,286 / 2,276 (`docs/adr/0012`) |
| Measured on `test` | top-1 **0.6784**, top-5 0.9631, macro-F1 0.6675 over 2,276 crops |
| Class list | `ml_workspace/yolo/artifacts/crops/classes.json` — Celana_Panjang, Celana_Pendek, Gaun, Jaket, Kaos, Kemeja, Mantel, Rok, Rompi, Sepatu, Sweter, Topi; the order `flutter_app/lib/logic/garment_labels.dart` mirrors |
| sha256 | `dbc61f21563f90e32b0a896a79a711ac6ee461e235a0cd27fe6135170c9fb81e` |
| Size | 5,846,659 bytes (5.8 MB) |
| Input | `[1, 3, 224, 224]` float32, **NCHW** RGB in `[0, 1]`, normalisation baked into the graph; `rgbaToInputFloats` reads the layout off the tensor, so an NHWC export works as well |
| Output | `[1, 12]` float32 softmax |

Class names are Indonesian because the UI shows them; `garmentLabelCategory` maps each one onto
one of the five Categories. Swapping this asset and regenerating `garment_labels.dart` must
happen in the same commit — `gen_dart_labels.py` refuses a class list whose length does not
match the shipped asset's output width.

## `garment_detector.tflite` — garment detector

Finds the garments in one photo and gives each a coarse Category, before the classifier names
the crop inside each box (`docs/adr/0009`, `docs/adr/0011`).

| | |
|---|---|
| Model | Ultralytics YOLOv8n detection fine-tuned to 5 Categories at 640×640 |
| Licence | **AGPL-3.0** — Ultralytics weights trained by us (`docs/adr/0006`); coursework artifact, not for redistribution |
| Training data | Fashionpedia — annotations CC BY 4.0, photographs keep the terms of the sites they came from; 4,030 train / 1,158 val / 2,000 test photographs |
| Measured on `test` | mAP50 **0.7081**, mAP50-95 0.5417; per Category 0.78–0.80 except Accessories 0.382 |
| Class list | `['Tops', 'Bottoms', 'Outerwear', 'Shoes', 'Accessories']`, in output order (`detectorCategories` in `lib/logic/scan_pipeline.dart`) |
| sha256 | `72d2ba68cc390ecae3755c13f026a12acc5743f3a84818c6781455e55dd866cb` |
| Size | 12,767,821 bytes (12.8 MB) |
| Input | `serving_default_args_0` — `[1, 3, 640, 640]` float32, **NCHW** RGB in `[0, 1]` |
| Output | `serving_default_output_0_output` — `[1, 9, 8400]` float32: centre x, centre y, width, height, then five Category scores, no objectness |

The `.tflite` is copied from `ml_workspace/yolo/artifacts/detector/`, where `report.md`,
`per_category_ap.csv` and the confusion matrix sit next to it.

