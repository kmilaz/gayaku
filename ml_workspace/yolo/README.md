# YOLOv8 classifier — the training venues (Colab for the catalogue, Kaggle for the merged set)

`fashion_classifier_yolov8.ipynb` trains the garment classifier with **Ultralytics YOLOv8
classification** (`yolov8n-cls.pt`, 224 px) instead of the MobileNetV3-small that
`ml_workspace/bootstrap/` trains, and exports the one file the app loads:
`flutter_app/assets/models/garment_classifier.tflite`. The model choice and its licence
consequence are `docs/adr/0006-yolov8-classifier-agpl.md`; the training data is
`docs/adr/0003-kaggle-catalogue-training-data.md`; what the classifier sees, and the detector
stage that now precedes it, is `docs/adr/0005-classify-the-cutout.md` and
`docs/adr/0009-detect-then-classify-multiple-garments.md`.

`kaggle_merged_dataset.ipynb` is the Kaggle venue for the **18-class merged set**
(`docs/adr/0008-merge-the-two-training-sources.md`): it clones this repository and the CC0
dataset, calls `ml_workspace/scripts/merge_datasets.py`, then trains, evaluates on both `val`
and `test`, and exports. Its predecessor trained on `Clothes_Dataset` alone (15 classes, no
Shoes, no Hat) and was replaced by the merged run, not kept beside it.

Both are the YOLO counterpart of `ml_workspace/kaggle/fashion_classifier.ipynb`, so the same rules
apply: the notebook reuses this repository's scripts where it can, writes everything under
`ml_workspace/yolo/`, and ends with a zip you download.

| file | committed? | what it is |
| --- | --- | --- |
| `fashion_classifier_yolov8.ipynb` | yes | the Colab notebook for the catalogue (no stored outputs; run it top to bottom) |
| `kaggle_merged_dataset.ipynb` | yes | the Kaggle notebook for the 18-class merged set: merge, train, evaluate, export (no stored outputs) |
| `kaggle_crops_classifier.ipynb` | yes | the Kaggle notebook for the 12-class worn-garment set: cut crops from Fashionpedia, train, measure per class, export (no stored outputs) |
| `dataset/` | no | the ultralytics ImageFolder: `{train,val,test}/<Label>/…`, **symlinks** into the catalogue or the CC0 clone |
| `runs/` | no | ultralytics training and validation output, including `weights/best.pt` |
| `artifacts/` | partly | `classes.json`, `classes_merged.json`, `merged_dataset.json`, `report.md`, the CSVs and the confusion-matrix PNGs are worth committing; `*.tflite`, `*.pt` and the zip are ignored |

## Preparation checklist

Have all of this ready **before** you open Colab, or the run fails an hour in.

1. **A Kaggle account and API token** for the catalogue path. Kaggle now issues two shapes and
   the tooling accepts both: `kaggle.json` (username + key) at `~/.kaggle/kaggle.json`, or an
   access token starting with `KGAT_` at `~/.kaggle/access_token` / `$KAGGLE_API_TOKEN`. The
   notebook takes whichever you have — from the `ACCESS_TOKEN` line at the top of step c, from
   Colab Secrets (`KAGGLE_USERNAME` + `KAGGLE_KEY`, or a single `KAGGLE_API_TOKEN`), or from the
   upload picker (it detects which shape you gave it).
   No Kaggle account? Skip this and use the CC0 path — it needs no credentials at all.
2. **A GPU runtime**, not just any runtime: *Runtime* → *Change runtime type* → T4 GPU. Free
   Colab is enough. Without a GPU the notebook still runs, but the catalogue takes many hours on
   two vCPUs, and it says so in step a.
3. **Disk and time, roughly**: the CC0 path clones ~103 MB and trains in well under half an
   hour. The catalogue path downloads a ~2 GB archive and extracts roughly 15 GB of photographs
   (44k items) plus a few hundred MB of symlinks; 30 epochs of `yolov8n-cls` at 224 px on a free
   T4 is about 1–3 hours, and extraction/download adds 10–20 minutes. Colab's free VM gives you
   ~100 GB of disk, so it fits — but do not *also* cache the dataset in RAM.
4. **Keep the tab open.** Free Colab disconnects an idle session, and the VM (clone, dataset,
   `best.pt`) is gone when it does. Nothing is written back to your machine until step j, so a
   disconnect means re-running from step b. Do the catalogue run in one sitting.
5. **`ml_workspace/labels.json` decides which classes exist.** It is the semantic source of
   truth: one entry per label, with the five Categories from `CONTEXT.md`. Every class folder
   the notebook builds needs an entry that looks like this — take it from the CC0 block, which
   is already complete for all ten of its folders:

   ```json
   {"label": "T-Shirt", "category": "Tops", "name": "Kaos", "keep": true,
    "dataset": "alexeygrigorev/clothing-dataset"}
   ```

   * `keep: true` — the label is trained on. The catalogue path uses the 80 `keep: true`
     entries tagged `paramaggarwal/fashion-product-images-dataset`; the CC0 path uses the 16
     tagged `alexeygrigorev/clothing-dataset`, of which the `clothing-dataset-small` clone only
     has 10 folders.
   * `category` — exactly one of `Tops`, `Bottoms`, `Outerwear`, `Shoes`, `Accessories`.
     `gen_dart_labels.py` refuses anything else.
   * `name` — the Indonesian display name the scanner shows (`Kaos`, `Kemeja`, `Jaket`, …).
   * `keep: false` — kept for the record, never a class (junk labels such as `Not sure`, or
     labels too thin to train: `prepare_data.py` stops when a `keep: true` label has fewer than
     8 photographs).

   **Adding a class is adding a row here**, not editing the notebook — and it changes how many
   classes the app expects, so it arrives with a Category and an Indonesian name or not at all.
6. **"Done" looks like**: the notebook ran top to bottom without an assertion firing, and it
   told you:

   * step g printed **top-1 and top-5** on the held-out `test` split — compare against the
     bootstrap MobileNetV3-small's measured **0.9194 on 10 classes** (`ml_workspace/bootstrap/README.md`)
     before you believe a number; 80 classes are harder, so a lower top-1 on the catalogue is
     expected, and the confusion matrix is what tells you whether it is honest;
   * step h printed **`sum of scores ≈ 1`**, the input layout, and a **PASSED** conversion gate;
   * **the class count** is 80 (catalogue) or 10 (CC0), and it must equal
     `garmentCategories.length` after step 2 of the integration steps below;
   * step j printed the `.tflite`'s **sha256 and byte size**, and handed your browser
     `gayaku_yolo_classifier.zip`.
7. **Two files to download** (three, really): `garment_classifier.tflite` and `classes.json`.
   Keep `report.md` too — it is the evidence for the numbers you report, and the only record of
   which commands produced them.

## Integration steps

From the repository root, in this order. Step 1 must come before step 2: the codegen guard reads
the *shipped* asset, so the Dart list cannot be regenerated for a model that is not in place yet.

1. **Put the artefacts where the app reads them.** Unzip the download, then copy the model over
   the shipped one:

   ```bash
   cd /path/to/gayaku
   unzip ~/Downloads/gayaku_yolo_classifier.zip -d ml_workspace/yolo/artifacts/
   cp ml_workspace/yolo/artifacts/garment_classifier.tflite \
      flutter_app/assets/models/garment_classifier.tflite
   ```

   *Proves*: the app now bundles the new weights — `flutter_app/pubspec.yaml` already lists
   `assets/models/`, so no pubspec change is needed. *Failure looks like*: `cp` cannot find the
   file (unzip path wrong), or the app later loads but every prediction is off — a `classes.json`
   from a different run than the `.tflite`, which step 2 catches. Keep the zip until the
   on-device scan passes; the asset you are overwriting is the CC0 bootstrap export.

2. **Regenerate the Dart class list from the class list that shipped with this model, and let it
   check the pairing:**

   ```bash
   python ml_workspace/scripts/gen_dart_labels.py \
     --classes ml_workspace/yolo/artifacts/classes.json \
     --labels ml_workspace/labels.json \
     --out flutter_app/lib/logic/garment_labels.dart \
     --model flutter_app/assets/models/garment_classifier.tflite
   ```

   `--classes` is the *only* correct argument here: the model's output order is ultralytics'
   alphabetical class-folder order, and for `ml_workspace/artifacts/classes.json` — the
   80-class catalogue list in `labels.json` order — the two orders differ, so pointing at it
   would mislabel every prediction by one index. `--model` is the guard: it reads the shipped
   `.tflite`'s output width and exits `1` before writing anything if it does not equal the
   number of labels.

   *Proves*: `garmentCategories[i]` names the class that `scores[i]` means, and the shipped
   weights match the list. *Failure looks like* (this is the current state of the repository,
   run verbatim):

   ```
   gen_dart_labels: ...\garment_classifier.tflite scores 10 classes but the class list has 80
   labels (Tshirts, Shirts, Casual Shoes, Watches, ...): the shipped weights and this class list
   describe different models. ...
   ```
   — i.e. step 1 was skipped or the wrong `--classes` was used. A class with no `labels.json`
   entry exits `1` with `no entry in labels.json for classifier classes: '...'`; a class whose
   `category` is not one of the five exits `1` too. For CI or a pre-commit hook the same check
   runs without writing: `python ml_workspace/scripts/gen_dart_labels.py --classes ml_workspace/yolo/artifacts/classes.json --check`.

3. **Refresh `flutter_app/assets/models/LICENSES.md`** in the same commit. Read the real numbers
   off the asset rather than retyping them from the notebook:

   ```bash
   python ml_workspace/scripts/tflite_io.py flutter_app/assets/models/garment_classifier.tflite
   ```

   Replace the classifier row's model, class list (`ml_workspace/yolo/artifacts/classes.json`),
   sha256, size and tensor IO, and change the licence line to **AGPL-3.0** (Ultralytics-trained
   weights, `docs/adr/0006`) — the "weights trained by us, permissively licensed" line that is
   there today belongs to the MobileNetV3-small bootstrap export. *Proves*: the APK's model
   provenance statement matches what is actually bundled. *Failure looks like*: `tflite_io.py`
   printing `input 0: shape=[1,3,224,224]` when you wrote `[1,224,224,3]` — read the line, do not
   assume the layout (the app accepts both, LICENSES.md should record the one you shipped).

4. **Run the app's own checks:**

   ```bash
   cd flutter_app && flutter analyze && flutter test && cd ..
   ```

   *Proves*: the Dart pipeline still compiles and behaves — `test/scan_pipeline_test.dart` covers
   the probability handling (`probabilitiesFrom` softmaxes a logits output, refuses a score vector
   shorter than the class list), the float16 conversion and the raw-byte tensor plumbing.
   *Note*: no test loads the real `.tflite`, so this does **not** prove your model is correct —
   step 2 and step 6 are what check the model. *Failure looks like*: `flutter analyze` flagging
   the regenerated `garment_labels.dart` (it should be a clean, generated file) or a test
   assertion on the probability helpers.

5. **Build and scan on a device:**

   ```bash
   cd flutter_app && flutter build apk --debug
   ```

   Install it, scan one flat-lay or hanger photo (one garment per photo — `docs/adr/0005`), and
   read the review screen: Category, Indonesian name, Dominant colour and the confidence line.
   *Proves*: the whole on-device path — matting, classify the Cutout, colour — against real
   weights. *Failure looks like*: the app throws at load with an Indonesian message naming both
   counts —
   `Model klasifikasi punya 10 kelas, label aplikasi punya 80. Jalankan ulang ml_workspace/scripts/gen_dart_labels.py.`
   (`scan_pipeline.dart::checkContracts`) — meaning step 2 did not run against the asset in
   step 1; or
   `Input model garment_classifier.tflite bukan 224x224 RGB NHWC/NCHW (bentuk: …)` — the export
   is not a 224 px RGB graph. A garment that is worn, or a photo with several garments, is out of
   contract and will produce a low-confidence answer rather than an error: that is the Correction
   step's job.

6. **Sweep the app's own photos, and record the numbers:**

   ```bash
   ml_workspace/bootstrap/.venv-convert/Scripts/python.exe ml_workspace/scripts/classify_assets.py \
     --classes ml_workspace/yolo/artifacts/classes.json \
     --model flutter_app/assets/models/garment_classifier.tflite \
     --markdown
   ```

   (Any Python with `tensorflow` will do — `ml_workspace/bootstrap/README.md` documents the venv
   above; every other script in `ml_workspace/` is dependency-light on purpose.) *Proves*: the
   model recognises the app's own garment photography, not just its training split, and the
   `--classes`/`--model` pair is consistent — a mismatched pair exits `1` with
   `model scores N classes but … lists M` plus the class lists in the repository that would fit.
   *Failure looks like*: every photo returning the same label, or a bag/watch photo answered with
   a garment label (the class list, not the model, is the limit — `ml_workspace/artifacts/asset_sweep.md`
   already records exactly that for the CC0 set).

7. **Record the run where the next person will look for it.** Commit
   `ml_workspace/yolo/artifacts/classes.json` and `report.md` (plus the CSVs and the
   confusion-matrix PNGs), paste the `classify_assets.py --markdown` table into
   `ml_workspace/artifacts/asset_sweep.md` with the new sha256, and update the "Where the models
   stand" table in `ml_workspace/README.md` so the shipped asset and its class list are named in
   one place. If the model choice itself changes (a different YOLO backbone, a permissively
   licensed model, a new Category), that is an ADR: extend `docs/adr/0006` or add a new one
   rather than editing `report.md` into a decision.

### What was not executed here

The notebook was **not run** on the machine that wrote it, and neither was anything downstream of
training. Explicitly:

* **a–j in the notebook**: no GPU and no Kaggle token here. `prepare_data.py` would stop at the
  missing token, and a free Colab T4 is where training happens by design. What *was* verified on
  the authoring machine: the notebook is valid nbformat 4.5 JSON with 23 cells, zero stored
  outputs and 11 code cells that all parse (`nbformat.validate` + `ast.parse` after stripping the
  single `!pip` line); the Ultralytics API used by steps f, g, h and i was read out of the
  installed wheel (`ultralytics 8.4.177`): `Classify.forward` ends in `Softmax` and returns
  probabilities in eval mode, `check_cls_dataset` sorts folder names for the class order,
  `ClassificationValidator.finalize_metrics` writes `confusion_matrix.png` /
  `confusion_matrix_normalized.png` and exposes `metrics.confusion_matrix`, and `format='litert'`
  is the current spelling of `format='tflite'`.
* **step 2's success path**: `gen_dart_labels.py --check` was run (read-only) and reproduced the
  *failure* quoted above, which is the state of the repository while the bootstrap model is
  shipped; the success path needs the YOLO `.tflite` that only a Colab run produces.
* **steps 4–6**: no Flutter toolchain run and no TensorFlow installed here, so `flutter analyze`,
  `flutter test`, `flutter build apk` and `classify_assets.py` are documented from their sources
  and their recorded previous outputs, not re-run. `tflite_io.py` *was* run against the shipped
  asset on the authoring machine: it reports `6129368 bytes, sha256 4dea19d6…`, input
  `[1, 224, 224, 3]` float32 and output `[1, 10]` float32, which is the file step 1 replaces.
* **The numbers**: this README quotes the measured CC0 bootstrap numbers from
  `ml_workspace/bootstrap/README.md` (0.9194 test top-1, 10 classes) as the bar to compare
  against. No YOLOv8 accuracy figure appears anywhere here, because none has been measured yet.

## The Kaggle merged run: `kaggle_merged_dataset.ipynb`

The Kaggle venue trains on the **18-class merged set** instead of one source alone: the notebook
clones this repository plus `alexeygrigorev/clothing-dataset-small`, runs
`ml_workspace/scripts/merge_datasets.py`, and only then trains `yolov8n-cls`. The merge rules and
the measurements behind them are `docs/adr/0008-merge-the-two-training-sources.md`; the notebook
never re-implements them, so the tree it trains on is the tree this repository's assertions
produced.

* **Run it**: Kaggle -> *Add Input* -> `ryanbadai/clothes-dataset`; *Accelerator: GPU T4*;
  *Internet: On* (the clone of the repository and of the CC0 dataset, `pip install ultralytics`, and
  the `yolov8n-cls.pt` download all need it). Set `REPO_REF` at the top of step 2 to the branch that
  contains `merge_datasets.py` if it is not on `main` yet; the cell stops with a message naming the
  missing file if the ref does not have it.
* **What the merge produces**: 11,281 files scanned -> **9,728 unique photographs over 18 classes**
  (7,350 from `Clothes_Dataset`, 2,378 from CC0), split 7,779 train / 957 val / 992 test. Step 3
  prints the per-class table from `merged_dataset.json`; those are the numbers to quote, not the 500
  per folder on the dataset page.
* **Where it writes**: the tree and the training run go to `/kaggle/temp` (not saved), the artefacts
  to `/kaggle/working/artifacts/` (`garment_classifier.tflite`, `classes.json`, `report.md`,
  `merged_dataset.json`, `classes_merged.json`, `classification_report_{val,test}.*`,
  `per_class_accuracy_{val,test}.csv`, `confusion_matrix_{val,test}.csv` and the PNGs) and the
  bundle to `/kaggle/working/gayaku_yolo_merged.zip`.
* **Evaluation**: `val` selects the best epoch, so the reported numbers are the **`test`** split --
  top-1, top-5, accuracy, macro-F1, precision/recall/F1 per class and the confusion matrix. A second
  `model.predict` pass cross-checks the ultralytics matrix against scikit-learn's; a non-zero cell
  difference means the two evaluation pipelines disagree, not that the model is wrong.
* **Integration**: unzip, copy `garment_classifier.tflite` over
  `flutter_app/assets/models/garment_classifier.tflite`, then regenerate the Dart list from the list
  that shipped with the zip, in the same commit:

  ```bash
  unzip ~/Downloads/gayaku_yolo_merged.zip -d ml_workspace/yolo/artifacts/
  cp ml_workspace/yolo/artifacts/garment_classifier.tflite \
     flutter_app/assets/models/garment_classifier.tflite
  python ml_workspace/scripts/gen_dart_labels.py \
    --classes ml_workspace/yolo/artifacts/classes.json \
    --model flutter_app/assets/models/garment_classifier.tflite
  ```

  `ml_workspace/yolo/artifacts/classes_merged.json` holds the same 18 labels in the same order,
  committed by the merge; `classes.json` from the zip is what the export actually wrote, and
  `--model` refuses the pair if their counts differ.
* **Accuracy is not comparable**: 18 classes here, 10 classes at 91.9 % for the shipped bootstrap
  model, and 78.47 % / 0.7803 for the public 15-class ViT-base baseline on a 40 % split. Quote the
  class count and the split with any figure.

### What was verified for the merged notebook, and what was not

Verified on the authoring machine (no Kaggle session, no GPU):

* `nbformat.validate` passes (nbformat 4.5, 20 cells: 11 markdown / 9 code), zero stored outputs,
  and every code cell parses with `ast.parse` after stripping its `!pip install` line.
* The verification cell (step 3) was **executed against the real merged tree** with only the three
  hard-coded paths swapped: it prints the 18-class table, matches the tree total (9,728) against
  `merged_dataset.json`, and reads every assert as `passed`.
* `merge_datasets.py` was run over the real datasets repeatedly: a second identical run reused the
  tree because every option, input path and per-folder file count still matched, and a forced
  rebuild wrote the same 9,728 photographs into the same splits.
* `gen_dart_labels.py --classes .../classes_merged.json` resolves all 18 labels into Categories and
  Indonesian names, and against the shipped 10-class asset it refuses with the drift message -- the
  guard that keeps the app's label list and its weights a matched pair.

Not verified (needs a Kaggle session):

* everything that touches the dataset mount or a GPU: the clone of the repository and of the CC0
  set on Kaggle, `ultralytics` training, `model.val` on `val`/`test`, the extra `model.predict`
  pass, both exports, the `.tflite` contract checks, the fidelity gate and the zip;
* no accuracy, macro-F1, per-class recall or agreement number is quoted anywhere for the merged
  set, because none has been measured. The confusion matrix in `report.md` is where they will
  appear.
