# yolov8n detection on Fashionpedia — GPU run

| | |
| --- | --- |
| date (UTC) | 2026-11-09 23:35 |
| notebook | `ml_workspace/yolo/kaggle_detector.ipynb` |
| repo ref | `feat/ml-pipeline` |
| dataset | `detection-datasets/fashionpedia` via `ml_workspace/scripts/fashionpedia_to_yolo.py` |
| photographs | 4030 train / 1158 val / 2000 test |
| boxes | 10000 train item boxes, 163007 part boxes dropped |
| training | yolov8n detection, 40 epochs, imgsz 640, batch 16, patience 10 |
| GPU | Tesla T4 |
| ultralytics / torch | 8.4.208 / 2.11.0+cu130 |

## Measured on `test`

| metric | value |
| --- | --- |
| mAP50 | 0.7081 |
| mAP50-95 | 0.5417 |

| Category | AP50 |
| --- | --- |
| Tops | 0.7922 |
| Bottoms | 0.7856 |
| Outerwear | 0.7809 |
| Shoes | 0.7998 |
| Accessories | 0.3821 |

The detector answers *where* and which Category; the 18-class classifier names the crop inside each
box (`docs/adr/0009`). Detection accuracy here therefore does not replace the classifier's
per-class recall, and vice versa.

## Licence

Ultralytics-trained weights are AGPL-3.0 (`docs/adr/0006`). Fashionpedia annotations are CC BY 4.0;
its photographs keep the terms of the sites they came from. Coursework artifacts, not for
redistribution (`docs/adr/0003`).
