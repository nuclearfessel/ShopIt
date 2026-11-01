from io import BytesIO
import json
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from PIL import Image
from check_icon_artwork import pixel_digest
from check_built_icons import check_windows, check_macos, main as icon_main
from check_built_version import verify_version, windows_version, main as version_main


def pe_fixture(resources):
    """Minimal real PE32 .rsrc section; parsed by pefile, not a fake parser."""
    content = bytearray()

    def allocate(length):
        while len(content) % 4:
            content.append(0)
        offset = len(content)
        content.extend(bytes(length))
        return offset

    def directory(node):
        offset = allocate(16 + len(node) * 8)
        struct.pack_into("<HH", content, offset + 12, 0, len(node))
        for index, (key, value) in enumerate(sorted(node.items())):
            if isinstance(value, dict):
                target = directory(value) | 0x80000000
            else:
                target = allocate(16)
                payload = allocate(len(value))
                content[payload:payload + len(value)] = value
                struct.pack_into("<IIII", content, target, 0x1000 + payload, len(value), 0, 0)
            struct.pack_into("<II", content, offset + 16 + index * 8, key, target)
        return offset

    assert directory(resources) == 0
    headers = bytearray(512)
    headers[:2] = b"MZ"
    struct.pack_into("<I", headers, 60, 128)
    headers[128:132] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", headers, 132, 0x14C, 1, 0, 0, 0, 224, 0x102)
    optional = 152
    struct.pack_into("<H", headers, optional, 0x10B)
    struct.pack_into("<III", headers, optional + 28, 0x400000, 4096, 512)
    struct.pack_into("<II", headers, optional + 56, 0x1000 + ((len(content) + 4095) // 4096) * 4096, 512)
    struct.pack_into("<I", headers, optional + 92, 16)
    struct.pack_into("<II", headers, optional + 112, 0x1000, len(content))
    raw_length = ((len(content) + 511) // 512) * 512
    section = optional + 224
    headers[section:section + 8] = b".rsrc\0\0\0"
    struct.pack_into("<IIII", headers, section + 8, len(content), 0x1000, raw_length, 512)
    struct.pack_into("<I", headers, section + 36, 0x40000040)
    return bytes(headers + content + bytes(raw_length - len(content)))


class NativeArtifactsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = {"exports": {}}
        self.pngs = {}
        self.resources = {3: {}, 14: {101: {}}}
        group = bytearray(struct.pack("<HHH", 0, 1, 7))
        self.icns = bytearray()
        tags = {16: b"icp4", 32: b"icp5", 64: b"icp6", 128: b"ic07",
                256: b"ic08", 512: b"ic09", 1024: b"ic10"}
        for index, size in enumerate((16, 24, 32, 48, 64, 128, 256, 512, 1024), 1):
            image = Image.new("RGBA", (size, size), (240, 120, 20, 255))
            encoded = BytesIO()
            image.save(encoded, format="PNG")
            payload = encoded.getvalue()
            self.pngs[size] = payload
            record = {"size": [size, size], "sha256": pixel_digest(image)}
            if size <= 256:
                self.resources[3][index] = {1033: payload}
                group.extend(struct.pack("<BBBBHHIH", size % 256, size % 256, 0, 0, 1, 32, len(payload), index))
                self.manifest["exports"][f"windows/runner/resources/app_icon.ico#{size}"] = record
            if size in tags:
                self.icns.extend(tags[size] + struct.pack(">I", len(payload) + 8) + payload)
                self.manifest["exports"][f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png"] = record
        self.resources[14][101][1033] = bytes(group)
        self.exe = self.root / "ShopIt.exe"
        self.write_pe()
        self.app = self.root / "ShopIt.app"
        resources = self.app / "Contents/Resources"
        resources.mkdir(parents=True)
        self.icon = resources / "AppIcon.icns"
        self.icon.write_bytes(b"icns" + struct.pack(">I", len(self.icns) + 8) + self.icns)
        self.info = self.app / "Contents/Info.plist"
        self.info.write_bytes(plistlib.dumps({"CFBundleIconFile": "AppIcon",
                                             "CFBundleShortVersionString": "1.2.3",
                                             "CFBundleVersion": "42"}))

    def write_pe(self):
        self.exe.write_bytes(pe_fixture(self.resources))

    def write_icns(self, chunks):
        payload = b"".join(tag + struct.pack(">I", len(data) + 8) + data
                           for tag, data in chunks)
        self.icon.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)

    def test_real_pe_icon_resources_pass(self):
        check_windows(self.exe, self.manifest)

    def test_missing_main_icon_group_fails(self):
        self.resources[14][102] = self.resources[14].pop(101)
        self.write_pe()
        with self.assertRaisesRegex(ValueError, "main icon"):
            check_windows(self.exe, self.manifest)

    def test_missing_pe_frame_resource_fails(self):
        del self.resources[3][1]
        self.write_pe()
        with self.assertRaisesRegex(ValueError, "payload"):
            check_windows(self.exe, self.manifest)

    def test_wrong_compiled_windows_artwork_fails(self):
        key = next(key for key in self.manifest["exports"] if key.endswith("#16"))
        self.manifest["exports"][key]["sha256"] = "wrong"
        with self.assertRaisesRegex(ValueError, "artwork differs"):
            check_windows(self.exe, self.manifest)

    def test_stale_windows_payload_fails_without_changing_baseline(self):
        changed = BytesIO()
        Image.new("RGBA", (16, 16), (0, 0, 255, 255)).save(changed, format="PNG")
        payload = changed.getvalue()
        self.resources[3][1][1033] = payload
        group = bytearray(self.resources[14][101][1033])
        struct.pack_into("<I", group, 14, len(payload))
        self.resources[14][101][1033] = bytes(group)
        self.write_pe()
        with self.assertRaisesRegex(ValueError, "language 1033, 16px: artwork differs"):
            check_windows(self.exe, self.manifest)

    def test_every_windows_language_is_checked(self):
        self.resources[14][101][1041] = self.resources[14][101][1033]
        self.write_pe()
        with self.assertRaisesRegex(ValueError, "language 1041"):
            check_windows(self.exe, self.manifest)
        for payload in self.resources[3].values():
            payload[1041] = payload[1033]
        self.write_pe()
        check_windows(self.exe, self.manifest)

    def test_dib_encoded_windows_resources_pass(self):
        group = bytearray(self.resources[14][101][1033])
        for index, languages in self.resources[3].items():
            size = (16, 24, 32, 48, 64, 128, 256)[index - 1]
            image = Image.open(BytesIO(languages[1033]))
            encoded = BytesIO()
            image.save(encoded, format="ICO", sizes=[(size, size)], bitmap_format="bmp")
            ico = encoded.getvalue()
            length, offset = struct.unpack_from("<II", ico, 14)
            languages[1033] = ico[offset:offset + length]
            struct.pack_into("<I", group, 6 + (index - 1) * 14 + 8, length)
        self.resources[14][101][1033] = bytes(group)
        self.write_pe()
        check_windows(self.exe, self.manifest)

    def test_configured_windows_main_group(self):
        self.resources[14][102] = self.resources[14].pop(101)
        self.write_pe()
        check_windows(self.exe, self.manifest, resource_id=102)

    def test_duplicate_windows_size_fails(self):
        group = bytearray(self.resources[14][101][1033])
        group[20:22] = group[6:8]
        self.resources[14][101][1033] = bytes(group)
        self.write_pe()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            check_windows(self.exe, self.manifest)

    def test_icns_bundle_passes(self):
        check_macos(self.app, self.manifest)

    def test_wrong_compiled_mac_artwork_fails(self):
        key = "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
        self.manifest["exports"][key]["sha256"] = "wrong"
        with self.assertRaisesRegex(ValueError, "artwork differs"):
            check_macos(self.app, self.manifest)

    def test_stale_mac_payload_fails_without_changing_baseline(self):
        changed = BytesIO()
        Image.new("RGBA", (16, 16), (0, 0, 255, 255)).save(changed, format="PNG")
        self.write_icns([(b"icp4", changed.getvalue())])
        with self.assertRaisesRegex(ValueError, "macOS AppIcon.icns.*artwork differs"):
            check_macos(self.app, self.manifest)

    def test_missing_compiled_mac_size_fails(self):
        self.write_icns([(b"icp4", self.pngs[16])])
        with self.assertRaisesRegex(ValueError, "missing physical pixel sizes"):
            check_macos(self.app, self.manifest)

    def test_missing_compiled_mac_icon_fails(self):
        self.icon.unlink()
        with self.assertRaises(FileNotFoundError):
            check_macos(self.app, self.manifest)

    def test_duplicate_icns_tag_fails_instead_of_hiding_payload(self):
        self.write_icns([(b"icp4", self.pngs[32]), (b"icp4", self.pngs[16])])
        with self.assertRaisesRegex(ValueError, "duplicate ICNS entry"):
            check_macos(self.app, self.manifest)

    def test_retina_representation_is_checked(self):
        # Add a 16pt @2x representation alongside the ordinary 32px frame.
        data = self.icon.read_bytes()[8:]
        payload = self.pngs[32]
        data += b"ic11" + struct.pack(">I", len(payload) + 8) + payload
        self.icon.write_bytes(b"icns" + struct.pack(">I", len(data) + 8) + data)
        check_macos(self.app, self.manifest)
        changed = BytesIO()
        Image.new("RGBA", (32, 32), (0, 0, 255, 255)).save(changed, format="PNG")
        payload = changed.getvalue()
        data = self.icon.read_bytes()[8:-(len(self.pngs[32]) + 8)]
        data += b"ic11" + struct.pack(">I", len(payload) + 8) + payload
        self.icon.write_bytes(b"icns" + struct.pack(">I", len(data) + 8) + data)
        with self.assertRaisesRegex(ValueError, "artwork differs"):
            check_macos(self.app, self.manifest)

    def test_catalog_only_bundle_is_not_accepted(self):
        self.info.write_bytes(plistlib.dumps({"CFBundleIconName": "AppIcon"}))
        (self.icon.parent / "Assets.car").write_bytes(b"not a certified catalog")
        with self.assertRaisesRegex(ValueError, "catalog-only Assets.car.*unsupported"):
            check_macos(self.app, self.manifest)

    def test_mac_icon_filename_cannot_escape_resources(self):
        self.info.write_bytes(plistlib.dumps({"CFBundleIconFile": "../AppIcon.icns"}))
        with self.assertRaisesRegex(ValueError, "CFBundleIconFile"):
            check_macos(self.app, self.manifest)

    def test_truncated_icns_fails(self):
        self.icon.write_bytes(self.icon.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, "ICNS"):
            check_macos(self.app, self.manifest)

    def test_unresolved_bundle_icon_fails(self):
        self.info.write_bytes(plistlib.dumps({"CFBundleIconFile": ""}))
        with self.assertRaisesRegex(ValueError, "CFBundleIconFile"):
            check_macos(self.app, self.manifest)

    def test_native_version_success_and_mismatch(self):
        self.assertEqual(version_main(["--macos-app", str(self.app), "--expected-version", "1.2.3", "--expected-build", "42"]), 0)
        self.assertEqual(version_main(["--macos-app", str(self.app), "--expected-version", "1.2.4", "--expected-build", "42"]), 1)

    def test_empty_or_unresolved_version_fails(self):
        for version, build in (("", ""), ("$(FLUTTER_BUILD_NAME)", "42"), ("1.2.3", "41")):
            with self.assertRaises(ValueError):
                verify_version(version, build, "1.2.3", "42")

    def test_windows_metadata_extraction(self):
        table = SimpleNamespace(entries={b"ProductVersion": b"1.2.3\0"})
        fake = SimpleNamespace(FileInfo=[[SimpleNamespace(StringTable=[table])]],
                               VS_FIXEDFILEINFO=[SimpleNamespace(FileVersionLS=(3 << 16) + 42)],
                               close=lambda: None)
        with patch("pefile.PE", return_value=fake):
            self.assertEqual(windows_version(self.exe), ("1.2.3", "42"))
            table.entries[b"ProductVersion"] = b"1.2.3+42"
            self.assertEqual(windows_version(self.exe), ("1.2.3", "42"))
            table.entries[b"ProductVersion"] = b"1.2.3+41"
            with self.assertRaisesRegex(ValueError, "disagree"):
                windows_version(self.exe)

    def test_missing_windows_version_resource_fails(self):
        with self.assertRaisesRegex(ValueError, "version resources"):
            windows_version(self.exe)

    def test_cli_rejects_wrong_artwork(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps({"exports": {}}))
        self.assertEqual(icon_main(["--windows-exe", str(self.exe), "--manifest", str(path)]), 1)

    def test_cli_success_for_both_native_artifacts(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.manifest))
        self.assertEqual(icon_main(["--windows-exe", str(self.exe), "--macos-app",
                                    str(self.app), "--manifest", str(path)]), 0)

    def test_cli_missing_artifact_exits_nonzero(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.manifest))
        for flag in ("--windows-exe", "--macos-app"):
            with self.subTest(flag=flag):
                self.assertEqual(icon_main([flag, str(self.root / "missing"),
                                            "--manifest", str(path)]), 1)


if __name__ == "__main__":
    unittest.main()
