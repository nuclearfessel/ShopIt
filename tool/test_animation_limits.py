import contextlib
import io
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image
from check_doc_images import ImageLimits, check_document, image_integrity_error, main


class AnimationAndBudgetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "docs").mkdir()
        (self.root / "README.md").write_text("")
        (self.root / "docs/usage.md").write_text("")

    def make(self, suffix, animated=False):
        path = self.root / f"image.{suffix}"
        frames = [Image.new("RGB", (12, 12), color) for color in ("red", "green", "blue")]
        kwargs = {"save_all": True, "append_images": frames[1:], "duration": 50, "loop": 0} if animated else {}
        frames[0].save(path, **kwargs)
        return path

    def test_static_and_all_animation_frames_pass(self):
        for extension in ("gif", "webp"):
            for animated in (False, True):
                with self.subTest(extension=extension, animated=animated):
                    self.assertIsNone(image_integrity_error(self.make(extension, animated)))

    def test_truncated_animation_container_fails(self):
        for extension in ("gif", "webp"):
            path = self.make(extension, True)
            path.write_bytes(path.read_bytes()[:-1])
            self.assertIsNotNone(image_integrity_error(path))

    def test_gif_missing_trailer_cannot_hide_behind_decoding(self):
        path = self.make("gif")
        path.write_bytes(path.read_bytes()[:-1])
        self.assertIn("trailer", image_integrity_error(path))

    def test_bad_webp_chunk_size_fails(self):
        path = self.make("webp")
        data = bytearray(path.read_bytes())
        struct.pack_into("<I", data, 16, len(data) + 500)
        path.write_bytes(data)
        self.assertIsNotNone(image_integrity_error(path))

    def test_bad_format_contents_fail(self):
        for extension in ("gif", "webp"):
            path = self.root / f"invalid.{extension}"
            path.write_bytes(b"not image data")
            self.assertIsNotNone(image_integrity_error(path))

    def test_frame_limit_stops_before_loading_extra_frame(self):
        for extension in ("gif", "webp"):
            self.assertIn("frame limit", image_integrity_error(
                self.make(extension, True), ImageLimits(max_frames=2)))

    def test_total_pixel_limit(self):
        self.assertIn("total pixel limit", image_integrity_error(
            self.make("gif", True), ImageLimits(max_total_pixels=200)))

    def test_byte_limit_checked_before_decoder(self):
        path = self.make("gif")
        with patch("check_doc_images.PillowImage.open") as decoder:
            self.assertIn("byte limit", image_integrity_error(path, ImageLimits(max_bytes=1)))
            decoder.assert_not_called()

    def test_pixel_limit_before_load(self):
        self.assertIn("pixel limit", image_integrity_error(
            self.make("webp"), ImageLimits(max_pixels=10)))

    def test_normal_image_after_oversized_one_is_still_checked(self):
        self.make("gif", True)
        (self.root / "bad.webp").write_bytes(b"bad")
        (self.root / "README.md").write_text("![big](image.gif)\n![bad](bad.webp)")
        count, errors = check_document(self.root, "README.md", ImageLimits(max_pixels=10))
        self.assertEqual(count, 2)
        self.assertEqual(len(errors), 2)
        self.assertIn("bad.webp", errors[1])

    def test_document_image_paths_and_decorative_animations(self):
        self.make("gif")
        (self.root / "README.md").write_text('<img src="image.gif" alt="" role="presentation">')
        self.assertEqual(check_document(self.root, "README.md"), (1, []))

    def test_cli_limit_and_invalid_limit(self):
        self.make("gif")
        (self.root / "README.md").write_text("![Animation](image.gif)")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(["--root", str(self.root), "--max-image-bytes", "1"]), 1)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            main(["--max-image-frames", "0"])
        self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
