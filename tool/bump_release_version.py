"""Bump ShopIt pubspec version for the next GitHub Release.

Patch runs 0..9, then minor goes up and patch returns to 0.
Minor runs 0..9, then major goes up and minor/patch return to 0.
9.9.9 becomes 10.0.0. The +build number increases by one every release.

Run from the repo root:
  python tool/bump_release_version.py           # print next version
  python tool/bump_release_version.py --write   # rewrite pubspec.yaml
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

VERSION_RE = re.compile(
    r"^(version:\s*)(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$",
    re.MULTILINE,
)


def bump_semver(major: int, minor: int, patch: int) -> tuple[int, int, int]:
    patch += 1
    if patch > 9:
        patch = 0
        minor += 1
        if minor > 9:
            minor = 0
            major += 1
    return major, minor, patch


def bump_pubspec_text(text: str) -> tuple[str, str, int]:
    match = VERSION_RE.search(text)
    if match is None:
        raise ValueError("pubspec.yaml has no version: major.minor.patch line")
    major = int(match.group(2))
    minor = int(match.group(3))
    patch = int(match.group(4))
    code = int(match.group(5) or "0") + 1
    major, minor, patch = bump_semver(major, minor, patch)
    name = f"{major}.{minor}.{patch}"
    replacement = f"{match.group(1)}{name}+{code}"
    return VERSION_RE.sub(replacement, text, count=1), name, code


def bump_file(path: Path, *, write: bool) -> tuple[str, int]:
    original = path.read_text(encoding="utf-8")
    updated, name, code = bump_pubspec_text(original)
    if write:
        path.write_text(updated, encoding="utf-8", newline="\n")
    return name, code


def write_github_output(name: str, code: int) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with open(output, "a", encoding="utf-8") as handle:
        handle.write(f"name={name}\n")
        handle.write(f"code={code}\n")
        handle.write(f"tag=v{name}\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root containing pubspec.yaml",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="rewrite pubspec.yaml with the bumped version",
    )
    args = parser.parse_args(argv)
    pubspec = args.root / "pubspec.yaml"
    name, code = bump_file(pubspec, write=args.write)
    write_github_output(name, code)
    print(f"{name}+{code}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # noqa: BLE001 - CLI boundary
        print(f"bump_release_version: {error}", file=sys.stderr)
        raise SystemExit(1) from error
