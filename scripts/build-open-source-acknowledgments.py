#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata as metadata
import os
from pathlib import Path
import re
import subprocess
import textwrap
import unicodedata

LICENSE_NAME = re.compile(r"^(license|licence|copying|notice|copyright)([._-].*)?$", re.IGNORECASE)


def command(*args: str) -> str:
    try:
        result = subprocess.run(
            args,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    except OSError:
        return "not installed"
    value = result.stdout.strip()
    return value or "not installed"


def environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    return value or "not installed in this profile"


def os_pretty_name() -> str:
    path = Path("/etc/os-release")
    if not path.is_file():
        return "unknown"
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("PRETTY_NAME="):
            return line.split("=", 1)[1].strip().strip('"')
    return "unknown"


def package_version(name: str) -> str:
    return command("dpkg-query", "-W", "-f=\${Version}", name)


def template_values(profile: str) -> dict[str, str]:
    return {
        "SCAD_TOOLCHAIN_VERSION": environment("SCAD_TOOLCHAIN_VERSION"),
        "SCAD_TOOLCHAIN_PROFILE": profile,
        "OS_PRETTY_NAME": os_pretty_name(),
        "OPENSCAD_PACKAGE_VERSION": package_version("openscad-nightly"),
        "PYTHONSCAD_VERSION": environment("PYTHONSCAD_VERSION"),
        "BOSL2_VERSION": environment("BOSL2_VERSION"),
        "OPENSCAD_NEW_DIMENSIONS_COMMIT": environment("OPENSCAD_NEW_DIMENSIONS_COMMIT"),
        "PYBOSL2_VERSION": environment("PYBOSL2_VERSION"),
        "SHAPELY_VERSION": environment("SHAPELY_VERSION"),
        "OPENSCAD_DOCSGEN_VERSION": environment("OPENSCAD_DOCSGEN_VERSION"),
        "PILLOW_VERSION": environment("PILLOW_VERSION"),
        "SCONS_VERSION": environment("SCONS_VERSION"),
    }


def apply_tokens(text: str, values: dict[str, str]) -> str:
    for key, value in values.items():
        text = text.replace(f"@{key}@", value)
    unresolved = sorted(set(re.findall(r"@[A-Z0-9_]+@", text)))
    if unresolved:
        raise RuntimeError("unresolved acknowledgment tokens: " + ", ".join(unresolved))
    return text


def matching_files(root: Path) -> list[Path]:
    if not root.is_dir():
        return []
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file() and LICENSE_NAME.match(path.name)
    )


def distribution_license_files(name: str) -> list[Path]:
    try:
        dist = metadata.distribution(name)
    except metadata.PackageNotFoundError:
        return []
    found: list[Path] = []
    for item in dist.files or []:
        if not LICENSE_NAME.match(Path(str(item)).name):
            continue
        path = Path(dist.locate_file(item))
        if path.is_file():
            found.append(path)
    return sorted(set(found), key=str)


def first_existing_globs(patterns: list[str]) -> list[Path]:
    found: list[Path] = []
    for pattern in patterns:
        found.extend(path for path in Path("/").glob(pattern.lstrip("/")) if path.is_file())
    return sorted(set(found), key=str)


def direct_license_groups(profile: str) -> list[tuple[str, list[Path]]]:
    groups: list[tuple[str, list[Path]]] = [
        (
            "OpenSCAD",
            first_existing_globs([
                "/usr/share/doc/openscad*/copyright",
                "/usr/share/common-licenses/GPL-2",
            ]),
        ),
        ("BOSL2", matching_files(Path("/opt/openscad-libraries/BOSL2"))),
        (
            "openscad-new-dimensions",
            matching_files(Path("/opt/openscad-libraries/openscad-new-dimensions")),
        ),
        ("openscad_docsgen", distribution_license_files("openscad_docsgen")),
        ("Pillow", distribution_license_files("Pillow")),
        ("SCons", distribution_license_files("SCons")),
    ]
    if profile == "full":
        upstream_copying = Path("/opt/pythonscad/COPYING.upstream")
        groups.extend([
            ("PythonSCAD", [upstream_copying] if upstream_copying.is_file() else []),
            ("pybosl2", distribution_license_files("pybosl2")),
            ("Shapely", distribution_license_files("shapely")),
        ])
    return groups


def write_package_inventories(output_dir: Path) -> None:
    debian = command("dpkg-query", "-W", "-f=\${Package}\\t\${Version}\\n")
    (output_dir / "DEBIAN_PACKAGES.txt").write_text(
        debian.rstrip() + "\n", encoding="utf-8"
    )

    distributions: set[tuple[str, str]] = set()
    for dist in metadata.distributions():
        name = (dist.metadata.get("Name") or "").strip()
        if not name:
            continue
        distributions.add((name, dist.version))
    python_lines = [
        f"{name}\t{version}"
        for name, version in sorted(distributions, key=lambda item: item[0].lower())
    ]
    (output_dir / "PYTHON_DISTRIBUTIONS.txt").write_text(
        "\n".join(python_lines) + ("\n" if python_lines else ""),
        encoding="utf-8",
    )


def assemble_text(source: Path, profile: str, output_dir: Path) -> str:
    base = apply_tokens(
        source.read_text(encoding="utf-8"),
        template_values(profile),
    ).rstrip()

    groups = direct_license_groups(profile)
    missing = [name for name, paths in groups if not paths]
    if missing:
        raise RuntimeError(
            "missing license/copyright material for direct component(s): "
            + ", ".join(missing)
        )

    index_lines = [
        "DIRECT LICENSE FILE INDEX",
        "-------------------------",
        "",
    ]
    for name, paths in groups:
        index_lines.append(name)
        for path in paths:
            index_lines.append(f"  {path}")
        index_lines.append("")
    (output_dir / "DIRECT_LICENSE_FILES.txt").write_text(
        "\n".join(index_lines).rstrip() + "\n", encoding="utf-8"
    )

    sections = [
        base,
        "",
        "\n".join(index_lines).rstrip(),
        "",
        "DIRECT COMPONENT LICENSE AND COPYRIGHT TEXTS",
        "--------------------------------------------",
        "",
        "The following text is copied verbatim from license/copyright files present",
        "in the built runtime. Identical files are reproduced only once.",
        "",
    ]

    seen: dict[str, tuple[str, str]] = {}
    order: list[str] = []
    aliases: dict[str, list[str]] = {}
    for name, paths in groups:
        for path in paths:
            raw = path.read_bytes()
            if not raw.strip():
                continue
            digest = hashlib.sha256(raw).hexdigest()
            aliases.setdefault(digest, []).append(f"{name}: {path}")
            if digest not in seen:
                seen[digest] = (
                    str(path),
                    raw.decode("utf-8", errors="replace")
                    .replace("\r\n", "\n")
                    .replace("\r", "\n"),
                )
                order.append(digest)

    for number, digest in enumerate(order, start=1):
        _origin, body = seen[digest]
        sections.append(f"[{number}] " + " | ".join(aliases[digest]))
        sections.append("-" * 76)
        sections.append(body.rstrip())
        sections.append("")

    return "\n".join(sections).rstrip() + "\n"


def pdf_text(value: str) -> bytes:
    safe = unicodedata.normalize("NFKC", value)
    safe = safe.encode("cp1252", errors="replace").decode("cp1252")
    safe = safe.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
    return safe.encode("cp1252", errors="replace")


def wrapped_lines(text: str, width: int = 94) -> list[str]:
    lines: list[str] = []
    for raw in text.splitlines():
        if not raw:
            lines.append("")
            continue
        expanded = raw.expandtabs(4)
        indent = len(expanded) - len(expanded.lstrip(" "))
        wrapped = textwrap.wrap(
            expanded,
            width=width,
            replace_whitespace=False,
            drop_whitespace=False,
            break_long_words=True,
            break_on_hyphens=False,
            subsequent_indent=" " * min(indent, 20),
        )
        lines.extend(part.rstrip() for part in (wrapped or [""]))
    return lines


def write_pdf(text: str, output: Path) -> None:
    per_page = 72
    lines = wrapped_lines(text)
    pages = [lines[i:i + per_page] for i in range(0, len(lines), per_page)] or [[]]

    objects: list[bytes] = []

    def add(data: bytes) -> int:
        objects.append(data)
        return len(objects)

    catalog_id = add(b"")
    pages_id = add(b"")
    font_id = add(
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>"
    )
    page_ids: list[int] = []

    for page_number, page in enumerate(pages, start=1):
        stream = bytearray(b"BT\n/F1 8 Tf\n10 TL\n42 800 Td\n")
        for line in page:
            stream.extend(b"(" + pdf_text(line) + b") Tj\nT*\n")
        stream.extend(b"ET\n")
        footer = f"Page {page_number} of {len(pages)}"
        stream.extend(
            b"BT\n/F1 8 Tf\n260 24 Td\n("
            + pdf_text(footer)
            + b") Tj\nET\n"
        )
        content_id = add(
            b"<< /Length %d >>\nstream\n" % len(stream)
            + bytes(stream)
            + b"endstream"
        )
        page_id = add(
            (
                f"<< /Type /Page /Parent {pages_id} 0 R "
                f"/MediaBox [0 0 595 842] "
                f"/Resources << /Font << /F1 {font_id} 0 R >> >> "
                f"/Contents {content_id} 0 R >>"
            ).encode("ascii")
        )
        page_ids.append(page_id)

    objects[catalog_id - 1] = (
        f"<< /Type /Catalog /Pages {pages_id} 0 R >>".encode("ascii")
    )
    kids = " ".join(f"{page_id} 0 R" for page_id in page_ids)
    objects[pages_id - 1] = (
        f"<< /Type /Pages /Kids [{kids}] /Count {len(page_ids)} >>".encode("ascii")
    )

    payload = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for object_id, data in enumerate(objects, start=1):
        offsets.append(len(payload))
        payload.extend(f"{object_id} 0 obj\n".encode("ascii"))
        payload.extend(data)
        payload.extend(b"\nendobj\n")

    xref_offset = len(payload)
    payload.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    payload.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        payload.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    payload.extend(
        (
            f"trailer\n<< /Size {len(objects) + 1} /Root {catalog_id} 0 R >>\n"
            f"startxref\n{xref_offset}\n%%EOF\n"
        ).encode("ascii")
    )
    output.write_bytes(payload)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--profile", choices=("openscad", "full"), required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_package_inventories(args.output_dir)
    assembled = assemble_text(args.input, args.profile, args.output_dir)

    txt = args.output_dir / "OPEN_SOURCE_ACKNOWLEDGMENTS.txt"
    pdf = args.output_dir / "OPEN_SOURCE_ACKNOWLEDGMENTS.pdf"
    txt.write_text(assembled, encoding="utf-8")
    write_pdf(assembled, pdf)


if __name__ == "__main__":
    main()
