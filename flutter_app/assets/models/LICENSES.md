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

Names the garment inside a box the detector found. **Shipped today is the merged 18-class
model** (`docs/adr/0008`, `docs/adr/0011`); the 10-class CC0 bootstrap it replaced lives on in
`ml_workspace/bootstrap/artifacts/` as the previous generation.

| | |
|---|---|
| Model | Ultralytics YOLOv8n-cls fine-tuned to 18 classes at 224Ã—224 |
| Licence | **AGPL-3.0** — Ultralytics weights trained by us (`docs/adr/0006`); coursework artifact, not for redistribution |
| Training data | `alexeygrigorev/clothing-dataset-small` (CC0) merged with `ryanbadai/clothes-dataset` by `ml_workspace/scripts/merge_datasets.py`: 9,728 unique photographs, split 7,779 / 957 / 992 (`docs/adr/0008`) |
| Measured on `test` | top-1 **0.8155**, top-5 0.9808, macro-F1 0.7968 over 992 photographs |
| Class list | `ml_workspace/yolo/artifacts/classes_merged.json` â€” Blazer, Celana_Panjang, Celana_Pendek, Gaun, Hoodie, Jaket, Jaket_Denim, Jaket_Olahraga, Jeans, Kaos, Kaos_Lengan_Panjang, Kemeja, Mantel, Polo, Rok, Sepatu, Sweter, Topi; the order `flutter_app/lib/logic/garment_labels.dart` mirrors |
| sha256 | `d0ec7b3514b2572eb79da9a8af06f720951bd8eb57edda8f877d65d4e6d63d4e` |
| Size | 5,862,976 bytes (5.9 MB) |
| Input | `[1, 224, 224, 3]` float32, NHWC RGB in `[0, 1]`, ImageNet normalisation baked into the graph |
| Output | `[1, 18]` float32 softmax |

Class names are Indonesian because the UI shows them; `garmentLabelCategory` maps each one onto
one of the five Categories. Swapping this asset and regenerating `garment_labels.dart` must
happen in the same commit â€” `gen_dart_labels.py` refuses a class list whose length does not
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

