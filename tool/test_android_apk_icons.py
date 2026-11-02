from io import BytesIO
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from zipfile import ZipFile

from PIL import Image
from check_android_apk_icons import DENSITIES, check_android_apk, selected_icons
from check_icon_artwork import pixel_digest
from validate_app_icons import ANDROID_SIZES


class PackagedAndroidIconsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.apk = Path(self.temp.name) / "ShopIt.apk"
        self.manifest = {"exports": {}}
        self.payloads, lines = {}, []
        for dpi, density in DENSITIES.items():
            size = ANDROID_SIZES[density]
            image = Image.new("RGBA", (size, size), (240, 130, 30, 255))
            encoded = BytesIO()
            image.save(encoded, format="PNG")
            name = f"res/mipmap-{density}-v4/ic_launcher.png"
            self.payloads[name] = encoded.getvalue()
            lines.append(f"application-icon-{dpi}:'{name}'")
            self.manifest["exports"][
                f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
            ] = {"size": [size, size], "sha256": pixel_digest(image)}
        self.badging = "\n".join(lines)
        self.write_apk()

    def write_apk(self):
        with ZipFile(self.apk, "w") as archive:
            for name, data in self.payloads.items():
                archive.writestr(name, data)

    def check(self):
        with patch("check_android_apk_icons.subprocess.run",
                   return_value=SimpleNamespace(stdout=self.badging)) as command:
            check_android_apk(self.apk, self.manifest, "known-aapt")
            self.assertEqual(command.call_args.args[0][:3], ["known-aapt", "dump", "badging"])

    def test_selected_compiled_png_payloads_pass(self):
        self.check()

    def test_stale_artwork_fails(self):
        key = next(iter(self.manifest["exports"]))
        self.manifest["exports"][key]["sha256"] = "not-approved"
        with self.assertRaisesRegex(ValueError, "artwork differs"):
            self.check()

    def test_missing_density_and_duplicate_selection_fail(self):
        with self.assertRaisesRegex(ValueError, "missing densities"):
            selected_icons(self.badging.splitlines()[0])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            selected_icons(self.badging + "\n" + self.badging.splitlines()[0])

    def test_selected_resource_not_guessed_from_filename(self):
        self.badging = self.badging.replace("ic_launcher.png", "other.png")
        with self.assertRaisesRegex(ValueError, "missing or duplicate"):
            self.check()

    def test_adaptive_xml_requires_reviewed_png_fallbacks(self):
        self.badging = "\n".join(
            f"application-icon-{dpi}:'res/mipmap-anydpi-v26/ic_launcher.xml'"
            for dpi in DENSITIES
        )
        with ZipFile(self.apk, "a") as archive:
            archive.writestr(
                "res/mipmap-anydpi-v26/ic_launcher.xml",
                b"<adaptive-icon/>",
            )
        self.check()

    def test_adaptive_xml_without_png_fallback_fails(self):
        self.badging = "\n".join(
            f"application-icon-{dpi}:'res/mipmap-anydpi-v26/ic_launcher.xml'"
            for dpi in DENSITIES
        )
        self.payloads = {
            "res/mipmap-anydpi-v26/ic_launcher.xml": b"<adaptive-icon/>",
        }
        self.write_apk()
        with self.assertRaisesRegex(ValueError, "reviewed ic_launcher.png"):
            self.check()

    def test_adaptive_xml_finds_hashed_png_fallback_by_artwork(self):
        self.badging = "\n".join(
            f"application-icon-{dpi}:'res/mipmap-anydpi-v26/ic_launcher.xml'"
            for dpi in DENSITIES
        )
        hashed = {}
        for dpi, density in DENSITIES.items():
            old = f"res/mipmap-{density}-v4/ic_launcher.png"
            new = f"res/{density[0].upper()}{dpi}.png"
            hashed[new] = self.payloads[old]
        hashed["res/mipmap-anydpi-v26/ic_launcher.xml"] = b"<adaptive-icon/>"
        self.payloads = hashed
        self.write_apk()
        self.check()

    def test_corrupt_payload_fails(self):
        self.payloads[next(iter(self.payloads))] = b"invalid PNG"
        self.write_apk()
        with self.assertRaises(OSError):
            self.check()

    def test_bad_png_crc_is_not_hidden_by_matching_pixels(self):
        name = next(iter(self.payloads))
        data = bytearray(self.payloads[name])
        offset = data.index(b"IDAT")
        length = int.from_bytes(data[offset - 4:offset], "big")
        data[offset + 4 + length] ^= 1
        self.payloads[name] = bytes(data)
        self.write_apk()
        with self.assertRaises((OSError, SyntaxError)):
            self.check()

    def test_aapt_failure_is_not_a_pass(self):
        with patch("check_android_apk_icons.subprocess.run",
                   side_effect=subprocess.CalledProcessError(1, "aapt")):
            with self.assertRaises(subprocess.CalledProcessError):
                check_android_apk(self.apk, self.manifest)


if __name__ == "__main__":
    unittest.main()
