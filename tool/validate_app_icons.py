"""Validate checked-in app icons without Flutter or native platform toolchains.

Run: python tool/validate_app_icons.py [--root /path/to/ShopIt]
Install dependencies with: python -m pip install -r tool/icon-requirements.txt

These expectations intentionally do not import make_icon: a generator regression
must not silently change both the output and its validation contract.
"""
import argparse
from decimal import Decimal, InvalidOperation
from io import BytesIO
import json
from pathlib import Path
import struct
import sys

from PIL import Image

WINDOWS_SIZES = {16, 24, 32, 48, 64, 128, 256}
ANDROID_SIZES = {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}
CATALOG_PATH = "Runner/Assets.xcassets/AppIcon.appiconset"
IOS_SLOTS = (
    {("iphone", size, scale) for size, scales in {
        "20x20": ("2x", "3x"),
        "29x29": ("1x", "2x", "3x"),
        "40x40": ("2x", "3x"),
        "60x60": ("2x", "3x"),
    }.items() for scale in scales}
    | {("ipad", size, scale) for size in (
        "20x20", "29x29", "40x40", "76x76",
    ) for scale in ("1x", "2x")}
    | {("ipad", "83.5x83.5", "2x"), ("ios-marketing", "1024x1024", "1x")}
)
MACOS_SLOTS = {
    ("mac", f"{size}x{size}", scale)
    for size in (16, 32, 128, 256, 512) for scale in ("1x", "2x")
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_pixels(image, pixels, alpha_policy):
    require(image.size == (pixels, pixels),
            f"expected {pixels}x{pixels}, got {image.width}x{image.height}")
    has_alpha = "A" in image.getbands() or "transparency" in image.info
    if alpha_policy == "opaque":
        # Apple forbids the alpha channel itself, even if every pixel is opaque.
        require(not has_alpha, "iOS icon must not contain an alpha channel or tRNS transparency")
        return
    require(has_alpha, "lost intended transparency (no alpha channel/transparency)")
    alpha = image.convert("RGBA").getchannel("A")
    # At 16 px the approved rounded tile's antialiased corners have alpha 6.
    # Allow at most 8/255 coverage, not an opaque or accidentally flattened tile.
    minimum, maximum = alpha.getextrema()
    require(minimum <= 8 and maximum == 255,
            "must retain both near-transparent exterior and fully opaque pixels")
    corners = ((0, 0), (0, pixels - 1), (pixels - 1, 0), (pixels - 1, pixels - 1))
    require(all(alpha.getpixel(point) <= 8 for point in corners),
            "all four exterior corners must remain transparent")


def check_png(path, pixels, alpha_policy):
    # verify checks PNG checksums/truncation; reopening decodes every pixel.
    with Image.open(path) as image:
        require(image.format == "PNG", "expected a PNG file")
        image.verify()
    with Image.open(path) as image:
        image.load()
        check_pixels(image, pixels, alpha_policy)


def check_ico(path):
    data = path.read_bytes()
    require(len(data) >= 6, "truncated ICO header")
    reserved, kind, count = struct.unpack_from("<HHH", data)
    require((reserved, kind) == (0, 1), "invalid ICO header (must be an icon, not a cursor)")
    require(count == len(WINDOWS_SIZES),
            f"expected {len(WINDOWS_SIZES)} ICO frames, found {count}")
    header_end = 6 + count * 16
    require(len(data) >= header_end, "truncated ICO directory")
    sizes, regions = set(), []
    for index in range(count):
        entry = data[6 + index * 16:22 + index * 16]
        width, height, _, _, _, _, length, offset = struct.unpack("<BBBBHHII", entry)
        width, height = width or 256, height or 256
        require(width == height and width in WINDOWS_SIZES,
                f"unexpected ICO frame {width}x{height}")
        require(width not in sizes, f"duplicate ICO frame {width}x{height}")
        sizes.add(width)
        require(length > 0 and offset >= header_end and offset + length <= len(data),
                f"ICO frame {width}x{height} has invalid/truncated payload")
        require(all(offset + length <= start or offset >= end for start, end in regions),
                f"ICO frame {width}x{height} overlaps another frame")
        regions.append((offset, offset + length))
        # Decode each individual entry, not just Pillow's default largest image.
        single_entry = entry[:12] + struct.pack("<I", 22)
        single_icon = struct.pack("<HHH", 0, 1, 1) + single_entry + data[offset:offset + length]
        with Image.open(BytesIO(single_icon)) as image:
            image.load()
            check_pixels(image, width, "transparent")
    require(sizes == WINDOWS_SIZES, f"missing ICO frame sizes: {sorted(WINDOWS_SIZES - sizes)}")


def catalog_pixels(entry):
    width, height = map(Decimal, entry["size"].split("x"))
    scale_text = entry["scale"]
    require(scale_text in ("1x", "2x", "3x"), f"invalid scale {scale_text!r}")
    scale = Decimal(scale_text[:-1])
    pixels = width * scale
    require(width.is_finite() and height.is_finite() and width == height and width > 0,
            f"invalid square size {entry['size']!r}")
    require(pixels == pixels.to_integral_value() and pixels <= 4096,
            f"invalid physical pixel size {pixels}")
    return int(pixels)


def validate(root):
    """Return path-specific failures; never modify or regenerate any assets."""
    root = Path(root)
    errors = []

    def check(path, operation):
        try:
            operation()
        except (OSError, ValueError, KeyError, TypeError, InvalidOperation, struct.error) as exc:
            errors.append(f"{Path(path).as_posix()}: {exc}")

    ico_path = Path("windows/runner/resources/app_icon.ico")
    check(ico_path, lambda: check_ico(root / ico_path))
    for density, pixels in ANDROID_SIZES.items():
        path = Path(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png")
        check(path, lambda p=path, px=pixels: check_png(root / p, px, "transparent"))

    for platform, required_slots in (("ios", IOS_SLOTS), ("macos", MACOS_SLOTS)):
        directory = Path(platform) / CATALOG_PATH
        catalog = directory / "Contents.json"

        def check_catalog():
            document = json.loads((root / catalog).read_text(encoding="utf-8"))
            require(isinstance(document, dict), "catalog must be an object")
            entries = document.get("images")
            require(isinstance(entries, list) and entries, "catalog images must be a nonempty list")
            found = set()
            for index, entry in enumerate(entries):
                label = f"{catalog} images[{index}]"

                def check_entry():
                    require(isinstance(entry, dict), "catalog image must be an object")
                    slot = (entry["idiom"], entry["size"], entry["scale"])
                    require(all(isinstance(value, str) for value in slot), "slot values must be strings")
                    require(slot in required_slots, f"unexpected icon slot {slot}")
                    require(slot not in found, f"duplicate icon slot {slot}")
                    found.add(slot)
                    filename = entry.get("filename")
                    require(isinstance(filename, str) and filename, "missing icon filename")
                    require("/" not in filename and "\\" not in filename
                            and filename.lower().endswith(".png"),
                            f"filename must be a local PNG basename: {filename!r}")
                    pixels = catalog_pixels(entry)
                    policy = "opaque" if platform == "ios" else "transparent"
                    check(directory / filename,
                          lambda: check_png(root / directory / filename, pixels, policy))

                check(label, check_entry)
            missing = required_slots - found
            require(not missing, f"missing required catalog slots: {sorted(missing)}")

        check(catalog, check_catalog)
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1],
                        help="ShopIt repository root (defaults to the script's repository)")
    args = parser.parse_args(argv)
    errors = validate(args.root)
    if errors:
        print(f"App icon validation failed ({len(errors)} issue(s)):", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("App icon packaging valid: Windows ICO, five Android densities, iOS and macOS catalogs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
