# ChatGPT project handoff — docker.scad-toolchain

## Purpose

This repository builds and publishes the shared CAD runtime used by other
brainboxemb CAD repositories.

The image is a **toolchain**, not a project-specific build system. It provides
stable public commands and reusable CAD libraries; consumer repositories own
their own design, render, export and verification logic.

## Public runtime interface

The intended stable commands are:

```text
openscad
pythonscad
python3
git
scad-toolchain-info
```

Do not make consumers depend on the internal AppImage path or other Docker
implementation details when a stable public command exists.

## Included CAD libraries

The v0.2 line adds two distinct BOSL2 capabilities:

```text
OpenSCAD   -> BOSL2
PythonSCAD -> pybosl2
```

BOSL2 is installed under `/opt/openscad-libraries/BOSL2` and exposed through
`OPENSCADPATH`, so consumers should use normal OpenSCAD syntax such as:

```scad
include <BOSL2/std.scad>
```

`pybosl2` is installed as a separately versioned Python package and exposed
through `PYTHONPATH`.

Do not describe pybosl2 as a wrapper around the installed BOSL2 tree. It is a
separate Python port with its own release/version.

## Version pins

All intentionally selected dependencies belong in `versions.env`.

Current planned v0.2 pins:

```text
PythonSCAD  1.1.2
BOSL2       2.0.752
pybosl2     0.6.7
```

OpenSCAD still comes from the official development-snapshot APT repository.
A released Docker image freezes the snapshot that was resolved during that
build.

## Release policy

The `0.x` line is experimental and uses semantic-style versioning.

Released image tags are immutable. Never rebuild/re-push an existing released
version with changed contents. Adding BOSL2/pybosl2 is a meaningful toolchain
capability change, so it belongs in the v0.2 line rather than replacing v0.1.2.

## Toolchain repository vs external test repository

Responsibilities are deliberately separate:

```text
docker.scad-toolchain
    -> builds the runtime image
    -> performs internal build/smoke tests

docker.scad-toolchain.test
    -> consumes the published image
    -> verifies the public consumer interface
    -> publishes evidence/reports
```

A capability is not considered proven merely because its package exists in the
Docker image. Add a real consumer test to `docker.scad-toolchain.test`.

For BOSL2 the external test suite should cover:

```text
OpenSCAD   -> BOSL2 .scad
PythonSCAD -> BOSL2 .scad through osuse()/osinclude()
PythonSCAD -> pybosl2
```

The last two should use equivalent small geometry so their behavior can be
compared.

## PythonSCAD status

PythonSCAD remains available in this general toolchain even though current
reusable library development prefers OpenSCAD.

The clamp-library investigation found that current PythonSCAD interoperability
does not transfer OpenSCAD `object()` values across the Python/OpenSCAD
boundary. Do not weaken object-oriented OpenSCAD library APIs merely to work
around that limitation.

BOSL2/pybosl2 support is included as toolchain capability and experimentation,
not as a decision to make PythonSCAD the primary CAD-library direction.

## Change discipline

Before changing consumers:

1. change this toolchain;
2. publish a new immutable image/version;
3. prove the capability in `docker.scad-toolchain.test`;
4. only then update downstream CAD repositories deliberately.

Keep internal smoke tests small. Broader behavior/interoperability belongs in
the external consumer test repository.
