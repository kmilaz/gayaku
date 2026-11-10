#!/usr/bin/env python3
"""Train, evaluate and export the garment classifier on this machine.

The Kaggle notebook (`kaggle_merged_dataset.ipynb`) stays the way to use a free GPU. This script
is the same run without a GPU, without a network round trip and without uploading anything: it
trains `yolov8n-cls` on the tree `merge_datasets.py` built, evaluates on `val` (epoch selection)
and `test` (the number to report), and writes the artefacts the app needs.

    # full run: 30 epochs, mean 8.7 min/epoch on 16 CPU cores, so about 4.5 h
    python ml_workspace/yolo/train_local.py

    # prove the pipeline in three minutes before spending the afternoon
    python ml_workspace/yolo/train_local.py --fraction 0.1 --epochs 1 --name smoke

    # random init instead of the ImageNet checkpoint (worse on 9.7k photographs)
    python ml_workspace/yolo/train_local.py --weights yolov8n-cls.yaml

    # the worn-garment tree: 12 classes cut from Fashionpedia's item boxes (ADR-0012)
    python ml_workspace/yolo/train_local.py --data ml_workspace/data/crops

Needs `ultralytics` in an interpreter that has torch. Use `ml_workspace/yolo/.venv-train` and keep it
**isolated** from the system interpreter: mixing anaconda's MKL numpy with torch's OpenMP runtime
aborts the run with `OMP: Error #15` before the first checkpoint is saved.

    python -m venv ml_workspace/yolo/.venv-train
    ml_workspace/yolo/.venv-train/Scripts/python.exe -m pip install torch torchvision \\
        --index-url https://download.pytorch.org/whl/cpu
    ml_workspace/yolo/.venv-train/Scripts/python.exe -m pip install ultralytics

The `.tflite` export runs in a **separate Python 3.12 environment**, because `onnx2tf` aborts on the
repository's Windows interpreter (Python 3.14 with TensorFlow 2.22.0-rc0: even a two-node Gemm model
fails). `uv` builds that environment without touching the system Python:

    uv python install 3.12
    uv venv --python 3.12 ml_workspace/yolo/.venv-convert312
    uv pip install --python ml_workspace/yolo/.venv-convert312/Scripts/python.exe \
        tensorflow onnx2tf onnx onnxruntime pillow ai-edge-litert

`--convert-python` points at it by default; `--no-export` skips the step, and
`--export-only weights/best.pt` converts an existing checkpoint without retraining.

Outputs, by default in `ml_workspace/yolo/artifacts/` (the directory the app's tooling reads):

    classes.json                    class order = the model's output order
    garment_classifier.tflite       the asset the app bundles, verified against its contract
    report.md                       measured numbers, per class, both splits, and the caveats
    per_class_accuracy_{val,test}.csv, classification_report_{val,test}.{txt,csv},
    confusion_matrix_{val,test}.csv, confusion_matrix_{val,test}.png, ..._normalized.png

Exit codes: 0 on success, 1 when a check fails (missing tree, wrong class count, export that does
not match the app contract). A failed check never leaves a `.tflite` that looks usable.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import sys
from pathlib import Path

import numpy as np
import torch
from ultralytics import YOLO

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATA = REPO_ROOT / "ml_workspace" / "data" / "merged"
DEFAULT_ARTIFACTS = REPO_ROOT / "ml_workspace" / "yolo" / "artifacts"
DEFAULT_RUNS = REPO_ROOT / "ml_workspace" / "yolo" / "runs"
SPLITS = ("train", "val", "test")
APP_IMAGE_SIZE = 224


class TrainError(Exception):
    """A condition that makes this run's artefacts untrustworthy."""


def check_tree(data: Path) -> list[str]:
    """The class list the tree trains, in `sorted()` order -- the model's output order."""
    if not data.is_dir():
        raise TrainError(f"{data} does not exist -- run ml_workspace/scripts/merge_datasets.py first")
    classes: list[str] | None = None
    for split in SPLITS:
        directory = data / split
        if not directory.is_dir():
            raise TrainError(f"{directory} does not exist; the tree needs train/, val/ and test/")
        folders = sorted(entry.name for entry in directory.iterdir() if entry.is_dir())
        if not folders:
            raise TrainError(f"{directory} holds no class folders")
        if classes is None:
            classes = folders
        elif folders != classes:
            raise TrainError(f"{directory} lists {len(folders)} classes, train lists {len(classes)}")
        empty = [folder for folder in folders if not any((directory / folder).iterdir())]
        if empty:
            raise TrainError(f"{directory} has no photographs for: {', '.join(empty)}")
    print(f"dataset       {data}")
    print(f"classes       {len(classes)} ({', '.join(classes)})")
    return classes or []


def dataset_kind(data: Path) -> str:
    """Which tree this is, so the report describes the data it actually trained on.

    `crops` is the Fashionpedia item-box tree `fashionpedia_crops.py` writes; `merged` is the
    18-class tree `merge_datasets.py` writes; anything else gets the generic wording.
    """
    if (data / "manifest.json").is_file():
        document = json.loads((data / "manifest.json").read_text(encoding="utf-8"))
        if "mapping" in document:
            return "crops"
    if (data / "merged_dataset.json").is_file():
        return "merged"
    return "generic"


def split_counts(data: Path, classes: list[str]) -> dict[str, dict[str, int]]:
    return {
        split: {
            label: len([path for path in (data / split / label).iterdir() if path.is_file() or path.is_symlink()])
            for label in classes
        }
        for split in SPLITS
    }


def train(args: argparse.Namespace) -> tuple[YOLO, Path]:
    last = args.runs / args.name / "weights" / "last.pt"
    resuming = args.resume and last.is_file()
    if args.resume and not resuming:
        print(f"resume        {last} does not exist, starting a fresh run")
    model = YOLO(str(last) if resuming else args.weights)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"device        {device}   torch {torch.__version__}   threads {torch.get_num_threads()}")
    if resuming:
        print(f"resume        continuing {last}")
    model.train(
        data=str(args.data),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        fraction=args.fraction,
        device=device,
        workers=args.workers,
        project=str(args.runs),
        name=args.name,
        exist_ok=True,
        plots=True,
        cache=args.cache,
        seed=args.seed,
        patience=args.patience,
        verbose=True,
        resume=resuming,
    )
    best = Path(model.trainer.save_dir) / "weights" / "best.pt"
    if not best.is_file():
        raise TrainError(f"{best} was not written")
    print(f"best weights  {best} ({best.stat().st_size / 1e6:.1f} MB)")
    return model, best


def evaluate(best: Path, args: argparse.Namespace, classes: list[str], counts: dict) -> dict:
    """`val` and `test`, each with per-class precision/recall/F1 and a confusion matrix on disk.

    Everything is derived from ultralytics' own confusion matrix: `[predicted][true]` counts, so
    `matrix[predicted][true]` transposed gives `[true][predicted]`, and from that TP, support and
    predicted totals follow exactly. No second pass over the images and no scikit-learn, which
    would load a second OpenMP runtime on this machine and abort the process.
    """
    trained = YOLO(str(best))
    names = [trained.names[index] for index in range(len(trained.names))]
    if names != classes:
        raise TrainError(f"model class order {names} differs from the dataset's {classes}")

    measured: dict[str, dict] = {}
    for split in ("val", "test"):
        metrics = trained.val(
            data=str(args.data),
            split=split,
            imgsz=args.imgsz,
            batch=args.batch,
            device="cpu",
            plots=True,
            project=str(args.runs),
            name=f"val-{split}",
            exist_ok=True,
        )
        cloud = np.asarray(metrics.confusion_matrix.matrix, dtype=np.int64)   # [predicted][true]
        matrix = cloud.T                                                       # [true][predicted]
        total = int(matrix.sum())
        correct = np.diag(matrix)
        support = matrix.sum(axis=1)
        predicted = matrix.sum(axis=0)
        accuracy = float(correct.sum() / max(1, total))
        if abs(accuracy - float(metrics.top1)) > 1e-6:
            raise TrainError(
                f"{split}: confusion matrix gives accuracy {accuracy:.6f} but ultralytics reports "
                f"top-1 {float(metrics.top1):.6f}; the matrix orientation is not what this script assumes"
            )

        per_class = {}
        for index, label in enumerate(classes):
            tp = float(correct[index])
            prec = tp / predicted[index] if predicted[index] else 0.0
            recall = tp / support[index] if support[index] else 0.0
            f1 = 2 * prec * recall / (prec + recall) if (prec + recall) else 0.0
            per_class[label] = {
                "precision": prec,
                "recall": recall,
                "f1-score": f1,
                "support": int(support[index]),
            }
        macro_f1 = float(np.mean([per_class[label]["f1-score"] for label in classes]))

        args.artifacts.mkdir(parents=True, exist_ok=True)
        with (args.artifacts / f"classification_report_{split}.csv").open(
            "w", encoding="utf-8", newline=""
        ) as handle:
            writer = csv.writer(handle)
            writer.writerow(("label", "precision", "recall", "f1-score", "support"))
            for label in classes:
                row = per_class[label]
                writer.writerow(
                    (label, f"{row['precision']:.4f}", f"{row['recall']:.4f}",
                     f"{row['f1-score']:.4f}", row["support"])
                )
            writer.writerow(("macro avg", "", "", f"{macro_f1:.4f}", total))
        with (args.artifacts / f"classification_report_{split}.txt").open("w", encoding="utf-8") as handle:
            header = f"{'label':<22}{'precision':>10}{'recall':>10}{'f1-score':>10}{'support':>9}\n"
            handle.write(header)
            for label in classes:
                row = per_class[label]
                handle.write(
                    f"{label:<22}{row['precision']:>10.4f}{row['recall']:>10.4f}"
                    f"{row['f1-score']:>10.4f}{row['support']:>9}\n"
                )
            handle.write(f"{'macro avg':<22}{'':>10}{'':>10}{macro_f1:>10.4f}{total:>9}\n")
            handle.write(f"{'accuracy':<22}{'':>10}{'':>10}{accuracy:>10.4f}{total:>9}\n")
        with (args.artifacts / f"per_class_accuracy_{split}.csv").open(
            "w", encoding="utf-8", newline=""
        ) as handle:
            writer = csv.writer(handle)
            writer.writerow(("label", "support", "correct", "recall", "unique_in_tree"))
            for index, label in enumerate(classes):
                writer.writerow(
                    (label, int(support[index]), int(correct[index]),
                     f"{per_class[label]['recall']:.4f}", counts[split][label])
                )
        with (args.artifacts / f"confusion_matrix_{split}.csv").open(
            "w", encoding="utf-8", newline=""
        ) as handle:
            writer = csv.writer(handle)
            writer.writerow(("predicted \\ true", *classes))
            for index, label in enumerate(classes):
                writer.writerow((label, *[int(value) for value in cloud[index]]))
        for png in sorted(Path(metrics.save_dir).glob("confusion_matrix*.png")):
            shutil.copy2(png, args.artifacts / f"{png.stem}_{split}{png.suffix}")

        measured[split] = {
            "top1": float(metrics.top1),
            "top5": float(metrics.top5),
            "accuracy": accuracy,
            "macro_f1": macro_f1,
            "per_class": per_class,
            "matrix": matrix,
            "counts": cloud.T,
            "images": total,
        }
        print(
            f"{split:<5} top-1 {measured[split]['top1']:.4f}  top-5 {measured[split]['top5']:.4f}  "
            f"macro-F1 {macro_f1:.4f}  {total} photographs"
        )
    return measured


def _run(command: list[str], cwd: Path | None = None) -> None:
    import subprocess

    print("+", " ".join(command))
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if completed.returncode != 0:
        tail = "\n".join((completed.stdout or "").strip().splitlines()[-25:])
        raise TrainError(f"command failed ({completed.returncode}): {' '.join(command)}\n{tail}")


VERIFY_SCRIPT = '''
"""Open a .tflite, print its contract and the scores for one photograph, as JSON."""
import json
import sys

import numpy as np
from PIL import Image

try:                                       # LiteRT 2.x dropped tf.lite.Interpreter
    from ai_edge_litert.interpreter import Interpreter
except ImportError:                        # older stacks still ship it inside TensorFlow
    from tensorflow.lite import Interpreter

model_path, out_path, image_path, size = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
interpreter = Interpreter(model_path=model_path)
interpreter.allocate_tensors()
inputs = interpreter.get_input_details()[0]
outputs = interpreter.get_output_details()[0]
shape = tuple(int(v) for v in inputs["shape"])

with Image.open(image_path) as image:
    image = image.convert("RGB")
    scale = size / min(image.size)
    resized = image.resize(
        (max(size, round(image.width * scale)), max(size, round(image.height * scale))), Image.BILINEAR
    )
    left = (resized.width - size) // 2
    top = (resized.height - size) // 2
    pixels = np.asarray(resized.crop((left, top, left + size, top + size)), dtype=np.float32) / 255.0
array = pixels[None] if shape[1:] == (size, size, 3) else np.transpose(pixels, (2, 0, 1))[None]
interpreter.set_tensor(inputs["index"], array.astype(np.float32))
interpreter.invoke()                      # `run()` is the older spelling of the same call
scores = interpreter.get_tensor(outputs["index"])[0]

json.dump(
    {
        "input": list(shape),
        "input_dtype": np.dtype(inputs["dtype"]).name,
        "output": [int(v) for v in outputs["shape"]],
        "output_dtype": np.dtype(outputs["dtype"]).name,
        "sum": float(scores.sum()),
        "argmax": int(scores.argmax()),
        "max": float(scores.max()),
    },
    open(out_path, "w", encoding="utf-8"),
)
'''


def export(best: Path, args: argparse.Namespace, classes: list[str]) -> tuple[Path, dict]:
    """Export `.tflite` through ONNX, then refuse it unless it matches the app contract.

    `litert-torch` (Ultralytics' direct converter) has no working dependency set on this
    interpreter, so the route is the one `bootstrap/export_tflite.py` already uses: torch to
    ONNX here, ONNX to TFLite with `onnx2tf` in the TensorFlow environment. Ultralytics' ONNX
    graph ends in Softmax and takes RGB `[0,1]`, which is the app's contract.
    """
    import json
    import tempfile

    trained = YOLO(str(best))
    onnx_path = Path(trained.export(format="onnx", imgsz=args.imgsz, device="cpu")).resolve()
    print(f"onnx          {onnx_path} ({onnx_path.stat().st_size / 1e6:.1f} MB)")

    convert_python = args.convert_python
    if not convert_python.is_file():
        raise TrainError(
            f"{convert_python} does not exist -- pass --convert-python with an interpreter that has "
            "tensorflow and onnx2tf (this repository uses ml_workspace/bootstrap/.venv-convert)"
        )
    converted_dir = args.runs / "onnx2tf_out"
    shutil.rmtree(converted_dir, ignore_errors=True)
    _run(
        [str(convert_python), "-m", "onnx2tf", "-i", str(onnx_path), "-o", str(converted_dir)],
        cwd=args.runs,
    )
    candidates = sorted(converted_dir.glob("*_float32.tflite")) or sorted(converted_dir.glob("*.tflite"))
    if not candidates:
        raise TrainError(f"onnx2tf wrote no .tflite into {converted_dir}")
    target = args.artifacts / "garment_classifier.tflite"
    shutil.copy2(candidates[0], target)

    probe_image = sorted((args.data / "test" / classes[0]).iterdir())[0]
    with tempfile.TemporaryDirectory(dir=args.runs) as scratch:
        script = Path(scratch) / "verify_tflite.py"
        script.write_text(VERIFY_SCRIPT, encoding="utf-8")
        probe_json = Path(scratch) / "probe.json"
        _run(
            [str(convert_python), str(script), str(target), str(probe_json), str(probe_image), str(args.imgsz)]
        )
        probe = json.loads(probe_json.read_text(encoding="utf-8"))

    if probe["input_dtype"] != "float32" or probe["output_dtype"] != "float32":
        raise TrainError(f"dtypes are {probe['input_dtype']} / {probe['output_dtype']}; the app reads float32")
    if probe["input"][0] != 1 or probe["output"][0] != 1:
        raise TrainError(f"batch must be 1, got {probe['input']} / {probe['output']}")
    if tuple(probe["input"][1:]) not in {
        (args.imgsz, args.imgsz, 3),
        (3, args.imgsz, args.imgsz),
    }:
        raise TrainError(f"input {probe['input']} is not {args.imgsz}x{args.imgsz} RGB")
    if probe["output"][-1] != len(classes):
        raise TrainError(f"model scores {probe['output'][-1]} classes but the list has {len(classes)}")
    if not 0.99 <= probe["sum"] <= 1.01:
        raise TrainError(f"scores sum to {probe['sum']:.4f}: the graph returns logits, not probabilities")

    info = {
        "path": str(target),
        "bytes": target.stat().st_size,
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "input": probe["input"],
        "output": probe["output"],
        "probe_label": classes[probe["argmax"]],
        "probe_confidence": probe["max"],
        "probe_sum": probe["sum"],
        "onnx": str(onnx_path),
    }
    print(f"exported      {target} ({info['bytes']:,} bytes, sha256 {info['sha256'][:16]}...)")
    print(
        f"contract      input {info['input']} float32, output {info['output']} float32, "
        f"scores sum {info['probe_sum']:.6f}, probe {info['probe_label']} at {info['probe_confidence']:.4f}"
    )
    return target, info


def write_classes(path: Path, classes: list[str], args: argparse.Namespace, kind: str) -> None:
    trees = {
        "crops": "the fashionpedia_crops.py tree",
        "merged": "the merge_datasets.py tree",
        "generic": "the --data tree",
    }
    path.write_text(
        json.dumps(
            {
                "version": 1,
                "dataset": kind,
                "source": (
                    f"ml_workspace/yolo/train_local.py: {args.weights} trained on {trees[kind]} "
                    f"({len(classes)} classes, imgsz {args.imgsz}, {args.epochs} epochs, "
                    f"batch {args.batch}, seed {args.seed}); labels in the model's output order"
                ),
                "labels": classes,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


def write_report(
    path: Path,
    args: argparse.Namespace,
    classes: list[str],
    counts: dict,
    measured: dict,
    exported: dict | None,
    kind: str,
) -> None:
    def per_class_table(split: str) -> str:
        rows = measured[split]["per_class"]
        return "\n".join(
            f"| {label} | {rows[label]['precision']:.4f} | {rows[label]['recall']:.4f} | "
            f"{rows[label]['f1-score']:.4f} | {int(rows[label]['support'])} |"
            for label in classes
        )

    def matrix_table(split: str) -> str:
        matrix = measured[split]["counts"]
        lines = ["| true \\ predicted | " + " | ".join(classes) + " |", "| --- |" + " --- |" * len(classes)]
        for index, label in enumerate(classes):
            lines.append(f"| **{label}** | " + " | ".join(str(int(v)) for v in matrix[index]) + " |")
        return "\n".join(lines)

    class_table = "\n".join(
        f"| {label} | {counts['train'][label]} | {counts['val'][label]} | {counts['test'][label]} |"
        for label in classes
    )
    if exported is None:
        export_section = (
            "The `.tflite` export was skipped (`--no-export`). The class order the app must be\n"
            f"generated from is: {', '.join(classes)}. Convert `weights/best.onnx` to `.tflite` and\n"
            "check it against the contract before copying anything into `flutter_app/assets/models/`."
        )
    else:
        export_section = (
            f"* `{exported['path']}` — {exported['bytes']:,} bytes, sha256 `{exported['sha256']}`\n"
            f"* input `{exported['input']}` float32, output `{exported['output']}` float32, "
            f"scores sum {exported['probe_sum']:.6f}\n"
            f"* probe: `{exported['probe_label']}` at {exported['probe_confidence']:.4f}\n"
            f"* ONNX source: `{exported['onnx']}`\n"
            f"* class order (`classes.json`): {', '.join(classes)}"
        )
    descriptions = {
        "crops": {
            "title": "yolov8n-cls on the Fashionpedia crop set",
            "dataset": "`ml_workspace/data/crops` from `scripts/fashionpedia_crops.py` (`docs/adr/0012`)",
            "comparison": (
                "Not comparable with the 18-class merged model (0.8155 top-1 on 992 photographs) or the\n"
                "shipped 10-class bootstrap model (91.9 %): different classes, different crops, and a\n"
                "different split."
            ),
            "caveats": (
                "* Every crop carries a 5 % margin around its box, so a person wearing the garment is\n"
                "  usually in frame. That matches inference, where the crop comes from the detector, so\n"
                "  the number here is the one the app's second stage sees.\n"
                "* `Gaun` merges Fashionpedia's `dress` and `jumpsuit`, `Sweter` merges `sweater` and\n"
                "  `cardigan`, `Mantel` merges `coat` and `cape`. Those are category-level merges, not\n"
                "  curated classes: a jumpsuit and a gown are one class here.\n"
                "* `Rompi` is the only class that cannot reach its cap (719 boxes in the whole set), so\n"
                "  its per-class figures rest on a smaller sample than the other eleven.\n"
                "* Labels come from Fashionpedia's annotations. A misplaced box is a wrong label, and no\n"
                "  duplicate detection runs across crops: two boxes of one garment in one photo stay both."
            ),
            "licence": (
                "Trained with Ultralytics YOLOv8 on Fashionpedia item boxes: annotations CC BY 4.0, the\n"
                "photographs under the terms of the sites they came from (`docs/adr/0012`)."
            ),
        },
        "merged": {
            "title": "yolov8n-cls on the merged set",
            "dataset": "`ml_workspace/data/merged` from `scripts/merge_datasets.py` (`docs/adr/0008`)",
            "comparison": (
                "Not comparable with the shipped 10-class bootstrap model (91.9 % top-1) or the public\n"
                "15-class baseline (78.47 % / 0.7803 on a 40 % split): the class counts and splits differ."
            ),
            "caveats": (
                "* `Kaos_Lengan_Panjang` is a mixed class: a spot check of five photographs found three\n"
                "  knitted sweaters or cardigans and two long-sleeve tees, and CC0's `longsleeve` folder is\n"
                "  where they came from (`docs/adr/0008`). Its recall is the number to read first.\n"
                "* CC0's `outwear` is one wide umbrella mapped to `Jaket`, so it competes with `Jaket_Denim`,\n"
                "  `Jaket_Olahraga`, `Blazer`, `Mantel` and `Sweter`.\n"
                "* `Polo` and `Kemeja` each lost 51 photographs that were jacket photographs filed under the\n"
                "  wrong class inside `Clothes_Dataset`; those classes hold wrong examples less often now,\n"
                "  but they are smaller."
            ),
            "licence": (
                "Trained with Ultralytics YOLOv8 on CC0 photographs plus `ryanbadai/clothes-dataset`."
            ),
        },
        "generic": {
            "title": "yolov8n-cls",
            "dataset": f"`{args.data}`",
            "comparison": "",
            "caveats": "* None recorded for this tree.",
            "licence": "Trained with Ultralytics YOLOv8.",
        },
    }
    described = descriptions[kind]
    comparison = f"{described['comparison']}\n\n" if described["comparison"] else ""
    report = f"""# {described['title']} — local run

| | |
| --- | --- |
| command | `python ml_workspace/yolo/train_local.py --epochs {args.epochs} --batch {args.batch} --name {args.name}` |
| dataset | {described['dataset']} |
| weights | `{args.weights}` |
| training | imgsz {args.imgsz}, {args.epochs} epochs, batch {args.batch}, seed {args.seed}, patience {args.patience} |
| classes | {len(classes)} |

## Measured

| split | top-1 | top-5 | accuracy | macro-F1 | photographs |
| --- | --- | --- | --- | --- | --- |
| val (epoch selection) | {measured['val']['top1']:.4f} | {measured['val']['top5']:.4f} | {measured['val']['accuracy']:.4f} | {measured['val']['macro_f1']:.4f} | {measured['val']['images']} |
| **test (reported)** | **{measured['test']['top1']:.4f}** | {measured['test']['top5']:.4f} | {measured['test']['accuracy']:.4f} | **{measured['test']['macro_f1']:.4f}** | {measured['test']['images']} |

{comparison}## Per class, split `test`

| class | precision | recall | f1-score | support |
| --- | --- | --- | --- | --- |
{per_class_table('test')}

## Per class, split `val`

| class | precision | recall | f1-score | support |
| --- | --- | --- | --- | --- |
{per_class_table('val')}

## Confusion matrix, split `test` (rows true, columns predicted)

{matrix_table('test')}

## Photographs per class in the tree

| class | train | val | test |
| --- | --- | --- | --- |
{class_table}

## Known data problems

{described['caveats']}

## Exported model

{export_section}

## Licence

{described['licence']} Ultralytics states that models trained with their code are AGPL-3.0 by
default, and this `.tflite` derives from the `{args.weights}` checkpoint: distributing a build that
contains it triggers AGPL-3.0's source obligation, and this repository has no LICENSE file
(`docs/adr/0006`). The source photographs are not ours to redistribute (`docs/adr/0007`).
"""
    path.write_text(report, encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--artifacts", type=Path, default=DEFAULT_ARTIFACTS)
    parser.add_argument("--runs", type=Path, default=DEFAULT_RUNS)
    parser.add_argument("--weights", default="yolov8n-cls.pt")
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--imgsz", type=int, default=APP_IMAGE_SIZE)
    parser.add_argument("--batch", type=int, default=32)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--patience", type=int, default=8)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--fraction", type=float, default=1.0, help="train on this share of train/")
    parser.add_argument("--cache", default=False, help="'ram' keeps the decoded images in memory")
    parser.add_argument("--threads", type=int, default=min(16, os.cpu_count() or 8))
    parser.add_argument(
        "--convert-python",
        type=Path,
        default=REPO_ROOT / "ml_workspace" / "yolo" / ".venv-convert312" / "Scripts" / "python.exe",
        help="interpreter with tensorflow + onnx2tf, used only for the .tflite export",
    )
    parser.add_argument(
        "--export-only",
        type=Path,
        help="skip training: convert this .pt to .tflite and verify it",
    )
    parser.add_argument("--name", default="yolov8n-cls-merged-224")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="continue runs/<name>/weights/last.pt if it exists (a killed background run)",
    )
    parser.add_argument("--no-export", action="store_true", help="skip the .tflite export")
    args = parser.parse_args(argv)

    try:
        if args.imgsz != APP_IMAGE_SIZE:
            raise TrainError(
                f"--imgsz {args.imgsz}: the app contract is {APP_IMAGE_SIZE} px; train at 224 or the "
                "exported graph will not match what scan_pipeline.dart feeds it"
            )
        # Absolute paths: ultralytics resolves a relative `project=` against its own runs_dir,
        # which silently wrote the smoke run to runs/classify/.amp/in/... instead of where asked.
        args.data = args.data.resolve()
        args.artifacts = args.artifacts.resolve()
        args.runs = args.runs.resolve()
        if args.export_only:
            args.export_only = args.export_only.resolve()
        classes = check_tree(args.data)
        kind = dataset_kind(args.data)
        print(f"kind          {kind}")
        counts = split_counts(args.data, classes)
        args.artifacts.mkdir(parents=True, exist_ok=True)
        torch.set_num_threads(args.threads)
        if args.export_only:
            write_classes(args.artifacts / "classes.json", classes, args, kind)
            _, exported = export(args.export_only, args, classes)
            print(f"written       {args.artifacts / 'classes.json'}")
            print(f"sha256        {exported['sha256']}")
            return 0
        model, best = train(args)
        measured = evaluate(best, args, classes, counts)
        write_classes(args.artifacts / "classes.json", classes, args, kind)
        if args.no_export:
            write_report(args.artifacts / "report.md", args, classes, counts, measured, None, kind)
            print("export        skipped (--no-export): ONNX/TFLite not written")
            print(f"written       {args.artifacts / 'classes.json'}")
            print(f"written       {args.artifacts / 'report.md'}")
            print(f"test top-1    {measured['test']['top1']:.4f}   macro-F1 {measured['test']['macro_f1']:.4f}")
            return 0
        _, exported = export(best, args, classes)
        write_report(args.artifacts / "report.md", args, classes, counts, measured, exported, kind)
        print(f"written       {args.artifacts / 'classes.json'}")
        print(f"written       {args.artifacts / 'report.md'}")
        print(f"test top-1    {measured['test']['top1']:.4f}   macro-F1 {measured['test']['macro_f1']:.4f}")
        return 0
    except TrainError as exc:
        print(f"train_local: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
