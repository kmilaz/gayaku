# yolov8n-cls on the Fashionpedia crop set — local run

| | |
| --- | --- |
| command | `python ml_workspace/yolo/train_local.py --epochs 30 --batch 64 --name yolov8n-cls-crops-224` |
| dataset | `ml_workspace/data/crops` from `scripts/fashionpedia_crops.py` (`docs/adr/0012`) |
| weights | `yolov8n-cls.pt` |
| training | imgsz 224, 30 epochs, batch 64, seed 42, patience 8 |
| classes | 12 |

## Measured

| split | top-1 | top-5 | accuracy | macro-F1 | photographs |
| --- | --- | --- | --- | --- | --- |
| val (epoch selection) | 0.6671 | 0.9567 | 0.6671 | 0.6506 | 2286 |
| **test (reported)** | **0.6784** | 0.9631 | 0.6784 | **0.6675** | 2276 |

Not comparable with the 18-class merged model (0.8155 top-1 on 992 photographs) or the
shipped 10-class bootstrap model (91.9 %): different classes, different crops, and a
different split.

## Per class, split `test`

| class | precision | recall | f1-score | support |
| --- | --- | --- | --- | --- |
| Celana_Panjang | 0.7919 | 0.7800 | 0.7859 | 200 |
| Celana_Pendek | 0.7914 | 0.7400 | 0.7649 | 200 |
| Gaun | 0.6495 | 0.6950 | 0.6715 | 200 |
| Jaket | 0.5092 | 0.5550 | 0.5311 | 200 |
| Kaos | 0.4912 | 0.5600 | 0.5234 | 200 |
| Kemeja | 0.6108 | 0.5100 | 0.5559 | 200 |
| Mantel | 0.5812 | 0.6800 | 0.6267 | 200 |
| Rok | 0.7027 | 0.6500 | 0.6753 | 200 |
| Rompi | 0.7368 | 0.3684 | 0.4912 | 76 |
| Sepatu | 0.8738 | 0.9350 | 0.9034 | 200 |
| Sweter | 0.5916 | 0.5650 | 0.5780 | 200 |
| Topi | 0.8966 | 0.9100 | 0.9032 | 200 |

## Per class, split `val`

| class | precision | recall | f1-score | support |
| --- | --- | --- | --- | --- |
| Celana_Panjang | 0.7959 | 0.7800 | 0.7879 | 200 |
| Celana_Pendek | 0.8146 | 0.7250 | 0.7672 | 200 |
| Gaun | 0.5903 | 0.6700 | 0.6276 | 200 |
| Jaket | 0.5066 | 0.5750 | 0.5386 | 200 |
| Kaos | 0.5000 | 0.5100 | 0.5050 | 200 |
| Kemeja | 0.6358 | 0.5150 | 0.5691 | 200 |
| Mantel | 0.5776 | 0.6700 | 0.6204 | 200 |
| Rok | 0.6458 | 0.6200 | 0.6327 | 200 |
| Rompi | 0.7097 | 0.2558 | 0.3761 | 86 |
| Sepatu | 0.8438 | 0.9450 | 0.8915 | 200 |
| Sweter | 0.5525 | 0.6050 | 0.5776 | 200 |
| Topi | 0.9278 | 0.9000 | 0.9137 | 200 |

## Confusion matrix, split `test` (rows true, columns predicted)

| true \ predicted | Celana_Panjang | Celana_Pendek | Gaun | Jaket | Kaos | Kemeja | Mantel | Rok | Rompi | Sepatu | Sweter | Topi |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Celana_Panjang** | 156 | 5 | 3 | 0 | 5 | 1 | 4 | 10 | 0 | 9 | 2 | 5 |
| **Celana_Pendek** | 9 | 148 | 4 | 0 | 4 | 0 | 1 | 19 | 0 | 7 | 3 | 5 |
| **Gaun** | 4 | 1 | 139 | 7 | 10 | 1 | 17 | 14 | 0 | 0 | 7 | 0 |
| **Jaket** | 2 | 1 | 3 | 111 | 16 | 19 | 31 | 0 | 0 | 0 | 16 | 1 |
| **Kaos** | 1 | 4 | 17 | 11 | 112 | 15 | 10 | 5 | 3 | 1 | 19 | 2 |
| **Kemeja** | 3 | 2 | 4 | 50 | 16 | 102 | 7 | 2 | 3 | 0 | 10 | 1 |
| **Mantel** | 2 | 1 | 11 | 16 | 8 | 5 | 136 | 0 | 1 | 0 | 19 | 1 |
| **Rok** | 12 | 18 | 24 | 0 | 5 | 0 | 5 | 130 | 1 | 2 | 2 | 1 |
| **Rompi** | 0 | 1 | 3 | 8 | 15 | 16 | 5 | 0 | 28 | 0 | 0 | 0 |
| **Sepatu** | 4 | 4 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 187 | 0 | 3 |
| **Sweter** | 4 | 1 | 6 | 13 | 32 | 8 | 16 | 3 | 2 | 0 | 113 | 2 |
| **Topi** | 0 | 1 | 0 | 2 | 5 | 0 | 2 | 0 | 0 | 8 | 0 | 182 |

## Photographs per class in the tree

| class | train | val | test |
| --- | --- | --- | --- |
| Celana_Panjang | 1600 | 200 | 200 |
| Celana_Pendek | 1600 | 200 | 200 |
| Gaun | 1600 | 200 | 200 |
| Jaket | 1600 | 200 | 200 |
| Kaos | 1600 | 200 | 200 |
| Kemeja | 1600 | 200 | 200 |
| Mantel | 1600 | 200 | 200 |
| Rok | 1600 | 200 | 200 |
| Rompi | 557 | 86 | 76 |
| Sepatu | 1600 | 200 | 200 |
| Sweter | 1600 | 200 | 200 |
| Topi | 1600 | 200 | 200 |

## Known data problems

* Every crop carries a 5 % margin around its box, so a person wearing the garment is
  usually in frame. That matches inference, where the crop comes from the detector, so
  the number here is the one the app's second stage sees.
* `Gaun` merges Fashionpedia's `dress` and `jumpsuit`, `Sweter` merges `sweater` and
  `cardigan`, `Mantel` merges `coat` and `cape`. Those are category-level merges, not
  curated classes: a jumpsuit and a gown are one class here.
* `Rompi` is the only class that cannot reach its cap (719 boxes in the whole set), so
  its per-class figures rest on a smaller sample than the other eleven.
* Labels come from Fashionpedia's annotations. A misplaced box is a wrong label, and no
  duplicate detection runs across crops: two boxes of one garment in one photo stay both.

## Exported model

The `.tflite` export was skipped (`--no-export`). The class order the app must be
generated from is: Celana_Panjang, Celana_Pendek, Gaun, Jaket, Kaos, Kemeja, Mantel, Rok, Rompi, Sepatu, Sweter, Topi. Convert `weights/best.onnx` to `.tflite` and
check it against the contract before copying anything into `flutter_app/assets/models/`.

## Licence

Trained with Ultralytics YOLOv8 on Fashionpedia item boxes: annotations CC BY 4.0, the
photographs under the terms of the sites they came from (`docs/adr/0012`). Ultralytics states that models trained with their code are AGPL-3.0 by
default, and this `.tflite` derives from the `yolov8n-cls.pt` checkpoint: distributing a build that
contains it triggers AGPL-3.0's source obligation, and this repository has no LICENSE file
(`docs/adr/0006`). The source photographs are not ours to redistribute (`docs/adr/0007`).

## Exported model (measured on the downloaded file)

Added after the run, from the `.tflite` this notebook produced; the run's own report stops at the
skipped-export note because training ran with `--no-export` and the export cell ran separately.

* `garment_classifier.tflite` — 5,846,659 bytes, sha256 `dbc61f21563f90e32b0a896a79a711ac6ee461e235a0cd27fe6135170c9fb81e`
* input `[1, 3, 224, 224]` float32 NCHW, output `[1, 12]` float32
* probe on a zero image: scores sum 1.000000, so the graph ends in softmax
* exported with `ultralytics.export(format="litert")`, which writes NCHW; `onnx2tf` writes NHWC.
  The app reads the layout off the tensor and accepts either.
