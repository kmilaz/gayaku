#!/usr/bin/env python3
"""Turn the Fashionpedia release into a YOLO detection tree the app's detector can train on.

Fashionpedia annotates whole garments **and their parts** - 27 item categories plus 19 categories
that are regions of an item (`hood`, `collar`, `sleeve`, `pocket`, `zipper`, ...). This script keeps
the items, maps them onto the five Categories from `CONTEXT.md` (which `labels.json` already uses),
and drops the parts; otherwise a detector learns to box a sleeve.

    # full conversion (46,781 photographs, ~3.5 GB of parquet to read)
    python ml_workspace/scripts/fashionpedia_to_yolo.py

    # 300 photographs per split, to check the mapping before the long run
    python ml_workspace/scripts/fashionpedia_to_yolo.py --limit-per-split 300 --out .amp/in/fp_smoke

The detector predicts a Category, not one of the 18 fine classes: `docs/adr/0009`. The classifier
names the crop inside each box, so this tree only has to answer "where" and "which shelf".

Outputs (`--out`, git-ignored; the manifest is the evidence worth keeping):

    images/{train,val,test}/<split>_<image_id>.jpg
    labels/{train,val,test}/<split>_<image_id>.txt   `cls cx cy w h`, normalised, one box per line
    data.yaml                                        ultralytics dataset file
    manifest.json                                    mapping applied, per-slot counts, what was dropped

Reads the HuggingFace parquet mirror `detection-datasets/fashionpedia` through `datasets`
(annotations are CC BY 4.0; the photographs keep the terms of the sites they came from). That
dependency is why this script is run with `ml_workspace/yolo/.venv-convert312`, not with the
repository's default interpreter:

    uv pip install --python ml_workspace/yolo/.venv-convert312/Scripts/python.exe datasets
"""

from __future__ import annotations

import argparse
import io
import json
import random
import shutil
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_HF_DIR = REPO_ROOT / "ml_workspace" / "data" / "fashionpedia_hf"
DEFAULT_OUT = REPO_ROOT / "ml_workspace" / "data" / "fashionpedia_yolo"

#: The five Categories from CONTEXT.md, in the order the detector's class indices take.
CATEGORIES = ("Tops", "Bottoms", "Outerwear", "Shoes", "Accessories")

#: Fashionpedia item category -> Category. Every mapping follows ml_workspace/labels.json where
#: that table already has an opinion: `sweater`/`cardigan` are Outerwear there (Sweter), `dress`
#: is Tops (Gaun), `jumpsuit` is Tops, `vest` is Outerwear (Waistcoat).
ITEM_CATEGORIES = {
    "shirt, blouse": "Tops",
    "top, t-shirt, sweatshirt": "Tops",
    "dress": "Tops",
    "jumpsuit": "Tops",
    "pants": "Bottoms",
    "shorts": "Bottoms",
    "skirt": "Bottoms",
    "sweater": "Outerwear",
    "cardigan": "Outerwear",
    "jacket": "Outerwear",
    "vest": "Outerwear",
    "coat": "Outerwear",
    "cape": "Outerwear",
    "shoe": "Shoes",
    "hat": "Accessories",
    "glasses": "Accessories",
    "bag, wallet": "Accessories",
    "belt": "Accessories",
    "scarf": "Accessories",
    "tie": "Accessories",
    "glove": "Accessories",
    "watch": "Accessories",
    "sock": "Accessories",
    "tights, stockings": "Accessories",
    "leg warmer": "Accessories",
    "headband, head covering, hair accessory": "Accessories",
    "umbrella": "Accessories",
}

#: The 19 categories that describe a region of an item, not an item. Dropped on purpose.
PART_CATEGORIES = {
    "hood",
    "collar",
    "lapel",
    "epaulette",
    "sleeve",
    "pocket",
    "neckline",
    "buckle",
    "zipper",
    "applique",
    "bead",
    "bow",
    "flower",
    "fringe",
    "ribbon",
    "rivet",
    "ruffle",
    "sequin",
    "tassel",
}


class ConvertError(Exception):
    """A condition that would produce a tree with wrong boxes or wrong classes."""


def read_category_names(path: Path) -> list[str]:
    """The release's 46 category names, read from the HuggingFace `dataset_infos.json`.

    The parquet files store categories as integers; this file is where the integer -> name table
    lives, so it is what `check_schema` validates against instead of a list copied by hand.
    """
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ConvertError(
            f"{path} is missing -- it holds the category names. Download it next to the shards: "
            "https://huggingface.co/datasets/detection-datasets/fashionpedia/resolve/main/dataset_infos.json"
        ) from exc
    entry = next(iter(doc.values()))
    names = entry["features"]["objects"]["feature"]["category"]["names"]
    if not isinstance(names, list) or not names:
        raise ConvertError(f"{path}: no category names under features.objects.feature.category")
    return names


def decode_image(value) -> Image.Image:
    """The image column arrives as either a decoded PIL image or `{bytes, path}`."""
    if isinstance(value, dict):
        payload = value.get("bytes")
        if payload is None:
            raise ConvertError("the image column has no bytes; the parquet shard is malformed")
        return Image.open(io.BytesIO(payload))
    return value


def check_schema(names: list[str]) -> None:
    """The release's category list must be exactly the one this mapping was written for."""
    known = set(ITEM_CATEGORIES) | PART_CATEGORIES
    unknown = sorted(set(names) - known)
    missing = sorted(known - set(names))
    if unknown or missing:
        raise ConvertError(
            "Fashionpedia's category list changed: "
            f"unknown {unknown}, missing {missing}. Update ITEM_CATEGORIES before converting - an "
            "unmapped category would otherwise be dropped silently and the detector would never "
            "learn it."
        )


def yolo_lines(boxes: list[list[float]], category_ids: list[int], width: int, height: int, min_px: float):
    """`cls cx cy w h` lines plus counters for what was dropped."""
    lines = []
    dropped_unknown = dropped_tiny = dropped_invalid = 0
    for bbox, category_id in zip(boxes, category_ids):
        name = CATEGORY_NAMES[category_id]
        category = ITEM_CATEGORIES.get(name)
        if category is None:
            if name in PART_CATEGORIES:
                dropped_unknown += 1
            else:  # pragma: no cover - check_schema already refuses this
                raise ConvertError(f"category {name!r} is neither an item nor a known part")
            continue
        x1, y1, x2, y2 = (float(value) for value in bbox)
        x1, x2 = max(0.0, min(x1, x2)), min(float(width), max(x1, x2))
        y1, y2 = max(0.0, min(y1, y2)), min(float(height), max(y1, y2))
        w, h = x2 - x1, y2 - y1
        if w < min_px or h < min_px:
            dropped_tiny += 1
            continue
        if w <= 0 or h <= 0:
            dropped_invalid += 1
            continue
        cx, cy = (x1 + x2) / 2 / width, (y1 + y2) / 2 / height
        index = CATEGORIES.index(category)
        lines.append(f"{index} {cx:.6f} {cy:.6f} {w / width:.6f} {h / height:.6f}")
    return lines, dropped_unknown, dropped_tiny, dropped_invalid


CATEGORY_NAMES: list[str] = []


def convert_split(
    split: str,
    rows,
    out: Path,
    limit: int,
    test_count: int,
    seed: int,
    min_px: float,
    skip_existing: bool = False,
) -> dict:
    """Write one split's photographs and labels; returns its counters."""
    label_dir = out / "labels" / split
    image_dir = out / "images" / split
    label_dir.mkdir(parents=True, exist_ok=True)
    image_dir.mkdir(parents=True, exist_ok=True)

    stats = {
        "rows_seen": 0,
        "images_written": 0,
        "images_reused": 0,
        "boxes_written": 0,
        "dropped_parts": 0,
        "dropped_tiny": 0,
        "dropped_invalid": 0,
        "images_without_items": 0,
        "per_category": Counter(),
    }
    for index, row in enumerate(rows):
        if limit and index >= limit:
            break
        stats["rows_seen"] += 1
        objects = row["objects"]
        boxes = objects["bbox"]
        categories = objects["category"]
        width, height = int(row["width"]), int(row["height"])
        lines, parts, tiny, invalid = yolo_lines(boxes, categories, width, height, min_px)
        stats["dropped_parts"] += parts
        stats["dropped_tiny"] += tiny
        stats["dropped_invalid"] += invalid
        if not lines:
            stats["images_without_items"] += 1
            continue
        stem = f"{split}_{row['image_id']}"
        image_path = image_dir / f"{stem}.jpg"
        label_path = label_dir / f"{stem}.txt"
        if skip_existing and image_path.is_file() and label_path.is_file():
            # Counters are rebuilt from the label on disk, not from the row, so a resumed run
            # reports the tree as it stands. Dropped-box counters still describe every row,
            # because `yolo_lines` above has already run.
            reused = [line for line in label_path.read_text(encoding="utf-8").splitlines() if line.strip()]
            stats["images_reused"] += 1
            stats["boxes_written"] += len(reused)
            for line in reused:
                stats["per_category"][CATEGORIES[int(line.split()[0])]] += 1
            continue
        decode_image(row["image"]).convert("RGB").save(image_path, "JPEG", quality=92)
        label_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        stats["images_written"] += 1
        stats["boxes_written"] += len(lines)
        for line in lines:
            stats["per_category"][CATEGORIES[int(line.split()[0])]] += 1
        if stats["rows_seen"] % 500 == 0:
            print(f"  {split}: {stats['rows_seen']} rows, {stats['images_written']} images written")
    stats["per_category"] = dict(sorted(stats["per_category"].items()))
    return stats


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--hf-dir", type=Path, default=DEFAULT_HF_DIR)
    parser.add_argument(
        "--dataset-info",
        type=Path,
        default=None,
        help="the HuggingFace metadata file that maps category integers to names "
        "(default: <hf-dir>/dataset_infos.json)",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--limit-per-split", type=int, default=0, help="smoke run: cap rows per split")
    parser.add_argument("--test-from-train", type=int, default=2000,
                        help="photographs carved out of train as the test split (default: %(default)s)")
    parser.add_argument("--seed", type=int, default=20261102)
    parser.add_argument("--min-box-px", type=float, default=8.0, help="drop boxes thinner than this")
    parser.add_argument("--force", action="store_true", help="rebuild the output tree")
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="reuse photographs already written to --out; unsafe to combine with a different --min-box-px",
    )
    args = parser.parse_args(argv)
    if args.dataset_info is None:
        # Default to the metadata beside the shards. A Kaggle run downloads both into
        # /kaggle/temp, while the repository default only exists on a developer machine --
        # reading the wrong path there failed with "missing" for a file that was present.
        args.dataset_info = args.hf_dir / "dataset_infos.json"

    try:
        parquet = sorted((args.hf_dir / "data").glob("*.parquet"))
        if not parquet:
            raise ConvertError(
                f"{args.hf_dir}/data has no parquet shards -- download them with "
                "huggingface_hub.snapshot_download('detection-datasets/fashionpedia')"
            )
        try:
            from datasets import load_dataset
        except ImportError as exc:
            raise ConvertError(
                "`datasets` is not installed in this interpreter; install it with "
                "uv pip install --python ml_workspace/yolo/.venv-convert312/Scripts/python.exe datasets"
            ) from exc

        if args.force and args.out.exists():
            shutil.rmtree(args.out)
        args.out.mkdir(parents=True, exist_ok=True)

        files = {
            "train": sorted(str(path) for path in parquet if path.name.startswith("train-")),
            "validation": sorted(str(path) for path in parquet if path.name.startswith("val-")),
        }
        print(f"reading {len(files['train'])} train shards and {len(files['validation'])} val shards")
        dataset = load_dataset(
            "parquet",
            data_files=files,
            cache_dir=str(args.hf_dir / "cache"),
        )
        CATEGORY_NAMES.extend(read_category_names(args.dataset_info))
        check_schema(CATEGORY_NAMES)
        print(f"categories: {len(CATEGORY_NAMES)} ({len(ITEM_CATEGORIES)} items, {len(PART_CATEGORIES)} parts)")

        # `val` stays the published validation split; the test photographs come out of train so a
        # reported number has never influenced the epoch choice.
        train_rows = dataset["train"]
        order = list(range(len(train_rows)))
        random.Random(args.seed).shuffle(order)
        test_ids = set(order[: args.test_from_train if not args.limit_per_split else min(args.test_from_train, 200)])
        test_rows = train_rows.select(sorted(test_ids))
        train_rest = train_rows.select([i for i in order if i not in test_ids])

        splits = {"train": train_rest, "val": dataset["validation"], "test": test_rows}
        results = {}
        for split, rows in splits.items():
            print(f"converting {split} ({len(rows)} rows)")
            results[split] = convert_split(
                split, rows, args.out, args.limit_per_split, args.test_from_train, args.seed,
                args.min_box_px, args.skip_existing,
            )

        (args.out / "data.yaml").write_text(
            "path: .\n"
            "train: images/train\n"
            "val: images/val\n"
            "test: images/test\n"
            f"names: {list(CATEGORIES)}\n",
            encoding="utf-8",
        )
        manifest = {
            "version": 1,
            "source": "detection-datasets/fashionpedia (HuggingFace mirror of the ECCV 2020 release)",
            "annotation_licence": "CC BY 4.0",
            "note": "photographs keep the terms of the sites they came from; see docs/adr/0009",
            "categories": list(CATEGORIES),
            "mapping": {name: category for name, category in sorted(ITEM_CATEGORIES.items())},
            "dropped_part_categories": sorted(PART_CATEGORIES),
            "options": {
                "seed": args.seed,
                "test_from_train": args.test_from_train,
                "min_box_px": args.min_box_px,
                "limit_per_split": args.limit_per_split,
                "skip_existing": args.skip_existing,
            },
            "splits": results,
        }
        (args.out / "manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

        print()
        print(f"{'split':<12}{'images':>8}{'boxes':>9}  per Category")
        for split, stats in results.items():
            print(
                f"{split:<12}{stats['images_written'] + stats['images_reused']:>8}"
                f"{stats['boxes_written']:>9}  {stats['per_category']}"
            )
        reused = {split: stats["images_reused"] for split, stats in results.items()}
        if any(reused.values()):
            print(f"reused from a previous run (not re-encoded): {reused}")
        dropped = {split: stats["dropped_parts"] for split, stats in results.items()}
        print(f"part boxes dropped: {dropped}")
        empty = {split: stats["images_without_items"] for split, stats in results.items()}
        print(f"images with no item box (skipped): {empty}")
        print(f"written: {args.out / 'data.yaml'}")
        print(f"written: {args.out / 'manifest.json'}")
        return 0
    except ConvertError as exc:
        print(f"fashionpedia_to_yolo: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
