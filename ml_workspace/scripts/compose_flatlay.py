#!/usr/bin/env python3
"""Build flat-lay scenes with exact boxes from single-garment photographs.

`Clothes_Dataset` and `clothing-dataset-small` hold one garment per photograph and no annotations.
This script cuts each garment out with the matte model the app already ships, then pastes several
cut-outs onto one canvas, so every pasted garment yields a box for free:

    python ml_workspace/scripts/compose_flatlay.py \\
        --source ml_workspace/bootstrap/data/clothing-dataset-small/train \\
        --backgrounds /path/to/flat-lay/photos \\
        --out ml_workspace/data/flatlay --count 2000 --val 200

Outputs, all under `--out`:

    images/{train,val}/*.jpg     the scenes
    labels/{train,val}/*.txt     YOLO boxes, one class: `0 cx cy w h`
    crops/{train,val}/<class>/   each garment cropped from its scene, for the classifier
    cutouts/<class>/*.png        cached RGBA cut-outs, so a rerun does not repeat the matte
    manifest.json                counts, classes, and the settings that produced the tree

The classifier crops come from the finished scenes on purpose: at inference the detector hands the
classifier a crop that still contains floor and neighbouring garments, so training on clean
photographs would teach the wrong input distribution.

The matte runs on the CPU through LiteRT (no torch needed):

    ml_workspace/yolo/.venv-convert312/Scripts/python.exe -m pip install ai-edge-litert pillow numpy
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MATTE = REPO_ROOT / "flutter_app" / "assets" / "models" / "u2netp_320.tflite"
MATTE_SIZE = 320
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
CLASS_INDEX = 0  # one-class detector: the box says "a garment is here", nothing else


class ComposeError(Exception):
    """A condition that would produce a tree nobody should train on."""


def load_classes(source: Path) -> list[str]:
    if not source.is_dir():
        raise ComposeError(f"{source} does not exist")
    classes = sorted(entry.name for entry in source.iterdir() if entry.is_dir())
    if not classes:
        raise ComposeError(f"{source} holds no class folders")
    for label in classes:
        if not any((source / label).iterdir()):
            raise ComposeError(f"class {label} is empty")
    return classes


class Matte:
    """U²-Net's first output, the saliency map the app uses for dominant colour."""

    def __init__(self, path: Path) -> None:
        if not path.is_file():
            raise ComposeError(f"{path} does not exist")
        from ai_edge_litert.interpreter import Interpreter

        self.interpreter = Interpreter(model_path=str(path))
        self.interpreter.allocate_tensors()
        self.input = self.interpreter.get_input_details()[0]
        self.output = self.interpreter.get_output_details()[0]

    def mask(self, image: Image.Image) -> np.ndarray:
        small = image.convert("RGB").resize((MATTE_SIZE, MATTE_SIZE), Image.BILINEAR)
        array = (np.asarray(small, dtype=np.float32) / 255.0)[None, ...]
        self.interpreter.set_tensor(self.input["index"], array)
        self.interpreter.invoke()
        raw = self.interpreter.get_tensor(self.output["index"])[0, :, :, 0]
        raw = (raw - raw.min()) / max(1e-6, raw.max() - raw.min())
        return np.asarray(
            Image.fromarray((raw * 255).astype(np.uint8)).resize(image.size, Image.BILINEAR),
            dtype=np.float32,
        ) / 255.0


def cut_out(path: Path, matte: Matte, cache: Path, label: str) -> Image.Image | None:
    """RGBA cut-out cropped to the garment, cached per photograph."""
    cached = cache / label / f"{path.stem}.png"
    if cached.is_file():
        with Image.open(cached) as image:
            return image.convert("RGBA").copy()

    with Image.open(path) as source:
        image = source.convert("RGB")
    alpha = matte.mask(image)
    binary = alpha >= 0.5
    if binary.sum() < 0.02 * binary.size:            # the matte found almost nothing
        return None
    rows = np.where(binary.any(axis=1))[0]
    cols = np.where(binary.any(axis=0))[0]
    top, bottom = int(rows[0]), int(rows[-1]) + 1
    left, right = int(cols[0]), int(cols[-1]) + 1
    if bottom - top < 32 or right - left < 32:
        return None

    # A mask that fills its own bounding box is not a garment: it is the matte giving up on a
    # photograph it could not separate (folded fabric, a busy print). Pasting that teaches the
    # detector to find rectangles, so the source is skipped instead.
    box_area = (bottom - top) * (right - left)
    if binary[top:bottom, left:right].mean() > 0.97 or box_area > 0.97 * binary.size:
        return None

    rgba = image.convert("RGBA")
    rgba.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8)))
    cut = rgba.crop((left, top, right, bottom))
    cached.parent.mkdir(parents=True, exist_ok=True)
    cut.save(cached)
    return cut


def procedural_background(size: tuple[int, int], rng: random.Random) -> Image.Image:
    """A floor-like backdrop: tiles, planks, carpet, or a plain wall.

    Made rather than borrowed on purpose. Any real photograph of clothes brings garments that carry
    no box, which teaches the detector to ignore exactly what it must find.
    """
    width, height = size
    kind = rng.choice(("tiles", "planks", "carpet", "plain"))
    base = np.array([rng.randint(120, 225) for _ in range(3)], dtype=np.float32)
    canvas = np.ones((height, width, 3), dtype=np.float32) * base

    if kind == "tiles":
        step = rng.choice((64, 80, 96, 120))
        grout = rng.randint(6, 14)
        for y in range(0, height, step):
            for x in range(0, width, step):
                shade = rng.uniform(-18, 18)
                canvas[y:y + step - grout, x:x + step - grout] = np.clip(base + shade, 0, 255)
    elif kind == "planks":
        plank = rng.randint(70, 130)
        for y in range(0, height, plank):
            shade = rng.uniform(-25, 15)
            canvas[y:y + plank - 4] = np.clip(base + shade, 0, 255)
    elif kind == "carpet":
        canvas += np.random.default_rng(rng.randint(0, 10**6)).normal(0, 14, canvas.shape)
        canvas = np.asarray(
            Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        ).astype(np.float32)
    else:
        top = np.array([rng.randint(140, 235) for _ in range(3)], dtype=np.float32)
        bottom = np.array([rng.randint(140, 235) for _ in range(3)], dtype=np.float32)
        ramp = np.linspace(0, 1, height, dtype=np.float32)[:, None, None]
        canvas = top[None, None, :] * (1 - ramp) + bottom[None, None, :] * ramp
        canvas = np.repeat(canvas, width, axis=1)

    canvas += np.random.default_rng(rng.randint(0, 10**6)).normal(0, 4, canvas.shape)
    return Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8))


def background(size: tuple[int, int], folder: Path | None, rng: random.Random) -> Image.Image:
    if folder is not None and folder.is_dir():
        files = [p for p in folder.rglob("*") if p.suffix.lower() in IMAGE_SUFFIXES]
        if files:
            with Image.open(rng.choice(files)) as photo:
                return crop_to_square(photo.convert("RGB"), size)
    return procedural_background(size, rng)


def crop_to_square(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    width, height = size
    side = min(image.size)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    return image.crop((left, top, left + side, top + side)).resize((width, height), Image.BILINEAR)


def cells(count: int, size: tuple[int, int], rng: random.Random) -> list[tuple[int, int, int, int]]:
    """A jittered grid so pasted garments tile the canvas without hiding each other."""
    columns = 2 if count <= 2 else 3
    rows = (count + columns - 1) // columns
    width, height = size
    box_w, box_h = width // columns, height // rows
    slots = [(column * box_w, row * box_h, box_w, box_h)
             for row in range(rows) for column in range(columns)]
    rng.shuffle(slots)
    chosen = []
    for left, top, slot_w, slot_h in slots[:count]:
        jitter_x = rng.randint(-slot_w // 10, slot_w // 10)
        jitter_y = rng.randint(-slot_h // 10, slot_h // 10)
        chosen.append((left + jitter_x, top + jitter_y, slot_w, slot_h))
    return chosen


def paste_canvas(items, size, rng: random.Random):
    """Composite the cut-outs; return the canvas and the box of every garment, in pixels."""
    canvas = background(size, items["backgrounds"], rng).convert("RGBA")
    boxes = []
    for (left, top, slot_w, slot_h), (label, cut) in zip(cells(len(items["garments"]), size, rng), items["garments"]):
        scale = min(slot_w * 0.92 / cut.width, slot_h * 0.92 / cut.height)
        scale *= rng.uniform(0.75, 1.0)
        resized = cut.resize((max(8, int(cut.width * scale)), max(8, int(cut.height * scale))), Image.LANCZOS)
        resized = resized.rotate(rng.uniform(-12, 12), expand=True, resample=Image.BICUBIC)
        x = left + (slot_w - resized.width) // 2 + rng.randint(-8, 8)
        y = top + (slot_h - resized.height) // 2 + rng.randint(-8, 8)
        x = max(0, min(size[0] - resized.width, x))
        y = max(0, min(size[1] - resized.height, y))
        canvas.alpha_composite(resized, (x, y))
        boxes.append((label, (x, y, x + resized.width, y + resized.height)))
    return canvas.convert("RGB"), boxes


def write_scene(canvas: Image.Image, boxes, split: str, index: int, out: Path, classes: list[str]) -> dict:
    stem = f"flatlay_{split}_{index:05d}"
    image_folder = out / "images" / split
    label_folder = out / "labels" / split
    crop_folder = out / "crops" / split
    for folder in (image_folder, label_folder, crop_folder):
        folder.mkdir(parents=True, exist_ok=True)

    canvas.save(image_folder / f"{stem}.jpg", "JPEG", quality=92)
    width, height = canvas.size
    lines = []
    for label, (x0, y0, x1, y1) in boxes:
        cx, cy = (x0 + x1) / 2 / width, (y0 + y1) / 2 / height
        bw, bh = (x1 - x0) / width, (y1 - y0) / height
        lines.append(f"{CLASS_INDEX} {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}")

        margin_x, margin_y = (x1 - x0) * 0.18, (y1 - y0) * 0.18
        box = (max(0, int(x0 - margin_x)), max(0, int(y0 - margin_y)),
               min(width, int(x1 + margin_x)), min(height, int(y1 + margin_y)))
        crop = canvas.crop(box).resize((256, 256), Image.BILINEAR)
        target = crop_folder / label
        target.mkdir(parents=True, exist_ok=True)
        crop.save(target / f"{stem}_{len(lines) - 1:02d}.jpg", "JPEG", quality=92)

    (label_folder / f"{stem}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {"image": f"images/{split}/{stem}.jpg", "items": [label for label, _ in boxes]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, required=True, help="class folders of single garments")
    parser.add_argument("--backgrounds", type=Path, default=None,
                        help="optional folder of backdrop photographs; only use images without garments "
                             "in them, otherwise they teach the detector to ignore real garments")
    parser.add_argument("--matte", type=Path, default=DEFAULT_MATTE)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--count", type=int, default=2000)
    parser.add_argument("--val", type=float, default=0.1, help="fraction of scenes used for validation")
    parser.add_argument("--min-items", type=int, default=2)
    parser.add_argument("--max-items", type=int, default=6)
    parser.add_argument("--size", type=int, default=800)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--max-sources", type=int, default=0, help="limit source photographs, 0 = all")
    args = parser.parse_args(argv)

    if args.min_items < 1 or args.max_items < args.min_items:
        raise ComposeError("--min-items/--max-items are inconsistent")
    classes = load_classes(args.source)
    rng = random.Random(args.seed)
    np.random.seed(args.seed)
    matte = Matte(args.matte)
    out = args.out

    photos: dict[str, list[Path]] = {}
    for label in classes:
        files = sorted(p for p in (args.source / label).rglob("*") if p.suffix.lower() in IMAGE_SUFFIXES)
        if args.max_sources:
            files = files[: args.max_sources]
        photos[label] = files
    print(f"classes       {len(classes)}: {', '.join(classes)}")
    print(f"sources       {sum(len(v) for v in photos.values())} photographs")
    print(f"scenes        {args.count} ({args.val:.0%} validation)")

    cache = out / "cutouts"
    cutouts: dict[str, list[Image.Image]] = {label: [] for label in classes}
    for label in classes:
        for path in photos[label]:
            cut = cut_out(path, matte, cache, label)
            if cut is not None:
                cutouts[label].append(cut)
        print(f"  {label:16s} {len(cutouts[label])} cut-outs", flush=True)
    usable = [label for label in classes if cutouts[label]]
    if len(usable) < 2:
        raise ComposeError("fewer than two classes produced cut-outs; check --matte and the source")

    val_count = round(args.count * args.val)
    manifest = {"count": args.count, "val": val_count, "classes": usable,
                "settings": {key: str(value) for key, value in vars(args).items()}, "scenes": []}
    for index in range(args.count):
        split = "val" if index < val_count else "train"
        k = rng.randint(args.min_items, args.max_items)
        garments = []
        for _ in range(k):
            label = rng.choice(usable)
            garments.append((label, rng.choice(cutouts[label])))
        payload = {"garments": garments, "backgrounds": args.backgrounds}
        canvas, boxes = paste_canvas(payload, (args.size, args.size), rng)
        manifest["scenes"].append({"split": split, **write_scene(canvas, boxes, split, index, out, usable)})
        if (index + 1) % 100 == 0:
            print(f"  {index + 1}/{args.count} scenes", flush=True)

    (out / "flatlay_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (out / "data.yaml").write_text(
        f"path: {out.resolve().as_posix()}\ntrain: images/train\nval: images/val\nnames: ['garment']\n",
        encoding="utf-8",
    )
    print(f"written       {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
