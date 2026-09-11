# Repository agent guidance

Persistent guidance for automated coding agents working in
`docker.scad-toolchain`.

## Purpose

This repository builds and publishes the shared CAD runtime used by the
brainboxemb SCAD ecosystem.

The image is a toolchain, not a project-specific build system. It provides
stable commands, libraries and runtime capabilities. Project build policy belongs
in `tool.scad-project` and consumer repositories.

## Sources of truth

Do not duplicate changing dependency versions in this file.

Use:

```text
versions.env                         toolchain and dependency pins
Dockerfile / scripts                 implementation
CHANGELOG.md                         released history
published image tag                  immutable runtime release
scad-toolchain-info                  runtime diagnostic evidence
```

Released image tags are immutable. Never rebuild or overwrite an existing
release tag with changed contents.

## Public runtime interface

Consumers should depend on stable public commands, not internal image paths:

```text
openscad
pythonscad
python3
git
scad-toolchain-info
openscad-docsgen
openscad-mdimggen
scad-image-watermark
```

When a new capability is intended for consumers, expose a stable interface and
add real external consumer coverage in `docker.scad-toolchain.test`.

## Library/runtime paths

OpenSCAD libraries are exposed through `OPENSCADPATH`. BOSL2 also has an
explicit `BOSL2_ROOT` because PythonSCAD `osuse()`/`osinclude()` do not use
OpenSCAD's library search path in the same way.

Shared Python packages are installed under `/opt/python-libs`. System Python can
use the configured `PYTHONPATH`; PythonSCAD's embedded Python may need explicit
`sys.path` setup in consumers.

Treat BOSL2 and pybosl2 as distinct capabilities. pybosl2 is a separate Python
port/package, not a wrapper around the installed BOSL2 tree.

Use BOSL2 `std.scad` as the library entrypoint. Do not use `shapes3d.scad` as a
standalone entrypoint.

## Release discipline

A toolchain release is not accepted merely because an image tag exists.

Required sequence:

1. current `main` publishes/tests `:edge`;
2. external consumer suite passes against `:edge`;
3. create the immutable toolchain tag through the permanent release workflow;
4. build/publish/test that exact immutable image;
5. external consumer suite passes against the exact immutable image;
6. create the matching immutable test-suite tag and permanent evidence;
7. only then advance downstream consumers.

Use `.github/workflows/release.yml`. Do not create one-shot release workflows.
The release workflow creates the immutable ref; the normal build workflow remains
authoritative for building/publishing/testing the image.

## External consumer validation

Responsibilities are intentionally split:

```text
docker.scad-toolchain
    build runtime image
    internal smoke tests

docker.scad-toolchain.test
    consume published image
    verify public interface
    publish verification evidence
```

Internal tests should stay small and prove packaging/runtime basics. Broader
interoperability and consumer behavior belong in the external test repository.

A package being installed is not sufficient proof. Test actual imports, commands
and representative geometry/output paths.

## PythonSCAD compatibility conclusions

Keep PythonSCAD available as a toolchain capability, but do not weaken reusable
OpenSCAD object-oriented APIs to accommodate current interoperability limits.

Known compatibility probes in the external suite include:

- PythonSCAD consuming BOSL2 SCAD through `osuse()`;
- PythonSCAD crossing an OpenSCAD `object()` API boundary.

Do not hide expected incompatibilities with test-only shims. Unexpected success
means the compatibility conclusion should be reviewed.

Never name a consumer script after an imported package such as `pybosl2.py`,
because Python import shadowing can invalidate the test.

## OpenSCAD documentation tooling

`openscad_docsgen` is a public capability. Structured source must begin with
`File:` or `LibFile:` before `Module`, `Function`, `Constant`, etc.

Keep API/source documentation separate from project design documentation:

```text
docsgen comments     API/source reference
design.md            design intent and visual construction
```

Smoke tests must validate the actual files produced by the invoked docsgen
command rather than guessing output locations.

## Image post-processing

`scad-image-watermark` is deliberately narrow. It is a generic PNG operation.

```text
docker.scad-toolchain    implements image operation
tool.scad-project        decides when/how to call it
consumer project         supplies policy/text
```

Do not move project-specific watermark decisions into this repository.

## Change discipline

Before changing consumers:

1. implement the runtime capability here;
2. publish a new immutable release candidate/release as appropriate;
3. prove it in `docker.scad-toolchain.test`;
4. then deliberately update downstream repositories.

Keep dependency pins centralized in `versions.env` and keep release history in
`CHANGELOG.md` rather than copying version tables into multiple documentation
files.
