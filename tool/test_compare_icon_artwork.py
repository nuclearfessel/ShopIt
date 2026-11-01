import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from PIL import Image
from compare_icon_artwork import create_report, main


class IconComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.before, self.after = self.root / "before", self.root / "after"
        self.before.mkdir()
        self.after.mkdir()
        for folder in (self.before, self.after):
            Image.new("RGBA", (16, 16), (220, 100, 20, 255)).save(folder / "icon.png")
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps({"source": "icon.png", "exports": {"icon.png": {}}}))
        self.output = self.root / "report"

    def report(self):
        return create_report(self.after, self.output, self.manifest, before_root=self.before)

    def test_unchanged_has_readable_self_contained_report(self):
        self.assertEqual(self.report()["changed"], 0)
        self.assertIn("No visible icon changes", (self.output / "index.html").read_text())

    def test_changed_pixels_produce_comparison_and_json(self):
        Image.new("RGBA", (16, 16), (0, 80, 200, 255)).save(self.after / "icon.png")
        self.assertEqual(self.report()["changed"], 1)
        self.assertIn("data:image/png;base64,", (self.output / "index.html").read_text())
        with Image.open(self.output / "comparison-000.png") as image:
            self.assertEqual(image.size, (768, 288))

    def test_invisible_rgb_does_not_generate_noise(self):
        for folder, color in ((self.before, "red"), (self.after, "blue")):
            image = Image.new("RGBA", (16, 16), color)
            image.putalpha(0)
            image.save(folder / "icon.png")
        self.assertEqual(self.report()["changed"], 0)

    def test_invalid_or_missing_current_image_is_visible_in_report(self):
        (self.after / "icon.png").write_bytes(b"bad")
        report = self.report()
        self.assertEqual(report["changed"], 1)
        self.assertIn("error", report["icons"][0]["after"])

    def test_git_commit_baseline_works_without_extra_worktrees(self):
        for command in (
            ["git", "init", "-q"],
            ["git", "add", "icon.png"],
            ["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             "commit", "-qm", "baseline"],
        ):
            subprocess.run(command, cwd=self.after, check=True, capture_output=True)
        Image.new("RGBA", (16, 16), "blue").save(self.after / "icon.png")
        self.assertEqual(main([
            "--root", str(self.after), "--manifest", str(self.manifest),
            "--before-ref", "HEAD", "--output-dir", str(self.output)
        ]), 0)
        self.assertEqual(json.loads((self.output / "report.json").read_text())["changed"], 1)

    def test_unsafe_manifest_paths_fail(self):
        self.manifest.write_text(json.dumps({"source": "../secret.png", "exports": {}}))
        with self.assertRaisesRegex(ValueError, "unsafe"):
            self.report()


if __name__ == "__main__":
    unittest.main()
