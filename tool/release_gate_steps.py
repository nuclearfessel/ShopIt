"""Generate a reviewed release-workflow patch; never upload or publish anything."""
import argparse
import difflib
from pathlib import Path


SOURCE_GATE = """      - name: Set up Python for source icon gate
        uses: actions/setup-python@v6
        with:
          python-version: '3.13'

      - name: Verify source icon contract
        run: |
          python -m pip install -r tool/icon-requirements.txt
          python tool/validate_app_icons.py
          python tool/check_icon_artwork.py

"""

WINDOWS_GATE = """      - name: Set up Python for Windows icon gate
        uses: actions/setup-python@v6
        with:
          python-version: '3.13'

      - name: Verify compiled Windows icon
        shell: pwsh
        run: |
          python -m pip install -r tool/native-requirements.txt
          if ($LASTEXITCODE -ne 0) { throw "Icon checker dependencies failed" }
          $exe = "build/windows/x64/runner/Release/shop_it.exe"
          python tool/check_built_icons.py --windows-exe "$exe"
          if ($LASTEXITCODE -ne 0) { throw "Compiled Windows icon failed" }
          python tool/check_built_version.py --windows-exe "$exe" --expected-version "${{ needs.version.outputs.name }}" --expected-build "${{ needs.version.outputs.code }}"
          if ($LASTEXITCODE -ne 0) { throw "Compiled Windows version failed" }

"""

WINDOWS_PAYLOAD_GATE = """      - name: Verify Windows installer payload
        shell: pwsh
        run: |
          # This is a disposable hosted runner, never a user's installed app.
          $installer = (Resolve-Path "build/installer/ShopIt-Setup-${{ needs.version.outputs.name }}.exe").Path
          $target = Join-Path $env:RUNNER_TEMP "ShopIt-icon-verification"
          $arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$target`""
          $result = Start-Process -FilePath $installer -ArgumentList $arguments -Wait -PassThru
          if ($result.ExitCode -ne 0) { throw "Verification install failed" }
          $exe = Join-Path $target "shop_it.exe"
          python tool/check_built_icons.py --windows-exe "$exe"
          if ($LASTEXITCODE -ne 0) { throw "Installer-payload icon failed" }
          python tool/check_built_version.py --windows-exe "$exe" --expected-version "${{ needs.version.outputs.name }}" --expected-build "${{ needs.version.outputs.code }}"
          if ($LASTEXITCODE -ne 0) { throw "Installer-payload version failed" }

"""

MACOS_GATE = """      - name: Set up Python for macOS icon gate
        uses: actions/setup-python@v6
        with:
          python-version: '3.13'

      - name: Verify compiled and packaged macOS icons
        shell: bash
        run: |
          set -euo pipefail
          python -m pip install -r tool/native-requirements.txt
          PAYLOAD="$RUNNER_TEMP/ShopIt-icon-verification"
          mkdir -p "$PAYLOAD"
          ditto -x -k "ShopIt-${{ needs.version.outputs.name }}-macos.zip" "$PAYLOAD"
          for APP in "build/macos/Build/Products/Release/ShopIt.app" "$PAYLOAD/ShopIt.app"; do
            python tool/check_built_icons.py --macos-app "$APP"
            python tool/check_built_version.py --macos-app "$APP" --expected-version "${{ needs.version.outputs.name }}" --expected-build "${{ needs.version.outputs.code }}"
          done

"""

ANDROID_GATE = """      - name: Set up Python for APK icon gate
        uses: actions/setup-python@v6
        with:
          python-version: '3.13'

      - name: Verify packaged Android launcher icons
        shell: bash
        run: |
          set -euo pipefail
          python -m pip install -r tool/icon-requirements.txt
          SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
          test -n "$SDK"
          AAPT="$(find "$SDK/build-tools" -type f -name aapt | sort -V | tail -n 1)"
          test -n "$AAPT"
          python tool/check_android_apk_icons.py --android-apk "ShopIt-${{ needs.version.outputs.name }}.apk" --aapt "$AAPT"

"""


def gate_release_workflow(source):
    if "Verify compiled Windows icon" in source:
        raise ValueError("release icon gates are already present; do not install twice")
    replacements = (
        ("      - name: Analyze and test\n", SOURCE_GATE),
        ("      - name: Build installer\n", WINDOWS_GATE),
        ("      - name: Upload installer\n", WINDOWS_PAYLOAD_GATE),
        ("      - name: Upload Mac app\n", MACOS_GATE),
        ("      - name: Upload APK\n", ANDROID_GATE),
    )
    for marker, insertion in replacements:
        if source.count(marker) != 1:
            raise ValueError(f"expected exactly one workflow step {marker.strip()!r}")
        source = source.replace(marker, insertion + marker, 1)
    return source


def make_patch(source):
    return "".join(difflib.unified_diff(
        source.splitlines(True), gate_release_workflow(source).splitlines(True),
        fromfile="a/.github/workflows/release.yml",
        tofile="b/.github/workflows/release.yml"))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workflow", type=Path, default=Path(".github/workflows/release.yml"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        patch = make_patch(args.workflow.read_text(encoding="utf-8"))
        args.output.write_text(patch, encoding="utf-8")
    except (OSError, ValueError) as error:
        print(f"Cannot generate release gates: {error}")
        return 1
    print(f"Review and apply {args.output}; no workflow or repository was modified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
