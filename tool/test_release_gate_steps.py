from pathlib import Path
import subprocess
import tempfile
import unittest

from release_gate_steps import gate_release_workflow, make_patch


FIXTURE = """name: Release
jobs:
  check:
    steps:
      - name: Analyze and test
        run: flutter test
  android:
    steps:
      - name: Upload APK
        uses: actions/upload-artifact@v7
  windows:
    steps:
      - name: Build installer
        run: build-installer
      - name: Upload installer
        uses: actions/upload-artifact@v7
  macos:
    steps:
      - name: Upload Mac app
        uses: actions/upload-artifact@v7
  publish:
    needs: [version, android, windows, macos, ios]
    steps:
      - run: publish-existing-release
"""


class ReleaseGateStepsTests(unittest.TestCase):
    def test_source_and_built_payload_checks_precede_uploads(self):
        result = gate_release_workflow(FIXTURE)
        for check, upload in (
            ("Verify packaged Android launcher icons", "Upload APK"),
            ("Verify compiled Windows icon", "Build installer"),
            ("Verify Windows installer payload", "Upload installer"),
            ("Verify compiled and packaged macOS icons", "Upload Mac app"),
        ):
            self.assertLess(result.index(check), result.index(upload))
        self.assertIn("if ($LASTEXITCODE -ne 0)", result)
        self.assertIn("set -euo pipefail", result)
        self.assertIn("needs: [version, android, windows, macos, ios]", result)
        self.assertIn("run: publish-existing-release", result)

    def test_patch_applies_without_replacing_unrelated_jobs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            workflow = root / ".github/workflows/release.yml"
            workflow.parent.mkdir(parents=True)
            workflow.write_text(FIXTURE)
            patch = root / "gate.patch"
            patch.write_text(make_patch(FIXTURE))
            result = subprocess.run(["git", "apply", str(patch)], cwd=root,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(workflow.read_text(), gate_release_workflow(FIXTURE))

    def test_unknown_workflow_and_repeat_install_fail_explicitly(self):
        with self.assertRaises(ValueError):
            gate_release_workflow("jobs: {}")
        with self.assertRaisesRegex(ValueError, "already present"):
            gate_release_workflow(gate_release_workflow(FIXTURE))


if __name__ == "__main__":
    unittest.main()
