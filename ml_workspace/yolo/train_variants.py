#!/usr/bin/env python3
"""Compare three ways to answer the same question, on the same crops and the same split.

The shipped classifier is one softmax over 12 classes. This script trains two alternatives from the
identical backbone (`yolov8n-cls.pt`) and the identical data, so the only difference is how the last
layer answers:

    flat     12-way softmax, cross-entropy            -- the shipped design, the control
    sigmoid  12 independent yes/no heads, BCE         -- the lecturer's "a dozen classifiers,
                                                         checked one by one", sharing one backbone
    heads    one softmax per Category plus a gate     -- Tops 3, Bottoms 3, Outerwear 4, Shoes 1,
                                                         Accessories 1; a small gate picks the head

Why the gate: `Shoes` and `Accessories` hold a single class, so their softmax is always exactly 1.0.
Without a gate, the confidence race would always be won by those two heads and every crop would be
called Sepatu or Topi. The gate is a linear layer on the same features, trained to name the
Category; in the app the detector already predicts that Category, so the gate stands in for it.

Every variant is scored on `test` with the same rule: top-1, top-1 without abstaining, coverage,
accuracy when it answers, macro-F1, per-class precision/recall/F1, and a confusion matrix in
`[true][predicted]` orientation -- the layout `train_local.py` writes.

    # the experiment, on a GPU
    python ml_workspace/yolo/train_variants.py --data ml_workspace/data/crops --epochs 30 --batch 64

    # prove the loop before spending GPU quota: 1 epoch on 20 images per class
    python ml_workspace/yolo/train_variants.py --data ml_workspace/data/crops --limit 20 \\
        --epochs 1 --batch 32 --out .amp/in/variants_smoke

This script never writes into `flutter_app/`: it produces measurements, not an asset. Replacing the
shipped `.tflite` is a separate change with its own contract check (`docs/adr/0012`).
"""

from __future__ import annotations

import argparse
import csv
import json
import random
import sys
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATA = REPO_ROOT / "ml_workspace" / "data" / "crops"
DEFAULT_OUT = REPO_ROOT / "ml_workspace" / "yolo" / "artifacts" / "variants"
LABELS = REPO_ROOT / "ml_workspace" / "labels.json"
SPLITS = ("train", "val", "test")
IMAGE_SIZE = 224
ABSTAIN_BELOW = 0.5
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"


class VariantError(Exception):
    """A condition that would make the comparison dishonest."""


def categories_for(classes: list[str]) -> dict[str, str]:
    """Model class -> Category, from labels.json (the file the Dart labels are generated from).

    Rows whose `label` equals the model class win over rows that only share the display `name`,
    which is why `Sweter` is Outerwear here even though a catalogue row named "Sweatshirts" also
    displays as "Sweter".
    """
    document = json.loads(LABELS.read_text(encoding="utf-8"))
    by_label = {entry["label"].lower(): entry for entry in document["labels"]}
    by_name: dict[str, list[dict]] = {}
    for entry in document["labels"]:
        by_name.setdefault(entry["name"].lower().replace(" ", "_"), []).append(entry)

    mapping: dict[str, str] = {}
    for label in classes:
        entry = by_label.get(label.lower())
        if entry is None:
            candidates = by_name.get(label.lower())
            if not candidates:
                raise VariantError(f"labels.json has no Category for class {label!r}")
            categories = {candidate["category"] for candidate in candidates}
            if len(categories) != 1:
                raise VariantError(f"class {label!r} matches rows with categories {sorted(categories)}")
            entry = candidates[0]
        mapping[label] = entry["category"]
    return mapping


def check_tree(data: Path) -> list[str]:
    if not data.is_dir():
        raise VariantError(f"{data} does not exist -- cut the crops first (fashionpedia_crops.py)")
    classes: list[str] | None = None
    for split in SPLITS:
        directory = data / split
        if not directory.is_dir():
            raise VariantError(f"{directory} does not exist")
        folders = sorted(entry.name for entry in directory.iterdir() if entry.is_dir())
        if classes is None:
            classes = folders
        elif folders != classes:
            raise VariantError(f"{directory} lists {len(folders)} classes, train lists {len(classes)}")
    return classes or []


class Crops(Dataset):
    """ImageFolder without torchvision's ImageFolder, so symlinks and subsets behave predictably."""

    def __init__(self, root: Path, split: str, classes: list[str], transform, limit: int) -> None:
        self.transform = transform
        self.items: list[tuple[Path, int]] = []
        for index, label in enumerate(classes):
            files = sorted(
                path for path in (root / split / label).iterdir()
                if path.is_file() or path.is_symlink()
            )
            if limit:
                files = files[:limit]
            self.items.extend((path, index) for path in files)

    def __len__(self) -> int:
        return len(self.items)

    def __getitem__(self, position: int):
        path, index = self.items[position]
        with Image.open(path) as image:
            tensor = self.transform(image.convert("RGB"))
        return tensor, index


def transforms_for(training: bool):
    if training:
        return transforms.Compose([
            transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.5, 1.0), ratio=(3 / 4, 4 / 3)),
            transforms.RandomHorizontalFlip(0.5),
            transforms.ToTensor(),
        ])
    return transforms.Compose([
        transforms.Resize(int(IMAGE_SIZE * 1.14)),
        transforms.CenterCrop(IMAGE_SIZE),
        transforms.ToTensor(),
    ])


class Categorised(nn.Module):
    """One softmax per Category, plus a gate that names the Category from the same features."""

    def __init__(self, features: int, groups: dict[str, list[int]]) -> None:
        super().__init__()
        self.order = list(groups)
        # A plain list, not a buffer: the groups have different lengths, so they cannot share one
        # rectangle. They are moved to the input device where they are used.
        self.groups = [torch.tensor(groups[name], dtype=torch.long) for name in self.order]
        self.linears = nn.ModuleDict(
            {name: nn.Linear(features, len(group)) for name, group in groups.items()}
        )
        self.gate = nn.Linear(features, len(groups))

    def forward(self, features):
        return [self.linears[name](features) for name in self.order], self.gate(features)


class Model(nn.Module):
    def __init__(self, body: nn.Module, head: nn.Module) -> None:
        super().__init__()
        self.body = body
        self.head = head

    def forward(self, x):
        features = self.body(x)
        if features.ndim > 2:
            features = nn.functional.adaptive_avg_pool2d(features, 1).flatten(1)
        return self.head(features)


def load_body(weights: str) -> tuple[nn.Module, int]:
    """Everything up to and including the head's 1×1 convolution, so features are 1280-wide.

    ultralytics' `Classify` head is conv → flatten → dropout → linear. Keeping only its conv means
    every variant's new head receives the tensor the shipped head receives, which is what makes the
    comparison fair.
    """
    from ultralytics import YOLO

    net = YOLO(weights).model
    layers = list(net.model.children())
    head = layers[-1]
    if not hasattr(head, "linear") or not hasattr(head, "conv"):
        raise VariantError(f"unexpected classifier head {type(head).__name__}")
    return nn.Sequential(*layers[:-1], head.conv), int(head.linear.in_features)


def build(variant: str, weights: str, classes: list[str], categories: dict[str, str]) -> Model:
    body, features = load_body(weights)
    if variant == "flat":
        head: nn.Module = nn.Linear(features, len(classes))
    elif variant == "sigmoid":
        head = nn.Linear(features, len(classes))
    elif variant == "heads":
        groups: dict[str, list[int]] = {}
        for index, label in enumerate(classes):
            groups.setdefault(categories[label], []).append(index)
        head = Categorised(features, groups)
    else:
        raise VariantError(f"unknown variant {variant!r}")
    return Model(body, head)


def category_index(classes: list[str], categories: dict[str, str]) -> tuple[list[str], torch.Tensor]:
    """Category order and the Category of every class, in the same order the heads are built."""
    order: list[str] = []
    for label in classes:
        if categories[label] not in order:
            order.append(categories[label])
    return order, torch.tensor([order.index(categories[label]) for label in classes], dtype=torch.long)


def run_epoch(model, loader, variant, optimizer, classes, categories, pos_weight, training: bool):
    model.train(training)
    ce = nn.CrossEntropyLoss()
    bce = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
    order, class_category = category_index(classes, categories)
    class_category = class_category.to(DEVICE)
    total, seen = 0.0, 0
    for images, targets in loader:
        images, targets = images.to(DEVICE), targets.to(DEVICE)
        out = model(images)
        if variant == "heads":
            head_logits, gate_logits = out
            loss = ce(gate_logits, class_category[targets])
            for index, head_output in enumerate(head_logits):
                mask = class_category[targets] == index
                if mask.any():
                    group = model.head.groups[index].to(DEVICE)
                    loss = loss + ce(head_output[mask], torch.searchsorted(group, targets[mask]))
        elif variant == "sigmoid":
            loss = bce(out, nn.functional.one_hot(targets, num_classes=len(classes)).float())
        else:
            loss = ce(out, targets)
        if training:
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
        total += float(loss.detach()) * targets.shape[0]
        seen += targets.shape[0]
    return total / max(1, seen)


def decide(model, variant, out, classes, categories, gate_override=None):
    """Both answers for one batch: what the design says, and what it would say without abstaining."""
    if variant == "flat":
        answers = out.argmax(dim=1).tolist()
        return answers, answers
    if variant == "sigmoid":
        scores = torch.sigmoid(out)
        forced = scores.argmax(dim=1).tolist()
        best = scores.max(dim=1)
        answered = [int(index) if float(value) >= ABSTAIN_BELOW else -1
                    for index, value in zip(best.indices.tolist(), best.values.tolist())]
        return answered, forced

    head_logits, gate_logits = out
    answered, forced = [], []
    for row in range(gate_logits.shape[0]):
        head_index = (
            int(gate_override[row]) if gate_override is not None else int(gate_logits[row].argmax())
        )
        probabilities = head_logits[head_index][row].softmax(dim=0)
        value, local = probabilities.max(dim=0)
        global_index = int(model.head.groups[head_index][int(local)])
        forced.append(global_index)
        answered.append(global_index if float(value) >= ABSTAIN_BELOW else -1)
    return answered, forced


@torch.no_grad()
def evaluate(model, loader, variant, classes, categories, gate_override=None) -> dict:
    """Score one split. `gate_override` admits an oracle run that uses the true Category."""
    model.eval()
    order, class_category = category_index(classes, categories)
    size = len(classes)
    matrix = np.zeros((size, size), dtype=np.int64)     # [true][predicted], abstain excluded
    forced = np.zeros_like(matrix)                      # [true][predicted], no abstain rule
    abstained = seen = 0
    for images, targets in loader:
        images = images.to(DEVICE)
        out = model(images)
        override = class_category[targets] if gate_override else None
        answered, forced_answers = decide(model, variant, out, classes, categories, override)
        for truth, guess, forced_guess in zip(targets.tolist(), answered, forced_answers):
            seen += 1
            forced[truth][forced_guess] += 1
            if guess < 0:
                abstained += 1
                continue
            matrix[truth][guess] += 1

    correct = np.diag(matrix)
    support = matrix.sum(axis=1)
    predicted_totals = matrix.sum(axis=0)
    per_class = {}
    for index, label in enumerate(classes):
        tp = float(correct[index])
        precision = tp / predicted_totals[index] if predicted_totals[index] else 0.0
        recall = tp / support[index] if support[index] else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        per_class[label] = {
            "precision": precision, "recall": recall, "f1-score": f1, "support": int(support[index])
        }
    return {
        "top1": float(correct.sum() / max(1, seen)),
        "top1_forced": float(np.diag(forced).sum() / max(1, seen)),
        "coverage": float((seen - abstained) / max(1, seen)),
        "answered_accuracy": float(correct.sum() / max(1, seen - abstained)),
        "macro_f1": float(np.mean([row["f1-score"] for row in per_class.values()])),
        "per_class": per_class,
        "matrix": matrix,
        "images": seen,
        "abstained": abstained,
    }


def write_report(out: Path, results: dict, args) -> None:
    classes = results["classes"]
    lines = [
        "# Tiga cara menjawab, satu dataset",
        "",
        f"* dataset `{args.data}`",
        f"* imgsz {IMAGE_SIZE}, {args.epochs} epoch, batch {args.batch}, seed {args.seed}, patience {args.patience}",
        "* backbone (`yolov8n-cls.pt`), split, dan augmentasi sama; hanya lapisan terakhir yang berbeda",
        "",
        "| varian | top-1 uji | tanpa abstain | cakupan | akurasi saat menjawab | macro-F1 | abstain | "
        + " | ".join(classes) + " |",
        "| --- | --- | --- | --- | --- | --- | --- | " + " | ".join("---" for _ in classes) + " |",
    ]
    for name, result in results["variants"].items():
        test = result["test"]
        recalls = " | ".join(f"{test['per_class'][label]['recall']:.3f}" for label in classes)
        lines.append(
            f"| {name} | {test['top1']:.4f} | {test['top1_forced']:.4f} | {test['coverage']:.3f} | "
            f"{test['answered_accuracy']:.4f} | {test['macro_f1']:.4f} | "
            f"{test['abstained']}/{test['images']} | {recalls} |"
        )
    if "heads_oracle" in results["variants"]:
        oracle = results["variants"]["heads_oracle"]["test"]
        lines += [
            "",
            f"Batas atas `heads`: dengan Category diambil dari label sebenarnya, top-1 "
            f"{oracle['top1']:.4f} (macro-F1 {oracle['macro_f1']:.4f}). Ini bukan angka yang bisa "
            "dipakai di aplikasi — aplikasi memakai Category dari gerbang atau detektor — tetapi ia "
            "memisahkan mutu penamaan di dalam Category dari mutu pemilihan Category.",
        ]
    lines += [
        "",
        "## Catatan membaca",
        "",
        "* `flat` adalah desain yang terpasang. Acuan run sebelumnya 0,6784 memakai praproses",
        "  ultralytics; skrip ini memakai resize + center crop sendiri, jadi selisih kecil pada `flat`",
        "  adalah praproses, bukan perbedaan model.",
        "* `sigmoid` memakai BCE dengan `pos_weight` sebesar rasio negatif/positif, karena tiap kepala",
        "  melihat 1.600 contoh positif lawan belasan ribu negatif. Tanpa itu semua skor jatuh di bawah",
        "  0,5 dan model menjawab \"tidak dikenali\" untuk hampir semua crop.",
        "* `heads` memakai gerbang linear untuk memilih Category. Di aplikasi gerbang itu bisa diganti",
        "  Category dari detektor; `heads_oracle` menunjukkan batas atasnya.",
        "",
    ]
    (out / "variants_report.md").write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--weights", default="yolov8n-cls.pt")
    parser.add_argument("--variants", default="flat,sigmoid,heads")
    parser.add_argument("--epochs", type=int, default=30)
    parser.add_argument("--batch", type=int, default=64)
    parser.add_argument("--fraction", type=float, default=1.0)
    parser.add_argument("--limit", type=int, default=0, help="cap images per class per split")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--patience", type=int, default=8)
    parser.add_argument("--workers", type=int, default=2)
    args = parser.parse_args(argv)

    if not torch.cuda.is_available():
        print("perhatian: tidak ada CUDA; 30 epoch pada 18 ribu crop akan memakan berjam-jam di CPU")

    classes = check_tree(args.data)
    categories = categories_for(classes)
    print(f"classes       {len(classes)}: {', '.join(classes)}")
    print("categories    " + ", ".join(f"{label}={categories[label]}" for label in classes))

    torch.manual_seed(args.seed)
    random.seed(args.seed)
    np.random.seed(args.seed)
    args.out.mkdir(parents=True, exist_ok=True)

    train_set = Crops(args.data, "train", classes, transforms_for(True), args.limit)
    if args.fraction < 1.0:
        keep = max(len(classes), int(len(train_set) * args.fraction))
        train_set.items = random.Random(args.seed).sample(train_set.items, keep)
    val_set = Crops(args.data, "val", classes, transforms_for(False), args.limit)
    test_set = Crops(args.data, "test", classes, transforms_for(False), args.limit)
    print(f"images        train {len(train_set)}  val {len(val_set)}  test {len(test_set)}")

    counts = np.zeros(len(classes))
    for _, index in train_set.items:
        counts[index] += 1
    pos_weight = torch.tensor((counts.sum() - counts) / np.maximum(counts, 1), dtype=torch.float32)
    pos_weight = pos_weight.to(DEVICE)
    print("pos_weight    " + " ".join(f"{value:.1f}" for value in pos_weight.tolist()))

    loaders = {
        "train": DataLoader(train_set, batch_size=args.batch, shuffle=True, num_workers=args.workers),
        "val": DataLoader(val_set, batch_size=args.batch, shuffle=False, num_workers=args.workers),
        "test": DataLoader(test_set, batch_size=args.batch, shuffle=False, num_workers=args.workers),
    }

    results = {"classes": classes, "categories": categories, "variants": {}}
    requested = [name.strip() for name in args.variants.split(",") if name.strip()]

    for variant in requested:
        print(f"\n=== {variant} ===", flush=True)
        model = build(variant, args.weights, classes, categories).to(DEVICE)
        optimizer = torch.optim.SGD(model.parameters(), lr=0.01, momentum=0.9, weight_decay=5e-4)
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(1, args.epochs))

        best = {"top1": -1.0, "epoch": 0, "state": None}
        stale = 0
        for epoch in range(1, args.epochs + 1):
            loss = run_epoch(model, loaders["train"], variant, optimizer, classes, categories,
                             pos_weight, True)
            scheduler.step()
            val = evaluate(model, loaders["val"], variant, classes, categories)
            print(f"epoch {epoch:2d}  loss {loss:.4f}  val top-1 {val['top1']:.4f}", flush=True)
            if val["top1"] > best["top1"]:
                best = {"top1": val["top1"], "epoch": epoch,
                        "state": {key: value.detach().cpu() for key, value in model.state_dict().items()}}
                stale = 0
            else:
                stale += 1
                if stale >= args.patience:
                    print(f"berhenti: {args.patience} epoch tanpa perbaikan")
                    break

        model.load_state_dict(best["state"])
        test = evaluate(model, loaders["test"], variant, classes, categories)
        print(f"test          top-1 {test['top1']:.4f}  macro-F1 {test['macro_f1']:.4f}  "
              f"abstain {test['abstained']}/{test['images']}")

        variants = {variant: test}
        if variant == "heads":
            variants["heads_oracle"] = evaluate(model, loaders["test"], variant, classes,
                                               categories, gate_override=True)
            print(f"test oracle   top-1 {variants['heads_oracle']['top1']:.4f} "
                  f"(Category dari label)")

        for name, measured in variants.items():
            folder = args.out / name
            folder.mkdir(parents=True, exist_ok=True)
            with (folder / "confusion_matrix_test.csv").open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(("predicted \\ true", *classes))
                for index, label in enumerate(classes):
                    writer.writerow((label, *[int(value) for value in measured["matrix"][index]]))
            with (folder / "classification_report_test.csv").open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(("label", "precision", "recall", "f1-score", "support"))
                for label in classes:
                    row = measured["per_class"][label]
                    writer.writerow((label, f"{row['precision']:.4f}", f"{row['recall']:.4f}",
                                     f"{row['f1-score']:.4f}", row["support"]))
                writer.writerow(("macro avg", "", "", f"{measured['macro_f1']:.4f}", measured["images"]))
            results["variants"][name] = {
                "best_epoch": best["epoch"],
                "val_top1": best["top1"],
                "test": {key: (value.tolist() if isinstance(value, np.ndarray) else value)
                         for key, value in measured.items()},
            }

    (args.out / "variants.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    write_report(args.out, results, args)
    print(f"\nlaporan       {args.out / 'variants_report.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
