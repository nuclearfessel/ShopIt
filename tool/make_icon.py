"""Builds all platform app icons from the approved ShopIt brand artwork.

Run from the repo root: python tool/make_icon.py (requires Pillow and resvg-py).
The supplied transparent icon master is preserved for Windows, macOS, and
Android. iOS requires an opaque, square icon, so transparent pixels are
composited onto the approved evergreen tile color before export.
"""
import json
import re
from pathlib import Path

from PIL import Image
from make_adaptive_icon import make_adaptive_icons

SOURCE = Path("assets/brand/shopit-app-icon-original-tangerine.png")
IOS_BACKGROUND = (38, 55, 47)  # #26372F, the app-icon tile background
RESAMPLE = Image.Resampling.LANCZOS


def resized(source, size):
    return source.resize((size, size), RESAMPLE)


def save_ios_icon(source, size, destination):
    icon = resized(source, size)
    background = Image.new("RGBA", icon.size, IOS_BACKGROUND + (255,))
    background.alpha_composite(icon)
    background.convert("RGB").save(destination, format="PNG", optimize=True)


def main():
    source = Image.open(SOURCE).convert("RGBA")

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
    macos_catalog = json.loads(
        Path("macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json")
        .read_text()
    )
    for entry in macos_catalog["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        match = re.search(r"_(\d+)\.png$", filename)
        if not match:
            raise ValueError(f"Cannot determine physical icon size: {filename}")
        resized(source, int(match.group(1))).save(
            Path("macos/Runner/Assets.xcassets/AppIcon.appiconset") / filename,
            format="PNG",
            optimize=True,
        )

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

    # In-app preview and Windows taskbar/tray image.
    resized(source, 96).save("assets/app_icon.png", format="PNG", optimize=True)
    resized(source, 512).save("tool/icon_preview.png", format="PNG", optimize=True)


if __name__ == "__main__":
    main()
