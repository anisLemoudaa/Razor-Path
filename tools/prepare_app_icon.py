#!/usr/bin/env python3
"""Prepare exact-source Android launcher assets for Razor Path."""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/reference/razor_path_app_icon_source.png"
OUTPUT = ROOT / "assets/icons"
MAIN_SIZE = 1920
ADAPTIVE_SIZE = 432
SAFE_SIZE = 288
DARK_THRESHOLD = 12


def remove_edge_connected_dark_background(image: Image.Image) -> tuple[Image.Image, int]:
    """Make only very dark pixels connected to an image edge transparent."""
    result = image.convert("RGBA")
    pixels = result.load()
    width, height = result.size
    seen = bytearray(width * height)
    queue: deque[int] = deque()

    def is_background(index: int) -> bool:
        x, y = index % width, index // width
        red, green, blue, _ = pixels[x, y]
        return max(red, green, blue) < DARK_THRESHOLD

    for x in range(width):
        for y in (0, height - 1):
            index = y * width + x
            if not seen[index] and is_background(index):
                seen[index] = 1
                queue.append(index)
    for y in range(height):
        for x in (0, width - 1):
            index = y * width + x
            if not seen[index] and is_background(index):
                seen[index] = 1
                queue.append(index)

    removed = 0
    while queue:
        index = queue.popleft()
        x, y = index % width, index // width
        pixels[x, y] = (0, 0, 0, 0)
        removed += 1
        if x > 0:
            neighbor = index - 1
            if not seen[neighbor] and is_background(neighbor):
                seen[neighbor] = 1
                queue.append(neighbor)
        if x + 1 < width:
            neighbor = index + 1
            if not seen[neighbor] and is_background(neighbor):
                seen[neighbor] = 1
                queue.append(neighbor)
        if y > 0:
            neighbor = index - width
            if not seen[neighbor] and is_background(neighbor):
                seen[neighbor] = 1
                queue.append(neighbor)
        if y + 1 < height:
            neighbor = index + width
            if not seen[neighbor] and is_background(neighbor):
                seen[neighbor] = 1
                queue.append(neighbor)

    return result, removed


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing user-supplied icon source: {SOURCE}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGB")
    if source.width != source.height:
        raise SystemExit(f"Expected a square app icon, got {source.size}")

    main_icon = source.resize((MAIN_SIZE, MAIN_SIZE), Image.Resampling.LANCZOS)
    main_path = OUTPUT / "razor_path_app_icon.png"
    main_icon.save(main_path, format="PNG", optimize=True, compress_level=9)

    foreground, removed = remove_edge_connected_dark_background(source)
    if removed < source.width * source.height // 100:
        raise SystemExit("Edge-background pass removed too few pixels; refusing to make a bad adaptive icon")
    safe = foreground.resize((SAFE_SIZE, SAFE_SIZE), Image.Resampling.LANCZOS)
    adaptive = Image.new("RGBA", (ADAPTIVE_SIZE, ADAPTIVE_SIZE), (0, 0, 0, 0))
    offset = (ADAPTIVE_SIZE - SAFE_SIZE) // 2
    adaptive.alpha_composite(safe, (offset, offset))
    foreground_path = OUTPUT / "razor_path_adaptive_foreground.png"
    adaptive.save(foreground_path, format="PNG", optimize=True, compress_level=9)

    corner = source.getpixel((0, 0))
    background = Image.new("RGBA", (ADAPTIVE_SIZE, ADAPTIVE_SIZE), (*corner, 255))
    background_path = OUTPUT / "razor_path_adaptive_background.png"
    background.save(background_path, format="PNG", optimize=True, compress_level=9)

    print(f"main_icon={main_path} size={MAIN_SIZE}x{MAIN_SIZE}")
    print(f"adaptive_foreground={foreground_path} size={ADAPTIVE_SIZE}x{ADAPTIVE_SIZE} safe_content={SAFE_SIZE}x{SAFE_SIZE}")
    print(f"adaptive_background={background_path} rgb={corner} edge_pixels_transparent={removed}")


if __name__ == "__main__":
    main()
