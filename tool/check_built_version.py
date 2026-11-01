"""Verify native release version/build metadata independently of mocked About tests."""
import argparse
from pathlib import Path

from check_built_icons import bundle_info


def windows_version(executable):
    import pefile
    pe = pefile.PE(str(executable))
    try:
        strings = {}
        for group in getattr(pe, "FileInfo", []):
            for entry in group:
                for table in getattr(entry, "StringTable", []):
                    strings.update({key.decode("utf-8"): value.decode("utf-8").strip("\0 ")
                                    for key, value in table.entries.items()})
        fixed = getattr(pe, "VS_FIXEDFILEINFO", [])
        if not fixed or "ProductVersion" not in strings:
            raise ValueError("Windows build is missing native version resources")
        build = str(fixed[0].FileVersionLS & 0xFFFF)
        version, separator, embedded_build = strings["ProductVersion"].partition("+")
        if separator and embedded_build != build:
            raise ValueError("Windows string and fixed-resource build numbers disagree")
        return version, build
    finally:
        pe.close()


def verify_version(actual_version, actual_build, expected_version, expected_build):
    if actual_version != expected_version or actual_build != expected_build:
        raise ValueError(f"native version/build is {actual_version!r}+{actual_build!r}, "
                         f"expected {expected_version!r}+{expected_build!r}")
    if not actual_version or not actual_build:
        raise ValueError("native version/build must not be empty")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--windows-exe", type=Path)
    parser.add_argument("--macos-app", type=Path)
    parser.add_argument("--expected-version", required=True)
    parser.add_argument("--expected-build", required=True)
    args = parser.parse_args(argv)
    if not args.windows_exe and not args.macos_app:
        parser.error("supply --windows-exe and/or --macos-app")
    try:
        if args.windows_exe:
            verify_version(*windows_version(args.windows_exe), args.expected_version, args.expected_build)
        if args.macos_app:
            _, info = bundle_info(args.macos_app)
            verify_version(info.get("CFBundleShortVersionString", ""),
                           info.get("CFBundleVersion", ""),
                           args.expected_version, args.expected_build)
    except Exception as error:
        print(f"Native version check failed: {type(error).__name__}: {error}")
        return 1
    print("Native release version/build metadata matches.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
