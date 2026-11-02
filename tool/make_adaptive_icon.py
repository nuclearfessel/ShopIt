"""Generate Android adaptive foregrounds from the approved, untiled SVG.

Run from the repository root: python tool/make_adaptive_icon.py
Requires Pillow and resvg-py. These are build-time tools, not app dependencies.
The legacy launcher PNGs are deliberately not touched by this command.
"""
from io import BytesIO
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image
import resvg_py

SOURCE = Path("assets/brand/daily-circle-original-tangerine.svg")
RES = Path("android/app/src/main/res")
CANVAS_DP = 108
# Fill the adaptive mask circle edge-to-edge. A padded safe-zone mark leaves a
# transparent ring that many Android launchers fill with a white plate.
MARK_DIAMETER_DP = 108


def render_circle_mark(pixels: int) -> Image.Image:
    """Rasterize the Daily Circle cropped to its outer circle, full-bleed."""
    # Preserve gradients, clipping, transparent seams, and geometry.
    # Outer clip is a circle centered at (40, 39.05), radius 33.4.
    root = ET.parse(SOURCE).getroot()
    root.set("viewBox", "6.6 5.65 66.8 66.8")
    root.set("width", str(pixels))
    root.set("height", str(pixels))
    return Image.open(
        BytesIO(
            resvg_py.svg_to_bytes(
                svg_string=ET.tostring(root, encoding="unicode"),
            )
        )
    ).convert("RGBA")


def make_adaptive_icons():
    for density, scale in {
        "mdpi": 1,
        "hdpi": 1.5,
        "xhdpi": 2,
        "xxhdpi": 3,
        "xxxhdpi": 4,
    }.items():
        mark_pixels = round(MARK_DIAMETER_DP * scale)
        mark = render_circle_mark(mark_pixels)
        canvas_pixels = round(CANVAS_DP * scale)
        foreground = Image.new("RGBA", (canvas_pixels, canvas_pixels))
        offset = (canvas_pixels - mark_pixels) // 2
        foreground.alpha_composite(mark, (offset, offset))
        destination = RES / f"drawable-{density}" / "ic_launcher_foreground.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        foreground.save(destination, optimize=True)


if __name__ == "__main__":
    make_adaptive_icons()
