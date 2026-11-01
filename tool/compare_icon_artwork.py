"""Create a reviewable before/after/pixel-difference report without changing icons."""
import argparse
import base64
from html import escape
from io import BytesIO
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageDraw
from check_icon_artwork import DEFAULT_MANIFEST, pixel_digest, visible_rgba


def safe_path(root, name):
    relative = Path(name)
    if relative.is_absolute() or ".." in relative.parts or "\\" in name:
        raise ValueError(f"unsafe icon path: {name}")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"icon path escapes checkout: {name}")
    return path


def decode(data, frame=None):
    if len(data) > 20 * 1024 * 1024:
        raise ValueError("icon exceeds 20 MiB report limit")
    with Image.open(BytesIO(data)) as source:
        if frame is not None:
            image = source.ico.getimage((frame, frame))
        else:
            image = source
        if max(image.size) > 2048:
            raise ValueError("icon exceeds 2048px report limit")
        image.load()
        return image.convert("RGBA")


def panel(image, label):
    result = Image.new("RGB", (256, 288), "#e9ecef")
    drawing = ImageDraw.Draw(result)
    drawing.text((10, 8), label, fill="#141618")
    if image is None:
        drawing.text((12, 135), "Missing or unreadable", fill="#b12f28")
        return result
    for y in range(32, 288, 16):
        for x in range(0, 256, 16):
            if (x // 16 + y // 16) % 2:
                drawing.rectangle((x, y, x + 15, y + 15), fill="#c5cad2")
    preview = image.copy()
    preview.thumbnail((240, 240), Image.Resampling.NEAREST)
    if max(preview.size) < 240:
        scale = max(1, 240 // max(preview.size))
        preview = preview.resize((preview.width * scale, preview.height * scale),
                                 Image.Resampling.NEAREST)
    result.paste(preview, ((256 - preview.width) // 2,
                          32 + (256 - preview.height) // 2), preview)
    return result


def comparison(before, after):
    difference = None
    if before is not None and after is not None:
        size = (max(before.width, after.width), max(before.height, after.height))
        left, right = Image.new("RGBA", size), Image.new("RGBA", size)
        left.paste(visible_rgba(before), (0, 0))
        right.paste(visible_rgba(after), (0, 0))
        channels = ImageChops.difference(left, right).split()
        mask = channels[0]
        for channel in channels[1:]:
            mask = ImageChops.lighter(mask, channel)
        difference = Image.merge("RGBA", (
            mask, Image.new("L", size), mask, Image.new("L", size, 255)))
    output = Image.new("RGB", (768, 288))
    for column, (image, label) in enumerate((
        (before, "Before"), (after, "After"), (difference, "Visible pixel difference")
    )):
        output.paste(panel(image, label), (column * 256, 0))
    return output


def create_report(root, output, manifest_path=DEFAULT_MANIFEST, *,
                  before_root=None, before_ref=None):
    root, output = Path(root).resolve(), Path(output)
    manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    keys = sorted(set(manifest["exports"]) | {manifest["source"]})
    if len(keys) > 256:
        raise ValueError("report exceeds 256 icon entries")
    if before_root is None:
        result = subprocess.run(
            ["git", "rev-parse", "--verify", f"{before_ref}^{{commit}}"],
            cwd=root, capture_output=True, text=True, check=True)
        commit = result.stdout.strip()
    else:
        before_root = Path(before_root).resolve()
        commit = None
    output.mkdir(parents=True, exist_ok=True)
    records, cards = [], []
    for number, key in enumerate(keys):
        filename, separator, frame_text = key.partition("#")
        safe_path(root, filename)
        frame = int(frame_text) if separator else None
        if frame is not None and not 1 <= frame <= 2048:
            raise ValueError(f"invalid ICO frame: {key}")
        images, record = [], {"path": key}
        for side in ("before", "after"):
            try:
                if side == "before" and before_root is None:
                    data = subprocess.run(
                        ["git", "show", f"{commit}:{filename}"], cwd=root,
                        capture_output=True, check=True).stdout
                else:
                    directory = before_root if side == "before" else root
                    data = safe_path(directory, filename).read_bytes()
                image = decode(data, frame)
                record[side] = {"size": list(image.size), "sha256": pixel_digest(image)}
            except (OSError, ValueError, AttributeError, subprocess.CalledProcessError) as error:
                image = None
                record[side] = {"error": str(error)}
            images.append(image)
        record["changed"] = record["before"] != record["after"]
        if record["changed"]:
            image = comparison(*images)
            name = f"comparison-{number:03d}.png"
            image.save(output / name)
            encoded = BytesIO()
            image.save(encoded, format="PNG")
            uri = base64.b64encode(encoded.getvalue()).decode("ascii")
            cards.append(
                f"<section><h2>{escape(key)}</h2>"
                f'<img alt="Before, after, and visible pixel difference for {escape(key)}" '
                f'src="data:image/png;base64,{uri}">'
                f"<pre>{escape(json.dumps(record, indent=2))}</pre></section>")
        records.append(record)
    changed = sum(record["changed"] for record in records)
    report = {"baseline_commit": commit, "changed": changed, "icons": records}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    html = (
        '<!doctype html><html lang="en"><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        "<title>ShopIt icon comparison</title><style>"
        "body{font:16px system-ui;background:#f7f8f9;color:#141618;margin:32px auto;"
        "max-width:1100px;padding:0 20px}section{margin:32px 0;padding:20px;"
        "background:#eceef1;border:1px solid #bcc0c7;border-radius:12px}"
        "h2{font-size:16px;overflow-wrap:anywhere}img{max-width:100%;height:auto}"
        "pre{overflow:auto;font-size:12px}</style><h1>ShopIt icon comparison</h1>"
        f"<p>{changed} changed entries out of {len(records)}. "
        "Magenta shows visible-channel differences; transparent RGB is ignored. "
        "This report never approves a baseline change or replaces validation.</p>"
        + ("".join(cards) if cards else "<p>No visible icon changes.</p>")
        + "</html>")
    (output / "index.html").write_text(html, encoding="utf-8")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    baseline = parser.add_mutually_exclusive_group(required=True)
    baseline.add_argument("--before-root", type=Path)
    baseline.add_argument("--before-ref")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        report = create_report(args.root, args.output_dir, args.manifest,
                               before_root=args.before_root, before_ref=args.before_ref)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"Icon comparison failed: {error}")
        return 1
    print(f"Icon comparison: {report['changed']} changed entries; {args.output_dir / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
