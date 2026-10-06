"""Build an installable addon ZIP using only Python's standard library."""
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "VassilisDungeonPlaner"
TOC = ADDON / "VassilisDungeonPlaner.toc"


def package():
    manifest = TOC.read_text(encoding="utf-8")
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)\s*$", manifest, re.MULTILINE)
    if not match:
        raise ValueError("Missing or invalid addon version in the TOC")
    files = [TOC, ADDON / "README.md", ADDON / "README.en.md", ADDON / "LICENSE"]
    files.extend(ADDON / line.strip() for line in manifest.splitlines() if line.strip() and not line.startswith("#"))
    for source in files:
        if not source.resolve().is_relative_to(ADDON.resolve()) or not source.is_file():
            raise ValueError(f"Invalid or missing addon file: {source.name}")
    output = ROOT / "dist" / f"VassilisDungeonPlaner-{match.group(1)}.zip"
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        for source in files:
            archive.write(source, source.relative_to(ROOT).as_posix())
    with ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP integrity check failed")
    print(f"Created {output.relative_to(ROOT)} ({len(files)} addon files)")
    return output


if __name__ == "__main__":
    package()
