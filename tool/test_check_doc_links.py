import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from check_doc_links import check_links, main, references


class WalkthroughLinkTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "docs").mkdir()
        (self.root / "README.md").write_text("[Guide](docs/usage.md#shopping)")
        (self.root / "docs/usage.md").write_text("# Shopping\n[Home](../README.md)")

    def errors(self):
        return check_links(self.root)[1]

    def test_valid_links_and_cycles(self):
        self.assertEqual(self.errors(), [])

    def test_missing_target(self):
        (self.root / "README.md").write_text("[broken](docs/missing.md)")
        self.assertIn("missing target", self.errors()[0])

    def test_each_document_uses_its_own_directory(self):
        (self.root / "README.md").write_text("[Guide](docs/detail.md#details)")
        (self.root / "docs/usage.md").write_text(
            "[Details](detail.md#details)\n[Home](../README.md)")
        (self.root / "docs/detail.md").write_text("# Details")
        self.assertEqual(self.errors(), [])
        (self.root / "docs/detail.md").unlink()
        errors = self.errors()
        self.assertTrue(any("README.md: link 1" in error for error in errors))
        self.assertTrue(any("docs/usage.md: link 1" in error for error in errors))
        self.assertTrue(all("docs/detail.md" in error for error in errors))

    def test_same_document_fragments_and_setext_headings(self):
        (self.root / "README.md").write_text(
            "Quick start\n===========\n[Here](#quick-start)\n"
            "## Quick start\n[Again](#quick-start-1)")
        self.assertEqual(self.errors(), [])
        (self.root / "README.md").write_text("# Changed\n[Here](#quick-start)")
        self.assertIn("missing anchor #quick-start", self.errors()[0])

    def test_heading_image_alt_contributes_to_slug(self):
        _, ids = references("# ![ShopIt](icon.png) **Guide**")
        self.assertIn("shopit-guide", ids)

    def test_anchor_changes_fail(self):
        (self.root / "docs/usage.md").write_text("# Renamed")
        self.assertIn("missing anchor #shopping", self.errors()[0])

    def test_formatting_unicode_duplicate_and_explicit_ids(self):
        _, ids = references('# **Café** & `Tea`\n# Café & Tea\n<a id="custom"></a>\n<a name="legacy"></a>')
        self.assertTrue({"café--tea", "café--tea-1", "custom", "legacy"} <= ids)

    def test_international_heading_slugs_preserve_unicode_marks_and_numbers(self):
        _, ids = references(
            "# 東京の買い物\n# Καλώς ήρθατε\n# Продукты питания\n"
            "# Cafe\u0301 2026\n# Emoji 🛒 & tea"
        )
        self.assertTrue({
            "東京の買い物", "καλώς-ήρθατε", "продукты-питания",
            "café-2026", "emoji---tea",
        } <= ids)

    def test_heading_slug_collision(self):
        _, ids = references("# One\n# One\n# One-1\n# One")
        self.assertTrue({"one", "one-1", "one-1-1", "one-2"} <= ids)

    def test_reference_and_html_links(self):
        links, _ = references('[Guide][g]\n\n[g]: docs/usage.md\n\n<a href="README.md">Home</a>')
        self.assertEqual(links, ["docs/usage.md", "README.md"])

    def test_examples_comments_and_image_sources_not_links(self):
        links, _ = references('`[x](bad)`\n\n```\n[x](bad)\n```\n\n<!-- <a href="bad">x</a> -->\n![Icon](bad)')
        self.assertEqual(links, [])

    def test_encoded_and_root_relative_paths(self):
        (self.root / "docs/with space.md").write_text("# Café", encoding="utf-8")
        (self.root / "README.md").write_text(
            "[x](/docs/with%20space.md?raw=1#caf%C3%A9)", encoding="utf-8"
        )
        self.assertEqual(self.errors(), [])

    def test_directory_heading_links_resolve_folder_readme(self):
        guide = self.root / "docs/cookbook"
        guide.mkdir()
        (guide / "README.md").write_text("# Getting started\n\n[valid](../usage.md#shopping)")
        (self.root / "README.md").write_text("[Start](docs/cookbook/#getting-started)")
        self.assertEqual(self.errors(), [])
        (self.root / "README.md").write_text("[Broken](docs/cookbook/#not-here)")
        self.assertIn("missing anchor #not-here", self.errors()[0])

    def test_directory_readme_is_traversed_without_fragment(self):
        guide = self.root / "docs/advanced"
        guide.mkdir()
        (guide / "README.markdown").write_text("[Missing](gone.md)")
        (self.root / "README.md").write_text("[Advanced](docs/advanced/)")
        self.assertTrue(any("docs/advanced/README.markdown" in error
                            for error in self.errors()))

    def test_directory_fragment_without_readme_fails(self):
        (self.root / "README.md").write_text("[Broken](docs/#no-readme)")
        self.assertIn("no Markdown README", self.errors()[0])

    def test_directory_readme_symlink_cannot_escape(self):
        with tempfile.TemporaryDirectory() as outside:
            external = Path(outside) / "README.md"
            external.write_text("# External")
            (self.root / "docs/README.md").symlink_to(external)
            (self.root / "README.md").write_text("[Docs](docs/#external)")
            self.assertIn("README escapes", self.errors()[0])

    def test_external_links_are_offline(self):
        (self.root / "README.md").write_text(
            "[web](https://example.invalid/missing.md#bad)\n"
            "[http](http://example.invalid/missing.md)\n"
            "[cdn](//example.invalid/missing.md#bad)\n"
            "[mail](mailto:a@example.invalid)")
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            self.assertEqual(self.errors(), [])

    def test_unsupported_url_and_path_escape(self):
        for target in ("javascript:alert", "../../outside.md", "https://[invalid"):
            (self.root / "README.md").write_text(f'<a href="{target}">x</a>')
            self.assertTrue(self.errors())

    def test_symlinks_outside_repository_fail(self):
        with tempfile.TemporaryDirectory() as outside:
            (self.root / "escape").symlink_to(outside, target_is_directory=True)
            (self.root / "README.md").write_text("[x](escape)")
            self.assertIn("escapes", self.errors()[0])

    def test_reachable_walkthrough_pages_also_checked(self):
        (self.root / "docs/usage.md").write_text("# Shopping\n[x](detail.md)")
        (self.root / "docs/detail.md").write_text("[bad](missing.md)")
        self.assertIn("docs/detail.md", self.errors()[0])

    def test_empty_html_link_and_document_limit(self):
        (self.root / "README.md").write_text('<a href="">empty</a>')
        self.assertIn("empty link", self.errors()[0])
        self.assertIn("linked-document limit", check_links(self.root, max_documents=1)[1][-1])

    def test_linked_image_checks_destination_not_image(self):
        (self.root / "README.md").write_text(
            "[![Icon](not-an-ordinary-link.png)](docs/missing.md)")
        self.assertEqual(len(self.errors()), 1)
        self.assertIn("docs/missing.md", self.errors()[0])

    def test_missing_unreadable_and_invalid_utf8_documents(self):
        guide = self.root / "docs/usage.md"
        guide.unlink()
        self.assertTrue(any("cannot read document" in error for error in self.errors()))
        guide.write_bytes(b"\xff")
        self.assertTrue(any("decode" in error for error in self.errors()))
        guide.write_text("# Shopping")
        original = Path.read_text

        def denied(path, *args, **kwargs):
            if path == guide:
                raise PermissionError("permission denied")
            return original(path, *args, **kwargs)

        with patch.object(Path, "read_text", denied):
            self.assertTrue(any("permission denied" in error for error in self.errors()))

    def test_symlink_loop_is_reported_without_crashing(self):
        (self.root / "loop.md").symlink_to("loop.md")
        (self.root / "README.md").write_text("[Loop](loop.md)")
        self.assertTrue(self.errors())
        self.assertTrue(check_links(self.root, documents=["loop.md"])[1])

    def test_document_byte_limit(self):
        with patch("check_doc_links.MAX_DOCUMENT_BYTES", 8):
            self.assertTrue(any("byte limit" in error for error in self.errors()))

    def test_cli_exit_status_and_output(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(main(["--root", str(self.root)]), 0)
        self.assertIn("0 error(s)", output.getvalue())
        (self.root / "docs/usage.md").write_text("[Broken](missing.md)")
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(main(["--root", str(self.root)]), 1)
        self.assertIn("docs/usage.md: link 1 (missing.md)", output.getvalue())
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            main(["--max-documents", "0"])
        self.assertEqual(error.exception.code, 2)

    def test_installed_script_defaults_to_repo_not_working_directory(self):
        tool = self.root / "tool"
        tool.mkdir()
        script = tool / "check_doc_links.py"
        script.write_bytes(Path(__file__).with_name("check_doc_links.py").read_bytes())
        with tempfile.TemporaryDirectory() as elsewhere:
            result = subprocess.run(
                [sys.executable, str(script)], cwd=elsewhere, env=os.environ.copy(),
                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
