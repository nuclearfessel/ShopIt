"""Tests for the ShopIt release version bump scheme."""
import tempfile
import unittest
from pathlib import Path

from bump_release_version import bump_pubspec_text, bump_semver


class BumpSemverTests(unittest.TestCase):
    def test_patch_increments_within_band(self):
        self.assertEqual(bump_semver(1, 0, 0), (1, 0, 1))
        self.assertEqual(bump_semver(1, 0, 8), (1, 0, 9))

    def test_patch_nine_rolls_minor(self):
        self.assertEqual(bump_semver(1, 0, 9), (1, 1, 0))
        self.assertEqual(bump_semver(1, 1, 9), (1, 2, 0))
        self.assertEqual(bump_semver(2, 0, 9), (2, 1, 0))

    def test_minor_nine_rolls_major(self):
        self.assertEqual(bump_semver(1, 9, 9), (2, 0, 0))
        self.assertEqual(bump_semver(9, 9, 9), (10, 0, 0))


class BumpPubspecTests(unittest.TestCase):
    def test_rewrites_version_and_build(self):
        text = "name: shop_it\nversion: 1.0.0+33\n"
        updated, name, code = bump_pubspec_text(text)
        self.assertEqual(name, "1.0.1")
        self.assertEqual(code, 34)
        self.assertIn("version: 1.0.1+34", updated)

    def test_roll_from_1_0_9(self):
        _, name, code = bump_pubspec_text("version: 1.0.9+40\n")
        self.assertEqual((name, code), ("1.1.0", 41))

    def test_roll_from_9_9_9(self):
        _, name, code = bump_pubspec_text("version: 9.9.9+99\n")
        self.assertEqual((name, code), ("10.0.0", 100))

    def test_missing_build_starts_at_one(self):
        _, name, code = bump_pubspec_text("version: 1.2.3\n")
        self.assertEqual((name, code), ("1.2.4", 1))

    def test_write_round_trip(self):
        from bump_release_version import bump_file

        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "pubspec.yaml"
            path.write_text("version: 1.1.9+7\n", encoding="utf-8")
            name, code = bump_file(path, write=True)
            self.assertEqual((name, code), ("1.2.0", 8))
            self.assertEqual(path.read_text(encoding="utf-8").strip(), "version: 1.2.0+8")


if __name__ == "__main__":
    unittest.main()
