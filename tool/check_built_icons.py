"""Inspect real Windows EXE resources or macOS .app icons, without launching them."""
import argparse
from io import BytesIO
import json
from pathlib import Path
import plistlib
import struct

from PIL import Image
from check_icon_artwork import DEFAULT_MANIFEST, check_export
from validate_app_icons import WINDOWS_SIZES


def windows_resources(executable):
    import pefile
    pe = pefile.PE(str(executable), fast_load=True)
    try:
        pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]])
        resources = {}
        directory = getattr(pe, "DIRECTORY_ENTRY_RESOURCE", None)
        if directory is None:
            raise ValueError("Windows executable has no resource directory")
        for kind in directory.entries:
            if kind.id not in (3, 14):
                continue
            for identifier in kind.directory.entries:
                for language in identifier.directory.entries:
                    item = language.data.struct
                    data = pe.get_data(item.OffsetToData, item.Size)
                    if len(data) != item.Size:
                        raise ValueError("truncated PE resource")
                    resources[(kind.id, identifier.id, language.id)] = data
        return resources
    finally:
        pe.close()


def check_windows(executable, manifest, resource_id=101):
    resources = windows_resources(executable)
    groups = [(language, value) for (kind, identifier, language), value in resources.items()
              if kind == 14 and identifier == resource_id]
    if not groups:
        raise ValueError(f"missing Windows main icon resource {resource_id}")
    for language, group in groups:
        if len(group) < 6:
            raise ValueError("truncated Windows icon group")
        reserved, kind, count = struct.unpack_from("<HHH", group)
        if (reserved, kind, count) != (0, 1, len(WINDOWS_SIZES)) or len(group) != 6 + count * 14:
            raise ValueError("incorrect Windows icon group header or frame count")
        sizes = set()
        for index in range(count):
            entry = group[6 + index * 14:20 + index * 14]
            width, height, _, _, _, _, length, icon_id = struct.unpack("<BBBBHHIH", entry)
            width, height = width or 256, height or 256
            if width != height or width not in WINDOWS_SIZES or width in sizes:
                raise ValueError("duplicate or unexpected Windows icon frame size")
            sizes.add(width)
            payload = resources.get((3, icon_id, language))
            if payload is None or len(payload) != length:
                raise ValueError(f"missing/truncated Windows icon payload {icon_id}, language {language}")
            icon = struct.pack("<HHH", 0, 1, 1) + entry[:12] + struct.pack("<I", 22) + payload
            with Image.open(BytesIO(icon)) as image:
                image.load()
                try:
                    check_export(image, manifest, f"windows/runner/resources/app_icon.ico#{width}")
                except ValueError as error:
                    raise ValueError(
                        f"Windows icon {resource_id}, language {language}, {width}px: {error}"
                    ) from error


def bundle_info(bundle):
    contents = Path(bundle) / "Contents"
    with (contents / "Info.plist").open("rb") as stream:
        return contents, plistlib.load(stream)


def check_macos(bundle, manifest):
    contents, info = bundle_info(bundle)
    resources = (contents / "Resources").resolve()
    # Prefer the reviewed release ICNS when present so an Xcode asset-catalog
    # AppIcon.icns cannot silently become the checked file.
    reviewed = (resources / "ShopItAppIcon.icns").resolve()
    name = info.get("CFBundleIconFile")
    if reviewed.is_file():
        if not isinstance(name, str) or Path(name).stem != "ShopItAppIcon":
            raise ValueError(
                "CFBundleIconFile must be ShopItAppIcon when "
                f"ShopItAppIcon.icns is packaged; found {name!r}"
            )
        name = "ShopItAppIcon.icns"
    elif not isinstance(name, str) or not name or Path(name).name != name:
        raise ValueError(
            "built Info.plist must name its compiled CFBundleIconFile; "
            "catalog-only Assets.car inspection is unsupported, not a pass"
        )
    elif not name.lower().endswith(".icns"):
        name += ".icns"
    icon = (resources / name).resolve()
    if not icon.is_relative_to(resources):
        raise ValueError("compiled icon escapes Resources")
    data = icon.read_bytes()
    if len(data) < 8 or data[:4] != b"icns" or struct.unpack_from(">I", data, 4)[0] != len(data):
        raise ValueError("invalid/truncated ICNS container")
    position = 8
    tags = set()
    while position < len(data):
        if position + 8 > len(data):
            raise ValueError("truncated ICNS entry header")
        tag = data[position:position + 4]
        if tag in tags:
            raise ValueError(f"duplicate ICNS entry {tag!r} could hide stale artwork")
        tags.add(tag)
        length = struct.unpack_from(">I", data, position + 4)[0]
        if length < 8 or position + length > len(data):
            raise ValueError("invalid ICNS entry length")
        position += length
    seen = set()
    with Image.open(icon) as image:
        for size in image.icns.itersizes():
            pixels = size[0] * size[2]
            if pixels not in (16, 32, 64, 128, 256, 512, 1024):
                continue
            frame = image.icns.getimage(size)
            try:
                check_export(frame, manifest,
                             f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{pixels}.png")
            except ValueError as error:
                raise ValueError(f"macOS {name}, representation {size}: {error}") from error
            seen.add(pixels)
    missing = {16, 32, 64, 128, 256, 512, 1024} - seen
    if missing:
        raise ValueError(f"compiled ICNS missing physical pixel sizes: {sorted(missing)}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--windows-exe", type=Path)
    parser.add_argument("--macos-app", type=Path)
    parser.add_argument("--windows-resource-id", type=int, default=101)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args(argv)
    if not args.windows_exe and not args.macos_app:
        parser.error("supply --windows-exe and/or --macos-app")
    try:
        manifest = json.loads(args.manifest.read_text())
        if args.windows_exe:
            check_windows(args.windows_exe, manifest, args.windows_resource_id)
        if args.macos_app:
            check_macos(args.macos_app, manifest)
    except Exception as error:
        # Also report optional pefile's format-specific exception cleanly.
        print(f"Built icon check failed: {type(error).__name__}: {error}")
        return 1
    print("Built application icons match the reviewed artwork.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
