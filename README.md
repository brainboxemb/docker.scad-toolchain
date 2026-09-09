# docker.scad-toolchain

Shared Docker toolchain for reproducible scripted CAD builds and renders.

The image provides a reusable runtime environment for repositories using
OpenSCAD and PythonSCAD. Project-specific build policy belongs outside this
repository.

## Included tools and libraries

- OpenSCAD development snapshot (`openscad-nightly`) with stable `openscad`
  command
- PythonSCAD
- Python 3
- Git
- Xvfb and rendering/font dependencies
- BOSL2 for OpenSCAD
- pybosl2 for Python/PythonSCAD experiments
- Shapely runtime dependency used by pybosl2 path/region code
- openscad_docsgen
- Pillow for lightweight PNG post-processing
- `scad-image-watermark` for adding a small copyright/watermark label to PNG
  renders

Inspect the actual runtime with:

```bash
scad-toolchain-info
```

## Container image

Published image:

```text
ghcr.io/brainboxemb/scad-toolchain
```

Consumers should normally use an immutable version tag:

```text
ghcr.io/brainboxemb/scad-toolchain:<version>
```

The mutable `:edge` tag represents the current `main` build and is intended
for development and pre-release verification.

## Public runtime interface

Consumers should use the stable public commands and environment variables
exposed by the image rather than depending on internal installation paths.

Important public commands include:

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

## Image watermark tooling

The toolchain exposes one deliberately small image-processing command:

```text
scad-image-watermark
```

It uses Pillow and the fonts already present in the rendering environment. The
command adds a subtle bottom-right label and is not intended to turn the
toolchain into a general graphics-processing environment.

Example:

```bash
scad-image-watermark input.png output.png --text "© 2026 brainboxemb"
```

The consuming project or workflow decides whether watermarking is enabled and
what text is used. The Docker image only supplies the generic operation.

## BOSL2

BOSL2 is installed as a normal OpenSCAD library. Two public environment
variables expose it:

```text
OPENSCADPATH=/opt/openscad-libraries
BOSL2_ROOT=/opt/openscad-libraries/BOSL2
```

`OPENSCADPATH` is intended for normal OpenSCAD `include`/`use` resolution.
`BOSL2_ROOT` gives PythonSCAD and other consumers an explicit filesystem path
for APIs such as `osuse()` that do not resolve libraries through
`OPENSCADPATH`.

Normal OpenSCAD usage:

```scad
include <BOSL2/std.scad>

cuboid([30, 20, 10], rounding=3);
```

Use `std.scad` as the normal BOSL2 entrypoint. Do not use component files such
as `shapes3d.scad` as shortcut entrypoints; those files depend on constants and
support modules loaded by `std.scad`.

### PythonSCAD consuming BOSL2 SCAD files

PythonSCAD `osuse()` requires a real file path. Do not assume it searches
`OPENSCADPATH`.

Use the toolchain-provided `BOSL2_ROOT`:

```python
import os
from pathlib import Path

from pythonscad import *

bosl2_file = Path(os.environ["BOSL2_ROOT"]) / "std.scad"
bosl2 = osuse(str(bosl2_file))
```

This keeps the physical installation path out of consumer source while still
using the BOSL2 tree supplied by the toolchain.

## pybosl2 and external Python packages

pybosl2 is installed as a separately versioned Python package under:

```text
/opt/python-libs
```

BOSL2 and pybosl2 are separate implementations and may have different release
cadences.

System Python sees `/opt/python-libs` through `PYTHONPATH`. PythonSCAD embeds
its own CPython runtime and does not reliably inherit that environment path, so
PythonSCAD consumers must currently add the shared package directory explicitly:

```python
import sys
sys.path.insert(0, "/opt/python-libs")

from pythonscad import *
from pybosl2 import cuboid

part = cuboid([30, 20, 10], rounding=3)
part.show()
```

pybosl2 is installed together with an explicitly pinned Shapely dependency
because its geometry/path code imports Shapely even when package installation
alone succeeds without it.

The actual geometry smoke test runs under PythonSCAD. Plain system Python is
used only to verify that installed Python packages and their dependencies can be
imported.

### Python module shadowing

Consumer and test files must not be named `pybosl2.py`. Python places the
script directory on its import path, so a local file with that name shadows the
installed package and can cause a circular or partially initialized import.

Use descriptive names such as:

```text
pybosl2_smoke.py
pybosl2_consumer.py
```

## OpenSCAD documentation tooling

The image includes the upstream `openscad_docsgen` package and exposes:

```text
openscad-docsgen
openscad-mdimggen
```

Use upstream docsgen comment syntax for structured OpenSCAD API/source
documentation.

A parsed `.scad` file must declare a top-level `// File:` or `// LibFile:`
block before documenting modules, functions or constants.

Typical validation:

```bash
openscad-docsgen -m -T component.scad
```

Typical Markdown generation:

```bash
openscad-docsgen -D docs -m component.scad
```

API/source documentation and project design documentation serve different
purposes:

```text
.scad docsgen comments
    -> API / source reference

design.md
    -> design intent, construction steps and visual explanation
```

## Local build

All intentionally selected dependency versions are stored in `versions.env`.

```bash
set -a
source versions.env
set +a

docker build \
  --build-arg PYTHONSCAD_VERSION="$PYTHONSCAD_VERSION" \
  --build-arg BOSL2_VERSION="$BOSL2_VERSION" \
  --build-arg PYBOSL2_VERSION="$PYBOSL2_VERSION" \
  --build-arg SHAPELY_VERSION="$SHAPELY_VERSION" \
  --build-arg OPENSCAD_DOCSGEN_VERSION="$OPENSCAD_DOCSGEN_VERSION" \
  --build-arg PILLOW_VERSION="$PILLOW_VERSION" \
  -t scad-toolchain:local .
```

Run the internal smoke test:

```bash
docker run --rm \
  -v "$PWD:/work" \
  scad-toolchain:local \
  bash /work/scripts/test-toolchain.sh
```

## Repository responsibilities

```text
docker.scad-toolchain
    -> builds and publishes the CAD runtime

docker.scad-toolchain.test
    -> externally validates the published runtime
    -> publishes verification reports

tool.scad-project
    -> reusable project workflow and build orchestration

CAD projects and libraries
    -> design source, project configuration and project-specific verification
```

The runtime repository should contain generic capabilities only. Project policy
belongs in `tool.scad-project` or the consuming project.

## Versioning and release

The project is currently in the experimental `0.x` line and uses
semantic-style versioning.

Current development target:

```text
v0.4.0
```

Dependency pins for a release are defined in `versions.env`.

Released Git tags and GHCR image tags are immutable. Never replace an existing
release tag with different contents. If a released version needs a fix, create a
patch release such as `v0.4.1`.

A release is complete only after both the runtime image and its external
consumer evidence have been made immutable.

For `v0.4.0` the release sequence is:

```text
main -> :edge
  -> internal smoke PASS
  -> docker.scad-toolchain.test against :edge PASS

tag docker.scad-toolchain v0.4.0
  -> publish :v0.4.0
  -> internal smoke PASS
  -> automatic docker.scad-toolchain.test against :v0.4.0 PASS
  -> mutable Pages /latest/ updated

tag docker.scad-toolchain.test test-v0.4.0-toolchain-v0.4.0
  -> external suite against :v0.4.0 PASS
  -> permanent Pages report:
     /test-v0.4.0-toolchain-v0.4.0/
```

Only after the permanent tagged verification report is green should downstream
consumers such as `tool.scad-project` be advanced to the new toolchain
release.

Example toolchain release tag:

```bash
git tag -a v0.4.0 -m "SCAD toolchain v0.4.0"
git push origin v0.4.0
```
