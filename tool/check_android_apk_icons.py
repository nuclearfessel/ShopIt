"""Check the APK's selected launcher-icon resources, not its source PNG inputs.

When aapt selects an adaptive/vector XML launcher, the reviewed density PNG
fallbacks packed beside it must still be present and match the artwork
manifest. Adaptive XML alone is not enough.
"""
import argparse
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
from zipfile import ZipFile

from PIL import Image
from check_icon_artwork import DEFAULT_MANIFEST, check_export
from validate_app_icons import ANDROID_SIZES

DENSITIES = {160: "mdpi", 240: "hdpi", 320: "xhdpi", 480: "xxhdpi", 640: "xxxhdpi"}


def selected_icons(badging):
    selected = {}
    for line in badging.splitlines():
        match = re.fullmatch(r"application-icon-(\d+):\s*['\"]([^'\"]+)['\"]\s*", line)
        if not match:
            continue
        density, path = int(match[1]), match[2]
        if density in selected:
            raise ValueError(f"duplicate selected launcher resource at density {density}")
        selected[density] = path
    missing = set(DENSITIES) - set(selected)
    if missing:
        raise ValueError(f"APK launcher icon is missing densities {sorted(missing)}")
    return selected


def _safe_res_member(name):
    path = PurePosixPath(name)
    if (
        path.is_absolute()
        or ".." in path.parts
        or "\\" in name
        or not name.startswith("res/")
    ):
        raise ValueError(f"unsupported APK icon member path {name!r}")
    return path


def _png_fallback(names, density_name):
    """Find the compiled legacy mipmap PNG for one density inside the APK."""
    prefix = f"mipmap-{density_name}"
    matches = [
        name
        for name in names
        if PurePosixPath(name).suffix.lower() == ".png"
        and PurePosixPath(name).stem == "ic_launcher"
        and any(
            part == prefix or part.startswith(f"{prefix}-")
            for part in PurePosixPath(name).parts
        )
    ]
    if len(matches) != 1:
        raise ValueError(
            f"expected exactly one ic_launcher.png under {prefix}*, found {matches}"
        )
    return matches[0]


def _check_png_member(archive, name, density_name, manifest):
    _safe_res_member(name)
    names = archive.namelist()
    if names.count(name) != 1:
        raise ValueError(f"missing or duplicate APK icon member: {name}")
    entry = archive.getinfo(name)
    if entry.file_size > 10 * 1024 * 1024:
        raise ValueError(f"APK icon exceeds byte budget: {name}")
    size = ANDROID_SIZES[density_name]
    payload = archive.read(entry)
    with Image.open(BytesIO(payload)) as image:
        if image.format != "PNG" or image.size != (size, size):
            raise ValueError(f"{name}: expected {size}px compiled PNG")
        image.verify()
    with Image.open(BytesIO(payload)) as image:
        image.load()
        key = f"android/app/src/main/res/mipmap-{density_name}/ic_launcher.png"
        try:
            check_export(image, manifest, key)
        except ValueError as error:
            raise ValueError(f"APK {density_name} {name}: {error}") from error


def check_android_apk(apk, manifest, aapt="aapt"):
    apk = Path(apk).resolve()
    badging = subprocess.run(
        [str(aapt), "dump", "badging", str(apk)],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=60,
    )
    selected = selected_icons(badging.stdout)
    with ZipFile(apk) as archive:
        names = archive.namelist()
        for density, suffix in DENSITIES.items():
            name = selected[density]
            path = _safe_res_member(name)
            if path.suffix.lower() == ".png":
                _check_png_member(archive, name, suffix, manifest)
                continue
            if path.suffix.lower() != ".xml":
                raise ValueError(
                    f"unsupported selected icon {name!r}; "
                    "expected PNG or adaptive XML with PNG mipmap fallbacks"
                )
            # Adaptive/vector is selected: require the reviewed PNG fallback.
            fallback = _png_fallback(names, suffix)
            _check_png_member(archive, fallback, suffix, manifest)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-apk", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--aapt", default="aapt", help="Android build-tools aapt executable")
    args = parser.parse_args(argv)
    try:
        check_android_apk(
            args.android_apk, json.loads(args.manifest.read_text()), args.aapt
        )
    except Exception as error:
        print(f"APK icon check failed: {type(error).__name__}: {error}")
        return 1
    print("APK launcher icons match the reviewed density PNG exports.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
