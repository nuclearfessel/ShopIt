"""Generate Android adaptive and round launcher icons from the approved SVG.

Run from the repository root: python tool/make_adaptive_icon.py
Requires Pillow and resvg-py. These are build-time tools, not app dependencies.

The Daily Circle fills the adaptive mask edge-to-edge. The adaptive background
is an opaque dark plate with the same full-bleed mark so OS surfaces never
fill transparent gaps with a white circle. Round mipmaps are the same artwork
for android:roundIcon.
"""
from io import BytesIO
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image
import resvg_py

SOURCE = Path("assets/brand/daily-circle-original-tangerine.svg")
RES = Path("android/app/src/main/res")
CANVAS_DP = 108
# Fill the adaptive mask circle edge-to-edge.
MARK_DIAMETER_DP = 108
# Behind transparent seams / center cutouts — never white.
PLATE_RGB = (20, 20, 20)

DENSITIES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}

LEGACY_MIPMAP_PX = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def render_circle_mark(pixels: int) -> Image.Image:
    """Rasterize the Daily Circle cropped to its outer circle, full-bleed."""
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


def opaque_circle_icon(pixels: int) -> Image.Image:
    """Full-bleed mark on an opaque dark plate for OS surfaces (no alpha)."""
    mark = render_circle_mark(pixels)
    plate = Image.new("RGBA", (pixels, pixels), PLATE_RGB + (255,))
    plate.alpha_composite(mark)
    return plate.convert("RGB")


def make_adaptive_icons():
    for density, scale in DENSITIES.items():
        mark_pixels = round(MARK_DIAMETER_DP * scale)
        canvas_pixels = round(CANVAS_DP * scale)
        mark = render_circle_mark(mark_pixels)
        offset = (canvas_pixels - mark_pixels) // 2

        # Foreground keeps alpha so adaptive seams stay transparent cuts.
        foreground = Image.new("RGBA", (canvas_pixels, canvas_pixels))
        foreground.alpha_composite(mark, (offset, offset))
        fg_path = RES / f"drawable-{density}" / "ic_launcher_foreground.png"
        fg_path.parent.mkdir(parents=True, exist_ok=True)
        foreground.save(fg_path, optimize=True)

        # Opaque full-bleed plate — OS never invents a white circle behind us.
        background = Image.new("RGBA", (canvas_pixels, canvas_pixels), PLATE_RGB + (255,))
        background.alpha_composite(mark, (offset, offset))
        bg_path = RES / f"drawable-{density}" / "ic_launcher_background.png"
        bg_path.parent.mkdir(parents=True, exist_ok=True)
        background.convert("RGB").save(bg_path, optimize=True)


def make_legacy_and_round_icons():
    for density, pixels in LEGACY_MIPMAP_PX.items():
        icon = opaque_circle_icon(pixels)
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        icon.save(folder / "ic_launcher.png", format="PNG", optimize=True)
        icon.save(folder / "ic_launcher_round.png", format="PNG", optimize=True)


def write_adaptive_xml():
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (anydpi / name).write_text(
            """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
""",
            encoding="utf-8",
            newline="\n",
        )


def main():
    make_adaptive_icons()
    make_legacy_and_round_icons()
    write_adaptive_xml()
    # Color resource kept only as a fallback reference; drawables are used.
    (RES / "values" / "ic_launcher_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Dark plate under the full-bleed Daily Circle; never a white OS fill. -->
    <color name="ic_launcher_background">#141414</color>
</resources>
""",
        encoding="utf-8",
        newline="\n",
    )


if __name__ == "__main__":
    main()
