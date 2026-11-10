"""Cut Fashionpedia's item boxes into a classification tree, one class per garment type.

The detector's training set annotates garments worn by people, and ADR-0012 makes that the scan
contract, so the classifier is taught from the same photographs: every item box becomes one crop,
labelled with the class its Fashionpedia category maps to.

Splitting happens per **photograph**, never per crop, so the same person cannot appear on both
sides of a train/test boundary. Each class is capped per split (`--per-class`, 80/10/10 by
default) which is what keeps a 46,000-box class from drowning a 719-box one.

Output::

    <out>/{train,val,test}/<Class>/<image_id>_<n>.jpg
    <out>/manifest.json            mapping applied, counts, cap, seed, what was dropped

Run it with the conversion interpreter, which has `datasets` and `pillow`:

    ml_workspace/yolo/.venv-convert312/Scripts/python.exe ml_workspace/scripts/fashionpedia_crops.py
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import random
import shutil
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_HF_DIR = REPO_ROOT / "ml_workspace" / "data" / "fashionpedia_hf"
DEFAULT_OUT = REPO_ROOT / "ml_workspace" / "data" / "crops"

#: Fashionpedia item category -> the class the app shows. Accessories are absent on purpose:
#: bags, belts, ties and watches have no garment class, so a box for one is not a training
#: example for any of these.
CATEGORY_TO_CLASS = {
    "shoe": "Sepatu",
    "dress": "Gaun",
    "jumpsuit": "Gaun",
    "top, t-shirt, sweatshirt": "Kaos",
    "pants": "Celana_Panjang",
    "jacket": "Jaket",
    "shirt, blouse": "Kemeja",
    "skirt": "Rok",
    "coat": "Mantel",
    "cape": "Mantel",
    "shorts": "Celana_Pendek",
    "sweater": "Sweter",
    "cardigan": "Sweter",
    "hat": "Topi",
    "vest": "Rompi",
}

SPLITS = ("train", "val", "test")
SPLIT_SHARE = {"train": 0.8, "val": 0.1, "test": 0.1}
MARGIN = 0.05
MIN_PX = 8.0


class CropError(Exception):
    """A condition that would produce a misleading tree."""


def read_category_names(path: Path) -> list[str]:
    doc = json.loads(path.read_text(encoding="utf-8"))
    entry = next(iter(doc.values()))
    names = entry["features"]["objects"]["feature"]["category"]["names"]
    if not isinstance(names, list) or not names:
        raise CropError(f"{path}: no category names under features.objects.feature.category")
    return names


def split_of(image_id: int, seed: int) -> str:
    """Which split one photograph belongs to, stable across runs and independent of row order."""
    digest = hashlib.sha256(f"{seed}:{image_id}".encode("utf-8")).hexdigest()
    bucket = int(digest[:8], 16) / 0xFFFFFFFF
    if bucket < SPLIT_SHARE["train"]:
        return "train"
    if bucket < SPLIT_SHARE["train"] + SPLIT_SHARE["val"]:
        return "val"
    return "test"


def crop_box(image: Image.Image, bbox: list[float]) -> Image.Image | None:
    width, height = image.size
    x, y, w, h = bbox
    margin_x, margin_y = w * MARGIN, h * MARGIN
    left = max(0, int(x - margin_x))
    top = max(0, int(y - margin_y))
    right = min(width, int(x + w + margin_x))
    bottom = min(height, int(y + h + margin_y))
    if right - left < 8 or bottom - top < 8:
        return None
    return image.crop((left, top, right, bottom))


def decode_image(payload) -> Image.Image:
    if isinstance(payload, dict) and "bytes" in payload:
        payload = payload["bytes"]
    return Image.open(io.BytesIO(payload)).convert("RGB")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--hf-dir", type=Path, default=DEFAULT_HF_DIR)
    parser.add_argument("--dataset-info", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--per-class",
        type=int,
        default=2000,
        help="crops kept per class overall, spread 80/10/10 across the splits (default: %(default)s)",
    )
    parser.add_argument("--seed", type=int, default=20261110)
    parser.add_argument("--force", action="store_true", help="rebuild the output tree")
    args = parser.parse_args(argv)

    if args.dataset_info is None:
        args.dataset_info = args.hf_dir / "dataset_infos.json"

    try:
        parquet = sorted((args.hf_dir / "data").glob("train-*.parquet"))
        if not parquet:
            raise CropError(f"{args.hf_dir}/data has no train parquet shards")
        try:
            from datasets import load_dataset
        except ImportError as exc:
            raise CropError(
                "`datasets` is not installed in this interpreter; run it with "
                "ml_workspace/yolo/.venv-convert312/Scripts/python.exe"
            ) from exc

        names = read_category_names(args.dataset_info)
        unknown = {k for k in CATEGORY_TO_CLASS if k not in names}
        if unknown:
            raise CropError(f"categories missing from {args.dataset_info}: {sorted(unknown)}")

        if args.force and args.out.exists():
            shutil.rmtree(args.out)
        for split in SPLITS:
            for label in sorted(set(CATEGORY_TO_CLASS.values())):
                (args.out / split / label).mkdir(parents=True, exist_ok=True)

        dataset = load_dataset(
            "parquet",
            data_files={"train": [str(path) for path in parquet]},
            cache_dir=str(args.hf_dir / "cache"),
            split="train",
        )
        print(f"reading {dataset.num_rows} rows from {len(parquet)} shards")

        # Cap per split, so a class cannot be all train and no test.
        caps = {
            split: max(1, round(args.per_class * share))
            for split, share in SPLIT_SHARE.items()
        }
        counts: dict[str, Counter] = {split: Counter() for split in SPLITS}
        seen_images: dict[str, set[int]] = {split: set() for split in SPLITS}
        dropped = Counter()

        order = list(range(dataset.num_rows))
        random.Random(args.seed).shuffle(order)
        for position in order:
            row = dataset[position]
            split = split_of(int(row["image_id"]), args.seed)
            objects = row["objects"]
            boxes = objects["bbox"]
            categories = objects["category"]
            if not boxes:
                continue

            image: Image.Image | None = None
            for index, (bbox, category_id) in enumerate(zip(boxes, categories)):
                name = names[category_id]
                label = CATEGORY_TO_CLASS.get(name)
                if label is None:
                    dropped[name] += 1
                    continue
                if bbox[2] < MIN_PX or bbox[3] < MIN_PX:
                    dropped["box too small"] += 1
                    continue
                if counts[split][label] >= caps[split]:
                    continue
                if image is None:
                    image = decode_image(row["image"])
                crop = crop_box(image, bbox)
                if crop is None:
                    dropped["crop too small"] += 1
                    continue
                filename = f"{row['image_id']}_{index}.jpg"
                crop.save(args.out / split / label / filename, "JPEG", quality=92)
                counts[split][label] += 1
                seen_images[split].add(int(row["image_id"]))

        shared = set.intersection(*(seen_images[split] for split in SPLITS))
        if shared:
            raise CropError(f"{len(shared)} photographs landed in more than one split")

        per_split = {split: dict(sorted(counts[split].items())) for split in SPLITS}
        total = {label: sum(per_split[split].get(label, 0) for split in SPLITS)
                 for label in sorted(set(CATEGORY_TO_CLASS.values()))}
        manifest = {
            "version": 1,
            "source": "detection-datasets/fashionpedia (HuggingFace mirror of the ECCV 2020 release)",
            "annotation_licence": "CC BY 4.0",
            "note": "photographs keep the terms of the sites they came from; see docs/adr/0012",
            "classes": sorted(set(CATEGORY_TO_CLASS.values())),
            "mapping": dict(sorted(CATEGORY_TO_CLASS.items())),
            "options": {
                "per_class": args.per_class,
                "per_split_cap": caps,
                "seed": args.seed,
                "margin": MARGIN,
                "min_box_px": MIN_PX,
            },
            "splits": per_split,
            "totals": total,
            "dropped": dict(dropped.most_common()),
        }
        (args.out / "manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

        print()
        header = "class".ljust(18) + "".join(split.rjust(8) for split in SPLITS) + "total".rjust(9)
        print(header)
        for label in manifest["classes"]:
            row = [per_split[split].get(label, 0) for split in SPLITS]
            print(f"{label:18s}" + "".join(str(count).rjust(8) for count in row) + str(total[label]).rjust(9))
        print(
            f"{'TOTAL':18s}"
            + "".join(str(sum(per_split[split].values())).rjust(8) for split in SPLITS)
            + str(sum(total.values())).rjust(9)
        )
        print(f"\nwritten: {args.out / 'manifest.json'}")
        return 0
    except CropError as exc:
        print(f"fashionpedia_crops: {exc}", file=__import__("sys").stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
