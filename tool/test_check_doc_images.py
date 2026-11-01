import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import struct
import zlib

from PIL import Image as PillowImage

from check_doc_images import (
    ImageLimits, _gif_complete, _webp_complete, check_document,
    image_integrity_error, images_in, main, svg_integrity_error,
)


class DocImageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / "docs/icons").mkdir(parents=True)
        for name in ("example.png", "space name.png", "a(b).png",
                     "example.jpg", "example.jpeg", "UPPER.PNG", "UPPER.JPG"):
            with PillowImage.new("RGB", (16, 16), (40, 120, 200)) as image:
                image.save(self.root / "docs/icons" / name)
        (self.root / "README.md").write_text("", encoding="utf-8")
        (self.root / "docs/usage.md").write_text("", encoding="utf-8")

    def check(self, text, document="docs/usage.md"):
        (self.root / document).write_text(text, encoding="utf-8")
        return check_document(self.root, document)

    def animation(self, extension, animated=True):
        """Generate real files rather than relying on opaque binary fixtures."""
        asset = self.root / "docs/icons" / f"animation.{extension}"
        frames = [PillowImage.new("RGB", (32, 32), color)
                  for color in ("red", "green", "blue")]
        try:
            options = (dict(save_all=True, append_images=frames[1:], duration=50, loop=0)
                       if animated else {})
            options["format"] = "PNG" if extension.lower() in ("png", "apng") else None
            frames[0].save(asset, **{key: value for key, value in options.items() if value is not None})
        finally:
            for frame in frames:
                frame.close()
        return asset

    def damage_later_frame(self, asset):
        data = bytearray(asset.read_bytes())
        if asset.suffix.lower() == ".gif":
            with PillowImage.open(asset) as image:
                image.seek(1)
                # Invalid LZW code size in frame two; retain every block/trailer.
                data[image.tile[0].offset - 1] = 12
        elif asset.suffix.lower() == ".webp":
            position = 12
            frames = []
            while position < len(data):
                size = struct.unpack_from("<I", data, position + 4)[0]
                if data[position:position + 4] == b"ANMF":
                    frames.append((position, size))
                position += 8 + size + (size & 1)
            position, size = frames[1]
            # Keep the VP8 header/dimensions and chunk lengths intact, but
            # damage the compressed pixels of the second animation frame.
            start, end = position + 50, position + 8 + size
            data[start:end] = b"\xff" * (end - start)
        else:
            position = 8
            frames = []
            while position + 12 <= len(data):
                size = struct.unpack_from(">I", data, position)[0]
                if data[position + 4:position + 8] == b"fdAT":
                    frames.append((position, size))
                position += size + 12
            position, size = frames[-1]
            payload = position + 8
            data[payload + 4] ^= 0xFF  # retain APNG sequence number
            crc = zlib.crc32(data[position + 4:payload + size])
            struct.pack_into(">I", data, payload + size, crc)
        asset.write_bytes(data)

    def test_static_and_animated_gif_webp_in_both_documents(self):
        for extension in ("gif", "webp", "GIF", "WEBP"):
            for animated in (False, True):
                asset = self.animation(extension, animated)
                with self.subTest(extension=extension, animated=animated):
                    with PillowImage.open(asset) as image:
                        self.assertEqual(image.n_frames, 3 if animated else 1)
                    for document, prefix in (("README.md", "docs/icons"),
                                             ("docs/usage.md", "icons")):
                        self.assertEqual(self.check(
                            f"![Animation]({prefix}/{asset.name}?raw=1#preview)",
                            document), (1, []))

    def test_damaged_later_frames_fail_despite_valid_first_frame_and_container(self):
        for extension, container_check in (("gif", _gif_complete), ("webp", _webp_complete)):
            asset = self.animation(extension)
            self.damage_later_frame(asset)
            with self.subTest(extension=extension):
                container_check(asset.read_bytes())
                with PillowImage.open(asset) as image:
                    image.load()  # Opening/decoding only frame one would pass.
                self.assertIsNotNone(image_integrity_error(asset))
                for document, prefix in (("README.md", "docs/icons"),
                                         ("docs/usage.md", "icons")):
                    source = f"{prefix}/{asset.name}"
                    _, errors = self.check(f"![Animation]({source})", document)
                    self.assertEqual(len(errors), 1)
                    self.assertIn(f"{document}: image 1 ({source})", errors[0])
                    self.assertIn(f"damaged or unreadable image asset: docs/icons/{asset.name}", errors[0])
                    with contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(main(["--root", str(self.root)]), 1)

    def test_animated_png_and_apng_suffix_decode_every_frame(self):
        for extension in ("png", "apng"):
            asset = self.animation(extension)
            with PillowImage.open(asset) as image:
                self.assertEqual(image.n_frames, 3)
            for document, prefix in (("README.md", "docs/icons"),
                                     ("docs/usage.md", "icons")):
                source = f"{prefix}/{asset.name}"
                with self.subTest(extension=extension, document=document):
                    self.assertEqual(self.check(f"![Animation]({source})", document),
                                     (1, []))

    def test_damaged_later_apng_frame_is_detected_after_valid_crc(self):
        asset = self.animation("apng")
        self.damage_later_frame(asset)
        with PillowImage.open(asset) as image:
            image.load()
            image.seek(2)
            with self.assertRaises(Exception):
                image.load()
        for document, prefix in (("README.md", "docs/icons"),
                                 ("docs/usage.md", "icons")):
            source = f"{prefix}/{asset.name}"
            _, errors = self.check(f"![Animation]({source})", document)
            self.assertEqual(len(errors), 1)
            self.assertIn("damaged or unreadable", errors[0])

    def test_truncated_apng_is_detected(self):
        asset = self.animation("apng")
        asset.write_bytes(asset.read_bytes()[:-12])
        self.assertIn("damaged or unreadable", self.check(
            f"![Animation](icons/{asset.name})")[1][0])

    def test_gif_webp_corrupt_static_and_truncated_animation_fixtures(self):
        for extension in ("gif", "webp"):
            asset = self.animation(extension, animated=False)
            valid = asset.read_bytes()
            variants = (b"", b"not image data", valid[:len(valid) // 2], valid[:-1])
            for data in variants:
                with self.subTest(extension=extension, data=data[:10]):
                    asset.write_bytes(data)
                    self.assertIn("damaged or unreadable", self.check(
                        f"![Animation](icons/{asset.name})")[1][0])
            asset = self.animation(extension)
            asset.write_bytes(asset.read_bytes()[:-10])
            self.assertIn("damaged or unreadable", self.check(
                f"![Animation](icons/{asset.name})")[1][0])

    def test_webp_nested_frame_chunk_bounds(self):
        asset = self.animation("webp")
        data = bytearray(asset.read_bytes())
        frame = data.index(b"ANMF")
        # ANMF's 16-byte frame header is followed by nested image chunks.
        struct.pack_into("<I", data, frame + 28, len(data) + 500)
        asset.write_bytes(data)
        with self.assertRaisesRegex(OSError, "WebP chunk payload"):
            _webp_complete(data)
        self.assertIsNotNone(image_integrity_error(asset))

    def test_gif_webp_decorative_integrity_and_alt_rules(self):
        for extension in ("gif", "webp"):
            asset = self.animation(extension)
            for marker in ('role="presentation"', 'role="none"', 'aria-hidden="true"'):
                self.assertEqual(self.check(
                    f'<img src="icons/{asset.name}" alt="" {marker}>'), (1, []))
            self.damage_later_frame(asset)
            for marker in ('role="presentation"', 'role="none"', 'aria-hidden="true"'):
                errors = self.check(
                    f'<img src="icons/{asset.name}" alt="" {marker}>')[1]
                self.assertEqual(len(errors), 1)
                self.assertIn("damaged or unreadable", errors[0])
            errors = self.check(f'![](icons/{asset.name})')[1]
            self.assertEqual(len(errors), 2)
            self.assertIn("empty alt", errors[0])
            self.assertIn("damaged or unreadable", errors[1])

    def test_resolve_from_each_markdown_directory(self):
        self.assertEqual(self.check("![Icon](docs/icons/example.png)", "README.md"), (1, []))
        self.assertEqual(self.check("![Icon](icons/example.png)"), (1, []))
        self.assertEqual(self.check("![Icon](../docs/icons/example.png)"), (1, []))
        self.assertEqual(self.check("![Icon](/docs/icons/example.png)"), (1, []))
        self.assertIn("missing image asset", self.check("![Icon](docs/icons/example.png)")[1][0])

    def test_markdown_and_html_missing_assets(self):
        for text in ('![Screen](missing.png)', '<img alt="Screen" src="missing.png">'):
            with self.subTest(text=text):
                count, errors = self.check(text)
                self.assertEqual(count, 1)
                self.assertIn("missing image asset: docs/missing.png", errors[0])

    def test_alt_required_for_informative_images(self):
        for text in (
            '![](icons/example.png)',
            '![   ](icons/example.png)',
            '<img src="icons/example.png">',
            '<img src="icons/example.png" alt="">',
            '<img src="icons/example.png" alt=" &#32; ">',
        ):
            with self.subTest(text=text):
                self.assertIn("alt", self.check(text)[1][0])

    def test_explicit_decorative_images_still_require_asset_and_alt(self):
        for marker in ('role="presentation"', 'role="none"', 'aria-hidden="true"'):
            self.assertEqual(self.check(
                f'<img src="icons/example.png" alt="" {marker}>'
            ), (1, []))
            self.assertIn("missing image asset", self.check(
                f'<img src="missing.png" alt="" {marker}>'
            )[1][0])
        self.assertIn("missing alt", self.check(
            '<img src="icons/example.png" role="presentation">'
        )[1][0])

    def test_html_multiline_single_quotes_uppercase_and_self_closing(self):
        self.assertEqual(self.check(
            "<IMG\n SRC='icons/example.png'\n ALT='Example' />"
        ), (1, []))
        self.assertEqual(self.check(
            '<img src="icons/example.png" alt="Example" role aria-hidden>'
        ), (1, []))

    def test_html_table_images_are_checked(self):
        self.assertEqual(self.check(
            '<table><tr><td><img src="icons/example.png" alt="Icon"></td></tr></table>'
        ), (1, []))

    def test_reference_collapsed_shortcut_and_linked_images(self):
        text = (
            "![Example][image]\n\n![image][]\n\n![image]\n\n"
            "[![Linked](icons/example.png)](https://example.org)\n\n"
            '[image]: icons/example.png "Title"\n'
        )
        self.assertEqual(self.check(text), (4, []))

    def test_encoded_paths_query_fragment_and_parentheses(self):
        for source in (
            "icons/space%20name.png", "icons/example.png?raw=1#preview",
            "icons/a(b).png", "<icons/space name.png>",
        ):
            self.assertEqual(self.check(f'![Icon]({source} "Title")'), (1, []))
        self.assertEqual(self.check(
            '<img src="icons/example.png?raw=1&amp;size=2" alt="Icon">'
        ), (1, []))

    def test_remote_images_skip_network_but_not_alt(self):
        with patch("check_doc_images.PillowImage.open") as image_open, \
                patch("socket.socket", side_effect=AssertionError("network forbidden")):
            for extension in ("png", "gif", "webp"):
                for scheme in ("https:", "http:", ""):
                    source = f"{scheme}//example.invalid/a.{extension}"
                    self.assertEqual(self.check(f'<img src="{source}" alt="Remote">'), (1, []))
                    self.assertTrue(self.check(f'<img src="{source}">')[1])
            image_open.assert_not_called()

    def test_valid_png_and_jpeg_images(self):
        for name in ("example.png", "example.jpg", "example.jpeg", "UPPER.PNG", "UPPER.JPG"):
            with self.subTest(name=name):
                self.assertEqual(self.check(f"![Icon](icons/{name})"), (1, []))

    def test_jpeg_allows_trailing_bytes(self):
        asset = self.root / "docs/icons/example.jpg"
        asset.write_bytes(asset.read_bytes() + b"trailing metadata")
        self.assertEqual(self.check("![Icon](icons/example.jpg)"), (1, []))

    def test_damaged_image_fixtures(self):
        icons = self.root / "docs/icons"
        png = (icons / "example.png").read_bytes()
        jpeg = (icons / "example.jpg").read_bytes()
        # Keep the PNG header intact, but invalidate the IDAT chunk's CRC.
        corrupt_crc = bytearray(png)
        corrupt_crc[png.index(b"IDAT") + 4] ^= 1
        # A valid CRC with invalid compressed pixels passes verify(), not load().
        idat = png.index(b"IDAT")
        length = struct.unpack(">I", png[idat - 4:idat])[0]
        bad_data = b"\x00" * length
        bad_pixels = (
            png[:idat + 4] + bad_data
            + struct.pack(">I", zlib.crc32(b"IDAT" + bad_data))
            + png[idat + 4 + length + 4:]
        )
        fixtures = {
            "truncated.png": png[:-12],  # missing IEND
            "bad-crc.png": bytes(corrupt_crc),
            "bad-pixels.png": bad_pixels,
            "header-only.png": png[:33],
            "truncated.jpg": jpeg[:-2],  # missing end-of-image marker
            "truncated.jpeg": jpeg[:len(jpeg) // 2],
            "empty.PNG": b"",
            "not-image.JPG": b"not an image",
        }
        for name, data in fixtures.items():
            with self.subTest(name=name):
                (icons / name).write_bytes(data)
                count, errors = self.check(f"![Icon](icons/{name}?raw=1#preview)")
                self.assertEqual(count, 1)
                self.assertEqual(len(errors), 1)
                self.assertIn("damaged or unreadable image asset", errors[0])
                self.assertIn(f"docs/usage.md: image 1 (icons/{name}", errors[0])
                self.assertIn(f"docs/icons/{name}", errors[0])

    def test_damaged_decorative_images_and_alt_errors_are_not_exempt(self):
        (self.root / "docs/icons/broken.png").write_bytes(b"broken")
        for marker in ('role="presentation"', 'role="none"', 'aria-hidden="true"'):
            count, errors = self.check(f'<img src="icons/broken.png" alt="" {marker}>')
            self.assertEqual(count, 1)
            self.assertEqual(len(errors), 1)
            self.assertIn("damaged or unreadable", errors[0])
        _, errors = self.check('![](icons/broken.png)')
        self.assertEqual(len(errors), 2)
        self.assertIn("empty alt", errors[0])
        self.assertIn("damaged or unreadable", errors[1])

    def test_valid_svg_is_checked_without_pillow_or_network(self):
        (self.root / "docs/icons/vector.svg").write_text(
            '<svg xmlns="http://www.w3.org/2000/svg"/>', encoding="utf-8"
        )
        with patch("check_doc_images.PillowImage.open") as image_open:
            self.assertEqual(self.check("![Icon](icons/vector.svg)"), (1, []))
            image_open.assert_not_called()

    def test_malformed_svg_wrong_root_and_entity_declarations_fail(self):
        asset = self.root / "docs/icons/vector.svg"
        for data, message in (
            (b'<svg xmlns="http://www.w3.org/2000/svg"><g></svg>', "mismatched"),
            (b'<html/>', "not <svg>"),
            (b'<!DOCTYPE svg [<!ENTITY x "a">]><svg>&x;</svg>', "entities"),
            (b'<svg xmlns="https://example.invalid/svg"/>', "namespace"),
        ):
            with self.subTest(data=data):
                asset.write_bytes(data)
                _, errors = self.check("![Icon](icons/vector.svg)")
                self.assertEqual(len(errors), 1)
                self.assertIn("damaged or unreadable", errors[0])
                self.assertIn(message, errors[0])

    def test_svg_byte_limit_and_readable_warning_behavior(self):
        asset = self.root / "docs/icons/vector.svg"
        asset.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
        self.assertIn("byte limit", svg_integrity_error(asset, ImageLimits(max_bytes=4)))
        (self.root / "docs/usage.md").write_text(
            '![](icons/vector.svg)\n![Broken](icons/missing.svg)', encoding="utf-8")
        _, errors = check_document(self.root, "docs/usage.md")
        self.assertEqual(len(errors), 2)
        self.assertIn("empty alt", errors[0])
        self.assertIn("missing image asset", errors[1])

    def test_unreadable_image_reports_error(self):
        with patch("check_doc_images.PillowImage.open", side_effect=PermissionError("denied")):
            self.assertIn("damaged or unreadable", self.check("![Icon](icons/example.png)")[1][0])

    def assert_decompression_bomb_rejected(self, pixel_limit, error_type):
        # Existing fixtures are only 16x16 (256 pixels). Trigger Pillow's
        # own warning/error thresholds without allocating oversized images.
        for name in ("example.png", "example.jpg"):
            for document, prefix in (("README.md", "docs/icons"),
                                     ("docs/usage.md", "icons")):
                with self.subTest(name=name, document=document):
                    for path in ("README.md", "docs/usage.md"):
                        (self.root / path).write_text("", encoding="utf-8")
                    source = f"{prefix}/{name}?raw=1#preview"
                    text = f"![Icon]({source})"
                    output, stderr = io.StringIO(), io.StringIO()
                    with patch.object(PillowImage, "MAX_IMAGE_PIXELS", pixel_limit):
                        count, errors = self.check(text, document)
                        self.assertEqual(count, 1)
                        self.assertEqual(len(errors), 1)
                        self.assertIn(f"{document}: image 1 ({source})", errors[0])
                        self.assertIn(
                            f"damaged or unreadable image asset: docs/icons/{name}",
                            errors[0])
                        self.assertIn(f"{error_type.__name__}: Image size (256 pixels)", errors[0])
                        self.assertIn("exceeds limit of", errors[0])
                        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(stderr):
                            self.assertEqual(main(["--root", str(self.root)]), 1)
                    self.assertEqual(output.getvalue(),
                                     f"{errors[0]}\nDocumentation image check failed: 1 error(s).\n")
                    self.assertEqual(stderr.getvalue(), "")
                    self.assertEqual(self.check(text, document), (1, []))

    def test_decompression_bomb_warning_is_a_document_error(self):
        # Between MAX_IMAGE_PIXELS and twice that limit, Pillow warns.
        self.assert_decompression_bomb_rejected(200, PillowImage.DecompressionBombWarning)

    def test_decompression_bomb_error_is_a_document_error(self):
        # Above twice MAX_IMAGE_PIXELS, Pillow raises an error directly.
        self.assert_decompression_bomb_rejected(100, PillowImage.DecompressionBombError)

    def test_command_rejects_damaged_images_in_both_documents(self):
        (self.root / "docs/icons/example.png").write_bytes(b"broken")
        for document, source in (("README.md", "docs/icons/example.png"),
                                 ("docs/usage.md", "icons/example.png")):
            with self.subTest(document=document):
                (self.root / "README.md").write_text("", encoding="utf-8")
                (self.root / "docs/usage.md").write_text("", encoding="utf-8")
                self.check(f"![Icon]({source})", document)
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    self.assertEqual(main(["--root", str(self.root)]), 1)
                self.assertIn(document, output.getvalue())
                self.assertIn("damaged or unreadable", output.getvalue())

    def test_ignores_code_comments_and_escaped_markdown(self):
        text = (
            '`![](missing.png)` and `<img src="missing.png">`\n\n'
            '```md\n![](missing.png)\n<img src="missing.png">\n```\n\n'
            '    ![](missing.png)\n\n'
            '<!-- <img src="missing.png"> ![](missing.png) -->\n\n'
            r'\![not an image](missing.png)'
        )
        self.assertEqual(images_in(text), [])

    def test_missing_source_directory_and_escape_fail(self):
        for text, expected in (
            ('<img alt="Icon">', "missing image source"),
            ('![Icon](#anchor)', "missing image path"),
            ('![Icon](icons)', "missing image asset"),
            ('![Icon](../../outside.png)', "escapes the repository"),
            ('<img alt="Icon" src="file:///tmp/test.png">', "unsupported"),
            ('<img alt="Icon" src="https://[broken">', "invalid image URL"),
        ):
            with self.subTest(text=text):
                self.assertIn(expected, self.check(text)[1][0])

    def test_missing_document_and_invalid_encoding_fail(self):
        (self.root / "README.md").unlink()
        self.assertIn("cannot read document", check_document(self.root, "README.md")[1][0])
        (self.root / "README.md").write_bytes(b"\xff")
        self.assertIn("cannot read document", check_document(self.root, "README.md")[1][0])

    def test_symlink_cannot_escape_repository(self):
        with tempfile.TemporaryDirectory() as outside:
            target = Path(outside) / "outside.png"
            target.write_bytes(b"fixture")
            (self.root / "docs/icons/link.png").symlink_to(target)
            self.assertIn("escapes the repository", self.check(
                "![Icon](icons/link.png)"
            )[1][0])

    def test_command_checks_both_documents_and_returns_nonzero(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(main(["--root", str(self.root)]), 0)
            (self.root / "docs/usage.md").write_text("![](missing.png)", encoding="utf-8")
            self.assertEqual(main(["--root", str(self.root)]), 1)
        self.assertIn("docs/usage.md", output.getvalue())
        self.assertIn("missing image asset", output.getvalue())
        self.assertIn("empty alt text", output.getvalue())


if __name__ == "__main__":
    unittest.main()
