import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from unittest.mock import patch
from PIL import Image

from check_icon_artwork import (approved_master, check_artwork, check_export,
                                check_regenerated_artwork, compare_artwork,
                                expected_icon, main, pixel_digest)
import test_validate_app_icons as packaging


class ArtworkTests(unittest.TestCase):
    def setUp(self):
        self.master = Image.new("RGBA", (32, 32), (255, 100, 20, 255))

    def test_exact_pixels_pass(self):
        compare_artwork(self.master.copy(), self.master)

    def test_wrong_palette_fails(self):
        with self.assertRaisesRegex(ValueError, "artwork differs"):
            compare_artwork(Image.new("RGBA", (32, 32), "blue"), self.master)

    def test_single_visible_changed_pixel_fails(self):
        actual = self.master.copy()
        actual.putpixel((10, 10), (255, 90, 20, 255))
        with self.assertRaises(ValueError):
            compare_artwork(actual, self.master)

    def test_transparent_rgb_is_not_visible_drift(self):
        compare_artwork(Image.new("RGBA", (3, 3), (200, 20, 100, 0)),
                        Image.new("RGBA", (3, 3)))

    def test_alpha_drift_fails(self):
        with self.assertRaises(ValueError):
            compare_artwork(Image.new("RGBA", (32, 32), (255, 100, 20, 0)), self.master)

    def test_tolerance_is_bounded(self):
        for tolerance in (-1, 9, "8"):
            with self.assertRaises(ValueError):
                compare_artwork(self.master, self.master, tolerance)

    def test_ios_composite_opaque(self):
        actual = expected_icon(Image.new("RGBA", (32, 32)), 16, [38, 55, 47])
        self.assertEqual(actual.getpixel((0, 0)), (38, 55, 47, 255))

    def test_manifest_pins_decoded_pixels_not_png_compression(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.master.save(root / "master.png", compress_level=0)
            manifest = {"source": "master.png", "size": 32,
                        "rgba_sha256": hashlib.sha256(self.master.tobytes()).hexdigest()}
            self.assertEqual(approved_master(root, manifest).size, (32, 32))
            self.master.save(root / "master.png", compress_level=9)
            self.assertEqual(approved_master(root, manifest).size, (32, 32))
            Image.new("RGBA", (32, 32), "blue").save(root / "master.png")
            with self.assertRaisesRegex(ValueError, "approved decoded-pixel"):
                approved_master(root, manifest)

    def test_manifest_path_escape_fails(self):
        with self.assertRaises(ValueError):
            approved_master(Path.cwd(), {"source": "../master.png"})

    def test_reviewed_export_contract(self):
        manifest = {"exports": {"icon": {"size": [32, 32], "sha256": pixel_digest(self.master)}}}
        check_export(self.master, manifest, "icon")
        with self.assertRaisesRegex(ValueError, "no reviewed export"):
            check_export(self.master, manifest, "unknown")
        changed = self.master.copy()
        changed.putpixel((10, 10), (0, 50, 70, 255))
        with self.assertRaisesRegex(ValueError, "artwork differs"):
            check_export(changed, manifest, "icon")


class ArtworkIntegrationTests(unittest.TestCase):
    """Generated regression fixtures: complete, dimensionally valid platform packs."""

    def setUp(self):
        fixture = packaging.IconPackagingTests("test_valid_complete_package")
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture = fixture
        self.root = fixture.root
        fixture.master.save(self.root / "master.png")
        manifest = {
            "source": "master.png", "size": 1024,
            "rgba_sha256": hashlib.sha256(fixture.master.tobytes()).hexdigest(),
            "exports": {},
        }
        for path in self.root.rglob("*.png"):
            if path.name == "master.png":
                continue
            with Image.open(path) as image:
                manifest["exports"][path.relative_to(self.root).as_posix()] = {
                    "size": list(image.size), "sha256": pixel_digest(image)}
        with Image.open(fixture.ico) as image:
            for size in sorted(packaging.validator.WINDOWS_SIZES):
                frame = image.ico.getimage((size, size))
                manifest["exports"][f"{fixture.ico.relative_to(self.root).as_posix()}#{size}"] = {
                    "size": list(frame.size), "sha256": pixel_digest(frame)}
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps(manifest))
        # A deterministic fixture generator, not a replacement for ShopIt's renderer.
        (self.root / "generate.py").write_text(
            "from pathlib import Path\n"
            "import json\n"
            "from PIL import Image\n"
            "root = Path.cwd()\n"
            "master = Image.open('master.png').convert('RGBA')\n"
            "sizes = [16, 24, 32, 48, 64, 128, 256]\n"
            "master.save('windows/runner/resources/app_icon.ico', sizes=[(s,s) for s in sizes])\n"
            "manifest = json.loads(Path('manifest.json').read_text())\n"
            "for name, record in manifest['exports'].items():\n"
            "    if '#' in name: continue\n"
            "    image = master.resize(tuple(record['size']), Image.Resampling.LANCZOS)\n"
            "    if name.startswith('ios/'):\n"
            "        bg = Image.new('RGBA', image.size, (38,55,47,255))\n"
            "        bg.alpha_composite(image)\n"
            "        image = bg.convert('RGB')\n"
            "    elif '/mipmap-' in name:\n"
            "        bg = Image.new('RGBA', image.size, (20,20,20,255))\n"
            "        bg.alpha_composite(image)\n"
            "        image = bg.convert('RGB')\n"
            "    image.save(name)\n")
        self.command = [sys.executable, "generate.py"]

    def snapshot(self):
        return {str(path.relative_to(self.root)): path.read_bytes()
                for path in self.root.rglob("*") if path.is_file()}

    def test_reviewed_pack_and_regeneration_pass_without_checkout_changes(self):
        self.assertEqual([], check_artwork(self.root, self.manifest))
        before = self.snapshot()
        self.assertEqual([], check_regenerated_artwork(self.root, self.command, self.manifest))
        self.assertEqual(before, self.snapshot())

    def test_wrong_artwork_with_correct_packaging_fails_on_every_platform(self):
        for path in (self.fixture.android_path(), self.fixture.catalog_icon("ios"),
                     self.fixture.catalog_icon("macos"), self.fixture.ico):
            with self.subTest(path=path):
                original = path.read_bytes()
                if path.suffix == ".ico":
                    wrong = self.fixture.master.copy()
                    wrong.paste((10, 30, 200, 255), (300, 300, 700, 700))
                    wrong.save(path, sizes=[(s, s) for s in sorted(packaging.validator.WINDOWS_SIZES)])
                else:
                    with Image.open(path) as image:
                        wrong = image.copy()
                    wrong.paste(
                        (10, 30, 200) if wrong.mode == "RGB" else (10, 30, 200, 255),
                        (wrong.width // 3, wrong.height // 3,
                         2 * wrong.width // 3, 2 * wrong.height // 3))
                    wrong.save(path)
                self.assertEqual([], packaging.validator.validate(self.root))
                errors = check_artwork(self.root, self.manifest)
                self.assertTrue(any("artwork differs" in error for error in errors), errors)
                path.write_bytes(original)

    def test_regeneration_does_not_repair_bad_committed_artwork(self):
        path = self.fixture.android_path()
        with Image.open(path) as image:
            wrong = image.copy()
        fill = (10, 30, 200) if wrong.mode == "RGB" else (10, 30, 200, 255)
        wrong.paste(fill, (16, 16, 32, 32))
        wrong.save(path)
        before = self.snapshot()
        self.assertTrue(check_artwork(self.root, self.manifest))
        self.assertEqual([], check_regenerated_artwork(self.root, self.command, self.manifest))
        self.assertEqual(before, self.snapshot())
        self.assertTrue(check_artwork(self.root, self.manifest))

    def test_wrong_generator_output_fails_and_temporary_copy_is_removed(self):
        generator = self.root / "generate.py"
        generator.write_text(generator.read_text() +
                             "\nImage.new('RGBA', (48,48), 'blue').save("
                             "'android/app/src/main/res/mipmap-mdpi/ic_launcher.png')\n")
        before = self.snapshot()
        import check_icon_artwork as checker
        temporary_directory = tempfile.TemporaryDirectory
        directories = []

        def track_directory(**kwargs):
            directory = temporary_directory(**kwargs)
            directories.append(Path(directory.name))
            return directory

        with patch.object(checker.tempfile, "TemporaryDirectory", side_effect=track_directory):
            errors = check_regenerated_artwork(self.root, self.command, self.manifest)
        self.assertTrue(any("mipmap-mdpi" in error and "artwork differs" in error
                            for error in errors), errors)
        self.assertEqual(before, self.snapshot())
        self.assertTrue(directories)
        self.assertTrue(all(not directory.exists() for directory in directories))

    def test_no_op_generator_cannot_pass_on_copied_exports(self):
        errors = check_regenerated_artwork(
            self.root, [sys.executable, "-c", "pass"], self.manifest)
        self.assertTrue(errors)
        self.assertTrue(any("ic_launcher.png" in error for error in errors), errors)

    def test_generator_failure_timeout_and_missing_command(self):
        for command, timeout, fragment in (
            ([sys.executable, "-c", "raise SystemExit(7)"], 10, "status 7"),
            ([sys.executable, "-c", "import time; time.sleep(10)"], .05, "exceeded"),
            ([], 10, "requires"),
            (["nonexistent-shopit-generator"], 10, "regeneration:"),
            (self.command, float("nan"), "finite and positive"),
            (self.command, float("inf"), "finite and positive"),
        ):
            with self.subTest(command=command):
                before = self.snapshot()
                errors = check_regenerated_artwork(self.root, command, self.manifest, timeout)
                self.assertTrue(any(fragment in error for error in errors), errors)
                self.assertEqual(before, self.snapshot())

    def test_master_is_verified_before_running_generator(self):
        Image.new("RGBA", (1024, 1024), "blue").save(self.root / "master.png")
        with patch("check_icon_artwork.subprocess.run") as run:
            errors = check_regenerated_artwork(self.root, self.command, self.manifest)
        run.assert_not_called()
        self.assertIn("approved decoded-pixel", errors[0])

    def test_symlink_and_manifest_escape_are_rejected(self):
        link = self.root / "escape"
        link.symlink_to(self.root, target_is_directory=True)
        self.assertIn("symlinks", check_regenerated_artwork(
            self.root, self.command, self.manifest)[0])
        link.unlink()
        manifest = json.loads(self.manifest.read_text())
        manifest["exports"]["../outside.png"] = {}
        self.manifest.write_text(json.dumps(manifest))
        self.assertIn("unsafe export", check_regenerated_artwork(
            self.root, self.command, self.manifest)[0])

    def test_cli_success_failure_and_empty_command(self):
        args = ["--root", str(self.root), "--manifest", str(self.manifest)]
        with redirect_stdout(StringIO()) as output:
            self.assertEqual(0, main(args + ["--regenerate"] + self.command))
            self.assertEqual(1, main(args + ["--regenerate"]))
        self.assertIn("requires a generator command", output.getvalue())


if __name__ == "__main__":
    unittest.main()
