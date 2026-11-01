"""Mutation tests for icon packaging, independent of the actual brand artwork."""
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

import validate_app_icons as validator


class IconPackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.master = Image.new("RGBA", (1024, 1024))
        ImageDraw.Draw(self.master).rounded_rectangle(
            (0, 0, 1023, 1023), radius=220, fill=(220, 100, 20, 255))
        self.ico = self.root / "windows/runner/resources/app_icon.ico"
        self.ico.parent.mkdir(parents=True)
        self.master.save(self.ico, sizes=[(s, s) for s in sorted(validator.WINDOWS_SIZES)])
        for density, pixels in validator.ANDROID_SIZES.items():
            self.write_png(self.android_path(density), pixels, transparent=True)
        for platform, slots in (("ios", validator.IOS_SLOTS), ("macos", validator.MACOS_SLOTS)):
            directory = self.root / platform / validator.CATALOG_PATH
            directory.mkdir(parents=True)
            entries = []
            for index, (idiom, size, scale) in enumerate(sorted(slots)):
                entry = {"idiom": idiom, "size": size, "scale": scale, "filename": f"icon-{index}.png"}
                entries.append(entry)
                self.write_png(directory / entry["filename"], validator.catalog_pixels(entry),
                               transparent=platform == "macos")
            self.save_catalog(platform, {"images": entries, "info": {"version": 1, "author": "xcode"}})

    def android_path(self, density="mdpi"):
        return self.root / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"

    def write_png(self, path, pixels, transparent=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        image = self.master.resize((pixels, pixels), Image.Resampling.LANCZOS)
        if not transparent:
            background = Image.new("RGBA", image.size, (38, 55, 47, 255))
            background.alpha_composite(image)
            image = background.convert("RGB")
        image.save(path)

    def catalog(self, platform="ios"):
        return json.loads((self.root / platform / validator.CATALOG_PATH / "Contents.json").read_text())

    def save_catalog(self, platform, document):
        (self.root / platform / validator.CATALOG_PATH / "Contents.json").write_text(json.dumps(document))

    def catalog_icon(self, platform="ios"):
        return self.root / platform / validator.CATALOG_PATH / self.catalog(platform)["images"][0]["filename"]

    def assert_failure(self, fragment):
        errors = validator.validate(self.root)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def test_valid_complete_package(self):
        self.assertEqual([], validator.validate(self.root))

    def test_cli_status_and_diagnostics(self):
        with redirect_stdout(StringIO()) as output:
            self.assertEqual(0, validator.main(["--root", str(self.root)]))
        self.assertIn("packaging valid", output.getvalue())
        self.android_path().unlink()
        with redirect_stderr(StringIO()) as output:
            self.assertEqual(1, validator.main(["--root", str(self.root)]))
        self.assertIn("mipmap-mdpi/ic_launcher.png", output.getvalue())

    def test_all_android_density_sizes_are_checked(self):
        for density in validator.ANDROID_SIZES:
            with self.subTest(density=density):
                path = self.android_path(density)
                original = path.read_bytes()
                self.write_png(path, 47, transparent=True)
                self.assert_failure(f"mipmap-{density}/ic_launcher.png: expected")
                path.write_bytes(original)

    def test_android_without_alpha_fails(self):
        self.write_png(self.android_path(), 48)
        self.assert_failure("lost intended transparency")

    def test_android_all_opaque_alpha_fails(self):
        Image.new("RGBA", (48, 48), (5, 6, 7, 255)).save(self.android_path())
        self.assert_failure("near-transparent exterior and fully opaque")

    def test_android_all_transparent_fails(self):
        Image.new("RGBA", (48, 48)).save(self.android_path())
        self.assert_failure("near-transparent exterior and fully opaque")

    def test_filled_exterior_corners_fail(self):
        image = Image.new("RGBA", (48, 48), (5, 6, 7, 255))
        image.putpixel((24, 24), (0, 0, 0, 0))
        image.save(self.android_path())
        self.assert_failure("four exterior corners")

    def test_small_icon_antialias_tolerance_is_bounded(self):
        image = Image.new("RGBA", (16, 16), (20, 30, 40, 255))
        corners = ((0, 0), (0, 15), (15, 0), (15, 15))
        for point in corners:
            image.putpixel(point, (20, 30, 40, 6))
        validator.check_pixels(image, 16, "transparent")
        image.putpixel((0, 0), (20, 30, 40, 9))
        with self.assertRaisesRegex(ValueError, "four exterior corners"):
            validator.check_pixels(image, 16, "transparent")

    def test_non_png_payload_fails(self):
        Image.new("RGB", (48, 48)).save(self.android_path(), format="JPEG")
        self.assert_failure("expected a PNG")

    def test_truncated_png_fails(self):
        path = self.android_path()
        path.write_bytes(path.read_bytes()[:80])
        self.assert_failure("mipmap-mdpi/ic_launcher.png")

    def test_ios_alpha_channel_fails_even_when_opaque(self):
        path = self.catalog_icon()
        with Image.open(path) as image:
            image.convert("RGBA").save(path)
        self.assert_failure("iOS icon must not contain an alpha")

    def test_ios_palette_transparency_fails(self):
        path = self.catalog_icon()
        with Image.open(path) as image:
            palette = image.convert("P")
        palette.save(path, transparency=0)
        self.assert_failure("tRNS")

    def test_missing_catalog_file_fails(self):
        self.catalog_icon().unlink()
        self.assert_failure(self.catalog_icon().name)

    def test_wrong_catalog_dimensions_fail(self):
        for platform in ("ios", "macos"):
            with self.subTest(platform=platform):
                path = self.catalog_icon(platform)
                self.write_png(path, 17, transparent=platform == "macos")
                self.assert_failure(f"{path.name}: expected")

    def test_macos_transparency_is_required(self):
        path = self.catalog_icon("macos")
        with Image.open(path) as image:
            image.convert("RGB").save(path)
        self.assert_failure("lost intended transparency")

    def test_missing_and_duplicate_catalog_roles_fail(self):
        for platform in ("ios", "macos"):
            with self.subTest(platform=platform):
                catalog = self.catalog(platform)
                catalog["images"][0] = catalog["images"][1]
                self.save_catalog(platform, catalog)
                self.assert_failure("duplicate icon slot")
                self.assert_failure("missing required catalog slots")

    def test_missing_filename_fails(self):
        catalog = self.catalog()
        del catalog["images"][0]["filename"]
        self.save_catalog("ios", catalog)
        self.assert_failure("missing icon filename")

    def test_path_escape_fails(self):
        catalog = self.catalog()
        catalog["images"][0]["filename"] = "../icon.png"
        self.save_catalog("ios", catalog)
        self.assert_failure("local PNG basename")

    def test_malformed_catalogs_report_errors_without_traceback(self):
        path = self.root / "ios" / validator.CATALOG_PATH / "Contents.json"
        for document in ("{invalid", "[]", "{}", '{"images":[]}', '{"images":[null]}'):
            with self.subTest(document=document):
                path.write_text(document)
                self.assert_failure("Contents.json")

    def test_fractional_ipad_size(self):
        self.assertEqual(167, validator.catalog_pixels({"size": "83.5x83.5", "scale": "2x"}))
        with self.assertRaises(ValueError):
            validator.catalog_pixels({"size": "83.5x83.5", "scale": "1x"})

    def test_ico_missing_frame_fails(self):
        self.master.save(self.ico, sizes=[(s, s) for s in (16, 32, 48, 64, 128, 256)])
        self.assert_failure("expected 7 ICO frames")

    def test_ico_opaque_frame_fails(self):
        self.master.convert("RGB").save(
            self.ico, sizes=[(s, s) for s in sorted(validator.WINDOWS_SIZES)])
        self.assert_failure("lost intended transparency")

    def test_ico_duplicate_size_fails(self):
        data = bytearray(self.ico.read_bytes())
        data[22:24] = data[6:8]
        self.ico.write_bytes(data)
        self.assert_failure("duplicate ICO frame")

    def test_ico_corrupt_small_frame_is_checked(self):
        data = bytearray(self.ico.read_bytes())
        offset = struct.unpack_from("<I", data, 18)[0]
        data[offset:offset + 12] = b"invalid-data"
        self.ico.write_bytes(data)
        self.assert_failure("app_icon.ico")

    def test_ico_truncated_payload_fails(self):
        self.ico.write_bytes(self.ico.read_bytes()[:-200])
        self.assert_failure("invalid/truncated payload")

    def test_ico_payload_overlap_fails(self):
        data = bytearray(self.ico.read_bytes())
        first_offset = struct.unpack_from("<I", data, 18)[0]
        struct.pack_into("<I", data, 34, first_offset)
        self.ico.write_bytes(data)
        self.assert_failure("overlaps another frame")

    def test_validation_is_read_only(self):
        with patch.object(Path, "write_bytes", side_effect=AssertionError("must not write")), \
             patch.object(Path, "write_text", side_effect=AssertionError("must not write")):
            self.assertEqual([], validator.validate(self.root))


if __name__ == "__main__":
    unittest.main()
