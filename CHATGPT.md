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

BOSL2 is installed under `/opt/openscad-libraries/BOSL2`.

The toolchain exposes:

```text
OPENSCADPATH=/opt/openscad-libraries
BOSL2_ROOT=/opt/openscad-libraries/BOSL2
```

`OPENSCADPATH` is for normal OpenSCAD library resolution. `BOSL2_ROOT` is the
explicit filesystem root for PythonSCAD `osuse()`/`osinclude()` and other APIs
that do not search `OPENSCADPATH`.

Normal OpenSCAD consumers should still use syntax such as:

```scad
include <BOSL2/std.scad>
```

`pybosl2` is installed as a separately versioned Python package under
`/opt/python-libs`. System Python uses `PYTHONPATH`; PythonSCAD consumers must
currently add that directory to `sys.path` explicitly.

Do not describe pybosl2 as a wrapper around the installed BOSL2 tree. It is a
separate Python port with its own release/version.

## Version pins

All intentionally selected dependencies belong in `versions.env`.

Current planned v0.2 pins:

```text
PythonSCAD  1.1.2
BOSL2       2.0.752
pybosl2     0.6.7
Shapely     2.1.2
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

## BOSL2 path resolution rule

Do not assume PythonSCAD `osuse()` searches OpenSCAD's `OPENSCADPATH`.

A failure such as:

```text
FileNotFoundError: osuse(): file not found: 'BOSL2/shapes3d.scad'
```

means the SCAD file must be supplied as an actual filesystem path.

Use:

```python
import os
from pathlib import Path

bosl2_file = Path(os.environ["BOSL2_ROOT"]) / "std.scad"
bosl2 = osuse(str(bosl2_file))
```

`BOSL2_ROOT` is part of the public toolchain environment and points to the
pinned BOSL2 installation.

## PythonSCAD external package path

Python packages that are part of the toolchain are installed under:

```text
/opt/python-libs
```

Normal system Python sees that directory through `PYTHONPATH`.

Do **not** assume PythonSCAD will inherit `PYTHONPATH`. PythonSCAD uses an
embedded CPython runtime; external packages must currently be made visible from
the design/test script itself:

```python
import sys
sys.path.insert(0, "/opt/python-libs")
```

This follows PythonSCAD's documented pattern for external pip packages.

Consumer tests for PythonSCAD + pybosl2 must include this path setup. A system
Python import is not sufficient evidence that PythonSCAD can import the same
package.

## Python import-shadowing rule

Never name a consumer/test script `pybosl2.py`.

Python adds the script directory to `sys.path`, so a local `pybosl2.py` shadows
the installed package. An import such as:

```python
from pybosl2 import cuboid
```

then imports the test file itself and fails with a partially initialized /
circular import error.

Use descriptive names such as `pybosl2_smoke.py` instead.

## pybosl2 dependency note

For pybosl2 0.6.7, a real import of its geometry/path stack reaches
`pybosl2.path2d`, which imports `shapely`. In the tested package installation
Shapely was not installed automatically.

Therefore the toolchain explicitly pins and installs:

```text
Shapely 2.1.2
```

Do not remove this merely because `pip install pybosl2` succeeds. Package
metadata/version checks are insufficient: keep an import-level dependency smoke
test, and keep the actual geometry test under PythonSCAD.

System Python is not the target runtime for native pybosl2 geometry. Its smoke
test should validate dependency availability only. PythonSCAD is responsible
for proving `cuboid()`/geometry creation works.

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


## BOSL2 entrypoint rule

Use `std.scad` as the BOSL2 library entrypoint in both OpenSCAD and PythonSCAD
tests.

```text
OpenSCAD
    include <BOSL2/std.scad>

PythonSCAD
    osuse(BOSL2_ROOT/std.scad)
```

Do not directly load `shapes3d.scad`; it assumes the standard BOSL2 environment
created by `std.scad`.
