"""Check local walkthrough links and Markdown anchors without network access."""
import argparse
from html.parser import HTMLParser
from pathlib import Path
import unicodedata
from urllib.parse import unquote, urlsplit

from markdown_it import MarkdownIt

DEFAULT_DOCUMENTS = ("README.md", "docs/usage.md")
MAX_DOCUMENT_BYTES = 2 * 1024 * 1024


class HTMLReferences(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self.anchors, self.text = [], set(), []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "img":
            self.text.append(attrs.get("alt") or "")
        if attrs.get("id"):
            self.anchors.add(attrs["id"])
        if tag == "a":
            if attrs.get("name"):
                self.anchors.add(attrs["name"])
            if "href" in attrs:
                self.links.append(attrs["href"] or "")

    handle_startendtag = handle_starttag

    def handle_data(self, data):
        self.text.append(data)


def heading_slug(text):
    """Match GitHub's Unicode-aware heading IDs, including repeated spaces."""
    kept = []
    for character in text.lower():
        category = unicodedata.category(character)
        if character == " ":
            kept.append("-")
        elif category[0] in ("L", "M", "N") or character in ("_", "-"):
            kept.append(character)
    return "".join(kept)


def references(markdown):
    parser = MarkdownIt("commonmark", {"html": True})
    tokens = parser.parse(markdown)
    html = HTMLReferences()
    html.feed(parser.renderer.render(tokens, parser.options, {}))
    html.close()
    anchors = set(html.anchors)
    used = set()
    for index, token in enumerate(tokens):
        if token.type != "heading_open":
            continue
        text = HTMLReferences()
        text.feed(parser.renderInline(tokens[index + 1].content))
        slug = heading_slug("".join(text.text))
        candidate, suffix = slug, 0
        while candidate in used:
            suffix += 1
            candidate = f"{slug}-{suffix}"
        used.add(candidate)
        anchors.add(candidate)
    return html.links, anchors


def directory_readme(directory):
    """Return a Markdown README rendered for a repository directory, if present."""
    candidates = [
        item for item in directory.iterdir()
        if item.is_file() and item.name.casefold() in ("readme.md", "readme.markdown")
    ]
    return min(candidates, key=lambda item: (
        item.name != "README.md", item.name.casefold(), item.name
    )).resolve() if candidates else None


def check_links(root, documents=DEFAULT_DOCUMENTS, max_documents=200):
    root = Path(root).resolve()
    cache, errors, queue, visited = {}, [], list(documents), set()
    count = 0

    def read(path):
        if path not in cache:
            if path.stat().st_size > MAX_DOCUMENT_BYTES:
                raise ValueError(f"Markdown exceeds {MAX_DOCUMENT_BYTES:,}-byte limit")
            cache[path] = references(path.read_text(encoding="utf-8"))
        return cache[path]

    while queue:
        source = queue.pop(0)
        try:
            document = (root / source).resolve()
        except (OSError, RuntimeError, ValueError) as error:
            errors.append(f"{source}: cannot resolve document: {error}")
            continue
        if document in visited:
            continue
        if len(visited) >= max_documents:
            errors.append(f"walkthrough exceeds {max_documents} linked-document limit")
            break
        visited.add(document)
        try:
            if not document.is_relative_to(root):
                raise ValueError("document escapes the repository")
            links, _ = read(document)
        except (OSError, UnicodeError, ValueError) as error:
            errors.append(f"{document.name}: cannot read document: {error}")
            continue
        for index, link in enumerate(links, 1):
            count += 1
            label = f"{document.relative_to(root).as_posix()}: link {index} ({link or 'empty href'})"
            try:
                if not link.strip():
                    raise ValueError("empty link destination")
                url = urlsplit(link)
                if url.scheme in ("http", "https", "mailto", "tel") or link.startswith("//"):
                    continue
                if url.scheme:
                    raise ValueError(f"unsupported link scheme {url.scheme!r}")
                path = unquote(url.path)
                target = (root / path.lstrip("/") if path.startswith("/")
                          else document.parent / path).resolve() if path else document
                if not target.is_relative_to(root):
                    raise ValueError("link escapes the repository")
                if not target.exists():
                    raise ValueError(f"missing target: {target.relative_to(root).as_posix()}")
                if target.is_dir():
                    readme = directory_readme(target)
                    if readme is not None:
                        if not readme.is_relative_to(root):
                            raise ValueError("directory README escapes the repository")
                        _, anchors = read(readme)
                        if url.fragment and unquote(url.fragment) not in anchors:
                            raise ValueError(
                                f"missing anchor #{unquote(url.fragment)} "
                                f"in {readme.relative_to(root).as_posix()}"
                            )
                        queue.append(readme.relative_to(root).as_posix())
                    elif url.fragment:
                        raise ValueError(
                            f"directory has no Markdown README for anchor "
                            f"#{unquote(url.fragment)}"
                        )
                elif target.suffix.lower() in (".md", ".markdown") and target.is_file():
                    _, anchors = read(target)
                    if url.fragment and unquote(url.fragment) not in anchors:
                        raise ValueError(f"missing anchor #{unquote(url.fragment)} in {target.relative_to(root).as_posix()}")
                    queue.append(target.relative_to(root).as_posix())
            except (OSError, UnicodeError, ValueError, RuntimeError) as error:
                errors.append(f"{label}: {error}")
    return count, errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--max-documents", type=int, default=200)
    args = parser.parse_args(argv)
    if args.max_documents <= 0:
        parser.error("--max-documents must be positive")
    count, errors = check_links(args.root, max_documents=args.max_documents)
    for error in errors:
        print(error)
    print(f"Checked {count} documentation links: {len(errors)} error(s).")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
