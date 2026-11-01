# App icon packaging checks

Run from the ShopIt repository root:

```sh
python -m pip install -r tool/icon-requirements.txt
python -m unittest discover -s tool -p 'test_validate_app_icons.py' -v
python tool/validate_app_icons.py
```

The `icon-packaging` CI job runs these commands on pushes to `main` and on pull
requests. It checks the **committed files**, without regenerating or repairing
them first, so broken exports cannot be hidden by CI.

Checks cover:

- Windows: exactly seven ICO frames (16, 24, 32, 48, 64, 128, 256), individually
  decoded, with valid nonoverlapping payloads and transparent exterior corners.
- Android: legacy launcher PNGs at mdpi 48, hdpi 72, xhdpi 96, xxhdpi 144, and
  xxxhdpi 192 pixels, with transparent corners.
- iOS/macOS: required catalog slots, local PNG references, pixel dimensions
  calculated from point size and scale (including iPad's 83.5 pt icon), and
  duplicate/missing entries. iOS forbids alpha channels and PNG transparency
  metadata, even if pixels are fully opaque. macOS preserves exterior alpha.
- PNG integrity/decoding, fully flattened exports, and accidentally empty images.

At tiny sizes the approved tile's antialiasing leaves near-transparent corners,
so exterior alpha up to 8/255 is accepted. Opaque content is still required.
This is a packaging check, not a pixel-for-pixel comparison with the brand master.
Adaptive Android launcher layers and native compiled resources are not checked.
That limitation applies to this source-packaging command. For the separate
Windows/macOS built-resource checker and native visual release gate, see
[`NATIVE_RELEASE.md`](NATIVE_RELEASE.md).

After intentionally changing the platform catalog contract, update the independent
expectations and tests in `validate_app_icons.py` / `test_validate_app_icons.py`.
They deliberately do not import the generator's size lists.

The validator exits 1 with file-specific errors on failure; use
`--root /path/to/ShopIt` to run it from another working directory.

## Optional artwork validation

Packaging alone accepts different artwork with correct dimensions and alpha.
Copy `check_icon_artwork.py` and `icon-artwork-manifest.json` beside this checker:

```sh
python tool/check_icon_artwork.py
# Optional: inspect the app generator's CLI first; replace the example as needed.
python tool/check_icon_artwork.py --regenerate python tool/make_icon.py
```

The first command checks committed exports against reviewed decoded pixels tied
to the approved Daily Circle Original Tangerine master. The optional second
command verifies that master, copies the checkout to a temporary directory,
removes only the copy's reviewed exports, runs the trusted generator there, and
checks every regenerated image/frame. It never copies generated files back.
Run the packaging check first; regeneration is not a substitute for validating
committed files. Use relative generator paths; temporary isolation is not a
security sandbox. Symlinked checkouts are rejected for this mode.

Use pinned Pillow 13.0.0. Export tolerance is zero on alpha-premultiplied RGBA
(including alpha); invisible RGB and encoding differences are ignored.
Do not synthesize replacement baselines with a different rasterizer or relax
tolerance after an upgrade. Review renderer/version changes against the approved
master before intentionally accepting new digests. See the handoff `README.md`
for the full invocation, renderer policy, fixture coverage, and installation
instructions.
