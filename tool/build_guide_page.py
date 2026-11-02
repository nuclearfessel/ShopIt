#!/usr/bin/env python3
"""Build docs/guide.html body from docs/usage.md (no CDN, no fetch)."""

from __future__ import annotations

import re
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[1]
USAGE = ROOT / "docs" / "usage.md"
GUIDE = ROOT / "docs" / "guide.html"
START = "<!-- GUIDE_BODY_START -->"
END = "<!-- GUIDE_BODY_END -->"
TOC_START = "<!-- GUIDE_TOC_START -->"
TOC_END = "<!-- GUIDE_TOC_END -->"


def strip_chrome(md: str) -> str:
    md = re.sub(r"^#\s+Using ShopIt\s*\n+", "", md)
    md = re.sub(r'^<p\s+align="center">[\s\S]*?</p>\s*', "", md, count=1, flags=re.I)
    md = re.sub(
        r'^<img\s+src="assets/readme-banner-dark\.svg"[\s\S]*?>\s*',
        "",
        md,
        count=1,
        flags=re.I,
    )
    return md.strip() + "\n"


def slugify(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def polish_html(html: str) -> tuple[str, str]:
    # Icon classes + drop align/style noise on icons.
    def icon_sub(match: re.Match[str]) -> str:
        tag = match.group(0)
        tag = re.sub(r'\s+align="[^"]*"', "", tag)
        tag = re.sub(r'\s+style="[^"]*"', "", tag)
        if 'class="' in tag:
            tag = tag.replace('class="', 'class="guide-icon ', 1)
        else:
            tag = tag.replace("<img ", '<img class="guide-icon" ', 1)
        return tag

    html = re.sub(
        r'<img\b[^>]*src="icons/[^"]+"[^>]*>',
        icon_sub,
        html,
        flags=re.I,
    )

    # Wrap desktop + phone screenshot pair into a shots grid.
    html = re.sub(
        r'<p\s+align="center">\s*<img\s+([^>]*src="screenshots/windows\.png"[^>]*)>\s*</p>\s*'
        r'<p\s+align="center">\s*<img\s+([^>]*src="screenshots/android\.png"[^>]*)>\s*</p>',
        r'<div class="guide-shots">'
        r'<figure class="guide-figure guide-figure-desktop"><img \1></figure>'
        r'<figure class="guide-figure guide-figure-phone"><img \2></figure>'
        r"</div>",
        html,
        flags=re.I,
    )

    # Other centered screenshot paragraphs → figures.
    html = re.sub(
        r'<p\s+align="center">\s*(<img\s+[^>]*src="screenshots/[^"]+"[^>]*>)\s*</p>',
        r'<figure class="guide-figure">\1</figure>',
        html,
        flags=re.I,
    )

    # Diagram SVGs as figures (unwrap accidental <p> wrappers from Markdown).
    html = re.sub(
        r'(?:<p>)?\s*(<img\s+[^>]*src="assets/(?:workflow|features|sharing)-dark\.svg"[^>]*>)\s*(?:</p>)?',
        r'<figure class="guide-figure guide-figure-wide">\1</figure>',
        html,
        flags=re.I,
    )
    html = re.sub(r"<p>\s*(<figure[\s\S]*?</figure>)\s*</p>", r"\1", html, flags=re.I)

    # Section ids + TOC from h2.
    toc_items: list[str] = []

    def heading_sub(match: re.Match[str]) -> str:
        inner = match.group(1)
        sid = slugify(inner)
        toc_items.append(f'<a href="#{sid}">{inner}</a>')
        return f'<h2 id="{sid}">{inner}</h2>'

    html = re.sub(r"<h2>(.*?)</h2>", heading_sub, html, flags=re.I | re.S)

    # Drop inline table header colors; CSS owns them.
    html = re.sub(r'\s+style="background-color:[^"]*"', "", html)
    html = re.sub(r'\s+align="left"', "", html)

    toc = "\n            ".join(toc_items)
    return html, toc


def main() -> None:
    md = strip_chrome(USAGE.read_text(encoding="utf-8"))
    html = markdown.markdown(
        md,
        extensions=["tables", "fenced_code", "sane_lists"],
        output_format="html5",
    )
    body, toc = polish_html(html)

    page = GUIDE.read_text(encoding="utf-8")
    if START not in page or END not in page:
        raise SystemExit(f"{GUIDE} is missing body markers")
    if TOC_START not in page or TOC_END not in page:
        raise SystemExit(f"{GUIDE} is missing TOC markers")

    page = re.sub(
        re.escape(TOC_START) + r"[\s\S]*?" + re.escape(TOC_END),
        TOC_START + "\n            " + toc + "\n            " + TOC_END,
        page,
        count=1,
    )
    page = re.sub(
        re.escape(START) + r"[\s\S]*?" + re.escape(END),
        START + "\n" + body + "\n          " + END,
        page,
        count=1,
    )
    GUIDE.write_text(page, encoding="utf-8", newline="\n")
    print(f"Updated {GUIDE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
