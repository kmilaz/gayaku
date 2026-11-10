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

**Shipped today** is the CC0 bootstrap export; the Kaggle-trained catalogue model takes the
same slot later (`docs/adr/0003`).

| | |
|---|---|
| Model | torchvision MobileNetV3-small fine-tuned to 10 classes at 224×224 |
| Licence | weights trained by us; torchvision's ImageNet initialisation is BSD-3-Clause |
| Training data | `alexeygrigorev/clothing-dataset-small` (CC0 — that is the uploader's claim over its labels; the photographs are third-party and are not redistributed here) |
| Class list | `ml_workspace/bootstrap/artifacts/classes.json` — T-Shirt, Shirt, Longsleeve, Outwear, Dress, Skirt, Pants, Shorts, Shoes, Hat; the order `flutter_app/lib/logic/garment_labels.dart` mirrors |
| sha256 | `4dea19d6b3dbe30bd5a8dc9686803afdd657e9dedbf234d0fd61e5a6be313457` |
| Size | 6,129,368 bytes (6.1 MB) |
| Input | `image` — `[1, 224, 224, 3]` float32, NHWC RGB in `[0, 1]`, ImageNet normalisation baked into the graph |
| Output | `Identity` — `[1, 10]` float32 softmax |

**Final model**, exported by `ml_workspace/kaggle/fashion_classifier.ipynb` with class list
`ml_workspace/artifacts/classes.json`:

- **Weights trained by us** (torchvision MobileNetV3-small, ImageNet-initialised; the
  torchvision weights are BSD-3-Clause).
- **Training data is the Kaggle Fashion Product Images catalogue whose MIT tag covers
  labels, not the photographs — coursework artifacts, not for redistribution.**
- Landing it means replacing this asset and regenerating
  `flutter_app/lib/logic/garment_labels.dart` in the same commit — `gen_dart_labels.py`
  refuses a class list whose length does not match the shipped asset's output width — and
  adding the new sha256 and size here.

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

