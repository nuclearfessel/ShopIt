"""Rasterize About lockup SVGs to anti-aliased PNGs for in-app use.

Run from the repo root: python tool/make_about_lockup.py
Requires resvg-py and Pillow. flutter_svg is not used for About; these PNGs are.
"""
from io import BytesIO
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image
import resvg_py

ROOT = Path(__file__).resolve().parents[1]
# Native lockup viewBox is 1100×300. Render at 2× for crisp 56dp About rows
# on 3×/4× screens without runtime SVG jaggies.
HEIGHT = 600
VARIANTS = (
    "assets/brand/shopit-horizontal-dark.svg",
    "assets/brand/shopit-horizontal-light.svg",
)


def rasterize(svg_path: Path, height: int) -> Image.Image:
    root = ET.parse(svg_path).getroot()
    view = root.get("viewBox", "0 0 1100 300").split()
    vb_w, vb_h = float(view[2]), float(view[3])
    width = max(1, round(height * (vb_w / vb_h)))
    root.set("width", str(width))
    root.set("height", str(height))
    return Image.open(
        BytesIO(
            resvg_py.svg_to_bytes(
                svg_string=ET.tostring(root, encoding="unicode"),
            )
        )
    ).convert("RGBA")


def main() -> None:
    for relative in VARIANTS:
        source = ROOT / relative
        destination = source.with_suffix(".png")
        image = rasterize(source, HEIGHT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        image.save(destination, format="PNG", optimize=True)
        print(f"{destination.relative_to(ROOT)} {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main()
