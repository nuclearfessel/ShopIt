"""Builds all platform app icons from the approved ShopIt brand artwork.

Run from the repo root: python tool/make_icon.py (requires Pillow and resvg-py).
The Daily Circle SVG is rasterized to a transparent, full-bleed mark master so
Windows, macOS, Android, and the in-app toolbar/taskbar thumb read large and
clear. iOS requires an opaque, square icon, so transparent pixels are
composited onto the approved evergreen tile color before export.
"""
from io import BytesIO
import json
import re
import struct
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image
import resvg_py
from make_adaptive_icon import make_adaptive_icons

SVG_SOURCE = Path("assets/brand/daily-circle-original-tangerine.svg")
SOURCE = Path("assets/brand/shopit-app-icon-original-tangerine.png")
ICNS_DESTINATION = Path("macos/Runner/ShopItAppIcon.icns")
IOS_BACKGROUND = (38, 55, 47)  # #26372F, the app-icon tile background
RESAMPLE = Image.Resampling.LANCZOS
MASTER_SIZE = 1024
ICNS_TAGS = {
    16: b"icp4",
    32: b"icp5",
    64: b"icp6",
    128: b"ic07",
    256: b"ic08",
    512: b"ic09",
    1024: b"ic10",
}


def render_master(size=MASTER_SIZE):
    """Rasterize the approved SVG to a transparent square mark."""
    root = ET.parse(SVG_SOURCE).getroot()
    root.set("width", str(size))
    root.set("height", str(size))
    return Image.open(BytesIO(resvg_py.svg_to_bytes(
        svg_string=ET.tostring(root, encoding="unicode"),
    ))).convert("RGBA")


def resized(source, size):
    return source.resize((size, size), RESAMPLE)


def save_ios_icon(source, size, destination):
    icon = resized(source, size)
    background = Image.new("RGBA", icon.size, IOS_BACKGROUND + (255,))
    background.alpha_composite(icon)
    background.convert("RGB").save(destination, format="PNG", optimize=True)


def write_icns(catalog_dir, destination):
    """Pack reviewed macOS catalog PNGs into the CFBundleIconFile ICNS."""
    payload = bytearray()
    for size, tag in ICNS_TAGS.items():
        encoded = BytesIO()
        Image.open(catalog_dir / f"app_icon_{size}.png").save(encoded, format="PNG")
        data = encoded.getvalue()
        payload.extend(tag + struct.pack(">I", len(data) + 8) + data)
    destination.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)


def main():
    source = render_master()
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    source.save(SOURCE, format="PNG", optimize=True)

    # Windows multi-resolution ICO; transparent pixels remain transparent.
    source.save(
        "windows/runner/resources/app_icon.ico",
        format="ICO",
        sizes=[(size, size) for size in (16, 24, 32, 48, 64, 128, 256)],
    )

    # Android legacy launcher assets at their native density sizes.
    for density, pixels in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        resized(source, pixels).save(
            f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
            format="PNG",
            optimize=True,
        )

    make_adaptive_icons()

    # macOS AppIcon catalog uses physical-pixel sizes in its filenames.
    macos_catalog_dir = Path("macos/Runner/Assets.xcassets/AppIcon.appiconset")
    macos_catalog = json.loads((macos_catalog_dir / "Contents.json").read_text())
    for entry in macos_catalog["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        match = re.search(r"_(\d+)\.png$", filename)
        if not match:
            raise ValueError(f"Cannot determine physical icon size: {filename}")
        resized(source, int(match.group(1))).save(
            macos_catalog_dir / filename,
            format="PNG",
            optimize=True,
        )
    write_icns(macos_catalog_dir, ICNS_DESTINATION)

    # iOS app icons must be square and opaque; iOS applies its own corner mask.
    ios_catalog = json.loads(
        Path("ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json")
        .read_text()
    )
    for entry in ios_catalog["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        logical_size = float(entry["size"].split("x")[0])
        scale = float(entry["scale"].removesuffix("x"))
        pixels = round(logical_size * scale)
        save_ios_icon(
            source,
            pixels,
            Path("ios/Runner/Assets.xcassets/AppIcon.appiconset") / filename,
        )

    # In-app preview and Windows title-bar / taskbar image.
    resized(source, 96).save("assets/app_icon.png", format="PNG", optimize=True)
    resized(source, 512).save("tool/icon_preview.png", format="PNG", optimize=True)
    # Keep the About mark aligned with the same transparent master.
    resized(source, 256).save("assets/brand/shopit-mark.png", format="PNG", optimize=True)


if __name__ == "__main__":
    main()
