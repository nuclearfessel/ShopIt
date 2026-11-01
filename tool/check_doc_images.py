#!/usr/bin/env python3
"""Check README and user-guide images without making network requests."""

import argparse
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import warnings
import struct
from xml.parsers import expat

from markdown_it import MarkdownIt
from PIL import Image as PillowImage


DOCUMENTS = ("README.md", "docs/usage.md")
RASTER_SUFFIXES = {".png", ".apng", ".jpg", ".jpeg", ".gif", ".webp"}
VECTOR_SUFFIXES = {".svg"}


@dataclass(frozen=True)
class ImageLimits:
    max_bytes: int = 10 * 1024 * 1024
    max_pixels: int = 25_000_000
    max_frames: int = 200
    max_total_pixels: int = 100_000_000

    def __post_init__(self):
        if min(self.max_bytes, self.max_pixels, self.max_frames, self.max_total_pixels) <= 0:
            raise ValueError("image limits must be positive")


def _gif_complete(data):
    """Walk GIF blocks so a decoder accepting a missing trailer cannot pass."""
    if data[:6] not in (b"GIF87a", b"GIF89a") or len(data) < 13:
        raise OSError("invalid GIF header")
    position = 13 + (3 * (2 ** ((data[10] & 7) + 1)) if data[10] & 128 else 0)

    def subblocks(offset):
        while offset < len(data):
            size = data[offset]
            offset += 1
            if not size:
                return offset
            offset += size
            if offset > len(data):
                break
        raise OSError("truncated GIF data subblock")

    while position < len(data):
        marker = data[position]
        position += 1
        if marker == 0x3B:
            return
        if marker == 0x21:
            if position >= len(data):
                raise OSError("truncated GIF extension")
            position = subblocks(position + 1)
        elif marker == 0x2C:
            if position + 9 > len(data):
                raise OSError("truncated GIF image descriptor")
            packed = data[position + 8]
            position += 9 + (3 * 2 ** ((packed & 7) + 1) if packed & 128 else 0)
            if position >= len(data):
                raise OSError("truncated GIF color table/image data")
            position = subblocks(position + 1)  # skip the LZW code size
        else:
            raise OSError(f"invalid GIF block marker {marker:#x}")
    raise OSError("GIF trailer is missing")


def _webp_complete(data):
    """Validate RIFF bounds, including the chunks inside animation frames."""
    if len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise OSError("invalid WebP RIFF header")
    end = struct.unpack_from("<I", data, 4)[0] + 8
    if end < 12 or end > len(data):
        raise OSError("truncated WebP RIFF container")
    def chunks(position, boundary, frames=False):
        while position < boundary:
            if position + 8 > boundary:
                raise OSError("truncated WebP chunk header")
            kind = data[position:position + 4]
            size = struct.unpack_from("<I", data, position + 4)[0]
            payload = position + 8
            position = payload + size + (size & 1)
            if position > boundary:
                raise OSError("truncated WebP chunk payload")
            if frames and kind == b"ANMF":
                if size < 16:
                    raise OSError("truncated WebP animation frame header")
                chunks(payload + 16, payload + size)

    chunks(12, end, frames=True)


def _pixel_budget(image, limits, total=0):
    pixels = image.width * image.height
    if pixels > limits.max_pixels:
        raise ValueError(f"image exceeds pixel limit {limits.max_pixels:,}")
    if total + pixels > limits.max_total_pixels:
        raise ValueError(f"animation exceeds total pixel limit {limits.max_total_pixels:,}")
    return total + pixels


def image_integrity_error(asset, limits=ImageLimits()):
    """Check structure and pixel data; verify() alone does not decode JPEGs."""
    try:
        size = asset.stat().st_size
        if size > limits.max_bytes:
            raise ValueError(f"image exceeds byte limit {limits.max_bytes:,} ({size:,} bytes)")
        with warnings.catch_warnings():
            warnings.simplefilter("error", PillowImage.DecompressionBombWarning)
            formats = ("PNG", "JPEG", "GIF", "WEBP")
            with PillowImage.open(asset, formats=formats) as image:
                _pixel_budget(image, limits)
                if image.format == "GIF":
                    _gif_complete(asset.read_bytes())
                if image.format == "WEBP":
                    _webp_complete(asset.read_bytes())
                image.verify()
                if image.format == "JPEG":
                    # Some libjpeg builds decode a missing EOI successfully.
                    # Look after the last scan header, not in EXIF thumbnails;
                    # allow legitimate trailing bytes after the EOI marker.
                    data = asset.read_bytes()
                    if data.rfind(b"\xff\xd9") < data.rfind(b"\xff\xda"):
                        raise OSError("JPEG end-of-image marker is missing")
            # verify() invalidates the image, so reopen before decoding pixels.
            with PillowImage.open(asset, formats=formats) as image:
                total = 0
                for frame in range(limits.max_frames + 1):
                    try:
                        image.seek(frame)
                    except EOFError:
                        break
                    if frame == limits.max_frames:
                        raise ValueError(f"animation exceeds frame limit {limits.max_frames}")
                    total = _pixel_budget(image, limits, total)
                    image.load()
    except (OSError, EOFError, SyntaxError, ValueError, PillowImage.DecompressionBombError,
            PillowImage.DecompressionBombWarning) as error:
        return f"{type(error).__name__}: {error}"
    return None


def svg_integrity_error(asset, limits=ImageLimits()):
    """Validate SVG XML without resolving external entities or reading references."""
    try:
        size = asset.stat().st_size
        if size > limits.max_bytes:
            raise ValueError(f"image exceeds byte limit {limits.max_bytes:,} ({size:,} bytes)")

        root = None
        parser = expat.ParserCreate(namespace_separator="}")
        parser.SetParamEntityParsing(expat.XML_PARAM_ENTITY_PARSING_NEVER)

        def reject_entities(*_):
            raise ValueError("SVG document types and entities are not allowed")

        def capture_root(name, _attributes):
            nonlocal root
            if root is None:
                root = name

        parser.StartElementHandler = capture_root
        parser.StartDoctypeDeclHandler = reject_entities
        parser.EntityDeclHandler = reject_entities
        parser.ExternalEntityRefHandler = reject_entities
        parser.Parse(asset.read_bytes(), True)

        if not root:
            raise ValueError("SVG document has no root element")
        namespace, separator, local_name = root.rpartition("}")
        if separator and namespace != "http://www.w3.org/2000/svg":
            raise ValueError(f"unexpected SVG namespace {namespace!r}")
        if (local_name if separator else root) != "svg":
            raise ValueError("document root is not <svg>")
    except (OSError, ValueError, expat.ExpatError) as error:
        return f"{type(error).__name__}: {error}"
    return None


@dataclass
class Image:
    source: str
    alt: str | None
    decorative: bool = False


class HTMLImages(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag != "img":
            return
        attrs = dict(attrs)
        decorative = (
            (attrs.get("role") or "").lower() in ("presentation", "none")
            or (attrs.get("aria-hidden") or "").lower() == "true"
        )
        self.images.append(
            Image(attrs.get("src") or "", attrs.get("alt"), decorative)
        )

    handle_startendtag = handle_starttag


def images_in(markdown):
    """Parse rendered Markdown, not code examples, escapes, or HTML comments."""
    rendered = MarkdownIt("commonmark", {"html": True}).render(markdown)
    parser = HTMLImages()
    parser.feed(rendered)
    parser.close()
    return parser.images


def check_document(root, relative, limits=ImageLimits()):
    root = root.resolve()
    document = root / relative
    try:
        markdown = document.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return 0, [f"{relative}: cannot read document: {error}"]

    images = images_in(markdown)
    errors = []
    for index, image in enumerate(images, 1):
        label = f"{relative}: image {index} ({image.source or 'no src'})"
        if image.alt is None:
            errors.append(f"{label}: missing alt attribute")
        elif not image.alt.strip() and not image.decorative:
            errors.append(
                f'{label}: empty alt text; describe the image or explicitly '
                'mark a decorative HTML image role="presentation" with alt=""'
            )

        source = image.source.strip()
        if not source:
            errors.append(f"{label}: missing image source")
            continue
        try:
            url = urlsplit(source)
        except ValueError:
            errors.append(f"{label}: invalid image URL")
            continue
        # Remote images are not fetched, but still need alt text.
        if url.scheme in ("http", "https") or source.startswith("//"):
            continue
        if url.scheme:
            errors.append(f"{label}: unsupported image URL scheme {url.scheme!r}")
            continue
        path = unquote(url.path)
        if not path:
            errors.append(f"{label}: missing image path")
            continue
        # GitHub's /path form starts at the repository root.
        asset = (
            root / path.lstrip("/") if path.startswith("/")
            else document.parent / path
        ).resolve()
        if not asset.is_relative_to(root):
            errors.append(f"{label}: image path escapes the repository")
        elif not asset.is_file():
            errors.append(f"{label}: missing image asset: {asset.relative_to(root).as_posix()}")
        elif asset.suffix.lower() in RASTER_SUFFIXES:
            problem = image_integrity_error(asset, limits)
            if problem:
                errors.append(
                    f"{label}: damaged or unreadable image asset: "
                    f"{asset.relative_to(root).as_posix()}: {problem}"
                )
        elif asset.suffix.lower() in VECTOR_SUFFIXES:
            problem = svg_integrity_error(asset, limits)
            if problem:
                errors.append(
                    f"{label}: damaged or unreadable image asset: "
                    f"{asset.relative_to(root).as_posix()}: {problem}"
                )
    return len(images), errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[1],
        help="Repository root (defaults to the parent of tool/)",
    )
    for flag, default in (
        ("max-image-bytes", ImageLimits().max_bytes),
        ("max-image-pixels", ImageLimits().max_pixels),
        ("max-image-frames", ImageLimits().max_frames),
        ("max-total-pixels", ImageLimits().max_total_pixels),
    ):
        parser.add_argument(f"--{flag}", type=int, default=default)
    args = parser.parse_args(argv)
    try:
        limits = ImageLimits(args.max_image_bytes, args.max_image_pixels,
                             args.max_image_frames, args.max_total_pixels)
    except ValueError as error:
        parser.error(str(error))
    root = args.root.resolve()
    errors = []
    count = 0
    for document in DOCUMENTS:
        document_count, document_errors = check_document(root, document, limits)
        count += document_count
        errors.extend(document_errors)
    if errors:
        for error in errors:
            print(error)
        print(f"Documentation image check failed: {len(errors)} error(s).")
        return 1
    print(f"Checked {count} images in {', '.join(DOCUMENTS)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
