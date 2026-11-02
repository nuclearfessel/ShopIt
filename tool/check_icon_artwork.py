"""Reject stale/wrong artwork even when icon dimensions and alpha are valid."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image, ImageChops
from validate_app_icons import ANDROID_SIZES, CATALOG_PATH, WINDOWS_SIZES, catalog_pixels

DEFAULT_MANIFEST = Path(__file__).with_name("icon-artwork-manifest.json")


def approved_master(root, manifest):
    relative = Path(manifest["source"])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("manifest source must stay inside the repository")
    path = (Path(root) / relative).resolve()
    if not path.is_relative_to(Path(root).resolve()):
        raise ValueError("manifest source symlink escapes the repository")
    with Image.open(path) as image:
        image.load()
        master = image.convert("RGBA")
    size = manifest["size"]
    if master.size != (size, size):
        raise ValueError(f"master must be {size}x{size}")
    digest = hashlib.sha256(master.tobytes()).hexdigest()
    if digest != manifest["rgba_sha256"]:
        raise ValueError("master does not match the approved decoded-pixel SHA256")
    return master


def expected_icon(master, size, background=None):
    image = master.resize((size, size), Image.Resampling.LANCZOS)
    if background is not None:
        canvas = Image.new("RGBA", image.size, tuple(background) + (255,))
        canvas.alpha_composite(image)
        image = canvas
    return image


def visible_rgba(image):
    image = image.convert("RGBA")
    r, g, b, a = image.split()
    # Ignore meaningless RGB under transparent pixels, but compare alpha itself.
    return Image.merge("RGBA", (ImageChops.multiply(r, a),
                               ImageChops.multiply(g, a),
                               ImageChops.multiply(b, a), a))


def pixel_digest(image):
    """Encoding-independent digest of visible RGBA pixels."""
    return hashlib.sha256(visible_rgba(image).tobytes()).hexdigest()


def check_export(image, manifest, key):
    record = manifest["exports"].get(key)
    if record is None:
        raise ValueError(f"no reviewed export recorded for {key}")
    if list(image.size) != record["size"] or pixel_digest(image) != record["sha256"]:
        raise ValueError("artwork differs from the reviewed export; review before updating its pixel digest")


def compare_artwork(actual, expected, tolerance=0):
    if not isinstance(tolerance, int) or not 0 <= tolerance <= 8:
        raise ValueError("pixel tolerance must be an integer between 0 and 8")
    if actual.size != expected.size:
        raise ValueError(f"wrong dimensions {actual.size}, expected {expected.size}")
    difference = ImageChops.difference(visible_rgba(actual), visible_rgba(expected))
    maximum = max(high for _, high in difference.getextrema())
    if maximum > tolerance:
        raise ValueError(f"artwork differs from approved master (max channel difference {maximum}, allowed {tolerance})")


def check_artwork(root, manifest_path=DEFAULT_MANIFEST):
    root = Path(root).resolve()
    errors = []
    try:
        manifest = json.loads(Path(manifest_path).read_text())
        approved_master(root, manifest)
        if not isinstance(manifest["exports"], dict) or not manifest["exports"]:
            raise ValueError("manifest must contain reviewed export pixel digests")
    except (OSError, ValueError, KeyError, TypeError) as error:
        return [f"approved master/manifest: {error}"]

    def compare_file(relative, size):
        try:
            with Image.open(root / relative) as image:
                image.load()
                if image.size != (size, size):
                    raise ValueError(f"wrong export dimensions, expected {size}x{size}")
                check_export(image, manifest, Path(relative).as_posix())
        except (OSError, ValueError, KeyError, TypeError) as error:
            errors.append(f"{Path(relative).as_posix()}: {error}")

    ico = Path("windows/runner/resources/app_icon.ico")
    try:
        with Image.open(root / ico) as image:
            for size in sorted(WINDOWS_SIZES):
                frame = image.ico.getimage((size, size))
                check_export(frame, manifest, f"{ico.as_posix()}#{size}")
    except (OSError, ValueError, KeyError, AttributeError, TypeError) as error:
        errors.append(f"{ico.as_posix()}: {error}")
    for density, size in ANDROID_SIZES.items():
        compare_file(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)
        compare_file(
            f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png",
            size,
        )
    for platform in ("ios", "macos"):
        directory = Path(platform) / CATALOG_PATH
        try:
            entries = json.loads((root / directory / "Contents.json").read_text())["images"]
            if not isinstance(entries, list) or not entries:
                raise ValueError("catalog must contain image entries")
            for entry in entries:
                name = entry["filename"]
                if not isinstance(name, str) or Path(name).name != name or "\\" in name:
                    raise ValueError("unsafe catalog filename")
                compare_file(directory / name, catalog_pixels(entry))
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
            errors.append(f"{directory.as_posix()}: {error}")
    return errors


def check_regenerated_artwork(root, command, manifest_path=DEFAULT_MANIFEST, timeout=120):
    """Run a trusted generator only in a disposable copy, never repair the checkout."""
    root = Path(root).resolve()
    try:
        manifest = json.loads(Path(manifest_path).read_text())
        approved_master(root, manifest)
        exports = manifest["exports"]
        if not isinstance(exports, dict) or not exports:
            raise ValueError("manifest must contain reviewed export pixel digests")
        if not command:
            raise ValueError("--regenerate requires a generator command")
        if not math.isfinite(timeout) or timeout <= 0:
            raise ValueError("generator timeout must be finite and positive")
        # Check before copying/deleting: even a custom manifest cannot escape staging.
        paths = {key.split("#", 1)[0] for key in exports}
        for name in paths:
            path = Path(name)
            if path.is_absolute() or ".." in path.parts or "\\" in name:
                raise ValueError(f"unsafe export path: {name}")
        with tempfile.TemporaryDirectory(prefix="shopit-icon-artwork-") as temporary:
            staging = Path(temporary) / "checkout"
            shutil.copytree(
                root, staging, symlinks=True,
                ignore=shutil.ignore_patterns(".git", ".dart_tool", "build",
                                             "node_modules", "__pycache__", ".venv"))
            # A copied symlink could still write through to the original checkout.
            if any(path.is_symlink() for path in staging.rglob("*")):
                raise ValueError("regeneration copy contains symlinks; use a symlink-free checkout")
            for name in paths:
                (staging / name).unlink(missing_ok=True)
            # Generator runs with relative paths in the disposable checkout.
            # It is trusted local code, not an OS security sandbox.
            subprocess.run(command, cwd=staging, check=True, timeout=timeout)
            return check_artwork(staging, manifest_path)
    except subprocess.CalledProcessError as error:
        return [f"regeneration: generator exited with status {error.returncode}"]
    except subprocess.TimeoutExpired:
        return [f"regeneration: generator exceeded {timeout} seconds"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        return [f"regeneration: {error}"]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--timeout", type=float, default=120,
                        help="generator time limit in seconds (default: 120)")
    parser.add_argument("--regenerate", nargs=argparse.REMAINDER,
                        help="optional trusted generator command; must be the last option")
    args = parser.parse_args(argv)
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    # Resolve before switching the generator's working directory.
    manifest_path = args.manifest.resolve()
    errors = (check_artwork(args.root, manifest_path) if args.regenerate is None else
              check_regenerated_artwork(args.root, args.regenerate, manifest_path, args.timeout))
    for error in errors:
        print(error)
    print(f"Icon artwork check: {len(errors)} error(s).")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
