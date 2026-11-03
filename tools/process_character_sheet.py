#!/usr/bin/env python3
"""Extract the eight user-supplied Razor Path poses from a 4x2 sprite sheet.

The sheet has a white page background. Only page-connected near-white pixels are
made transparent; enclosed white fills inside the outlined character are kept.
Each output preserves the same 160x292 cell canvas so its foot baseline/pivot is
identical across poses and animation frames cannot jump due to trimming.
"""
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def exterior_background_mask(rgb: np.ndarray, threshold: int) -> np.ndarray:
    """Return near-white pixels connected to the outer page edge (4-connected)."""
    near_white = (
        (rgb.min(axis=2) >= threshold)
        & ((rgb.max(axis=2) - rgb.min(axis=2)) <= 14)
    )
    height, width = near_white.shape
    outside = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def seed(y: int, x: int) -> None:
        if near_white[y, x] and not outside[y, x]:
            outside[y, x] = True
            queue.append((y, x))

    for x in range(width):
        seed(0, x)
        seed(height - 1, x)
    for y in range(height):
        seed(y, 0)
        seed(y, width - 1)

    while queue:
        y, x = queue.popleft()
        if y > 0:
            seed(y - 1, x)
        if y + 1 < height:
            seed(y + 1, x)
        if x > 0:
            seed(y, x - 1)
        if x + 1 < width:
            seed(y, x + 1)
    return outside


def extract(sheet_path: Path, output_dir: Path, threshold: int = 247) -> list[Path]:
    image = Image.open(sheet_path).convert("RGB")
    width, height = image.size
    if width % 4 or height % 2:
        raise ValueError(f"Expected a 4x2 sheet with evenly divisible cells, got {width}x{height}")
    cell_w, cell_h = width // 4, height // 2
    if (cell_w, cell_h) != (160, 292):
        raise ValueError(f"Unexpected cell size {(cell_w, cell_h)}; expected (160, 292)")

    rgb = np.asarray(image)
    outside = exterior_background_mask(rgb, threshold)
    rgba = np.dstack((rgb, np.where(outside, 0, 255).astype(np.uint8)))
    output_dir.mkdir(parents=True, exist_ok=True)

    paths: list[Path] = []
    for index in range(8):
        row, col = divmod(index, 4)
        crop = rgba[row * cell_h:(row + 1) * cell_h, col * cell_w:(col + 1) * cell_w]
        path = output_dir / f"razor_hero_{index + 1:02d}.png"
        Image.fromarray(crop, mode="RGBA").save(path, optimize=True)
        paths.append(path)
    return paths


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", type=Path, help="Path to the supplied 4x2 character sheet")
    parser.add_argument("--output", type=Path, default=Path("assets/characters"))
    parser.add_argument("--threshold", type=int, default=247)
    args = parser.parse_args()
    paths = extract(args.sheet, args.output, args.threshold)
    for path in paths:
        frame = Image.open(path).convert("RGBA")
        alpha = np.asarray(frame)[:, :, 3]
        ys, xs = np.where(alpha > 0)
        bounds = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        print(f"{path}: size={frame.size}, nontransparent_bounds={bounds}, visible_pixels={len(xs)}")


if __name__ == "__main__":
    main()
