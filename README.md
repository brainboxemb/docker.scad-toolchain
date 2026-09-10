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
- SCons
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
scons
scad-toolchain-info
openscad-docsgen
openscad-mdimggen
scad-image-watermark
```

SCons is intentionally only a generic runtime capability here. Build target
selection, dependency scanning and incremental-build policy belong in
`tool.scad-project` or another consumer.

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

## pybosl2 and external Python packages

pybosl2 is installed as a separately versioned Python package under:

```text
/opt/python-libs
```

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

## OpenSCAD documentation tooling

The image includes the upstream `openscad_docsgen` package and exposes:

```text
openscad-docsgen
openscad-mdimggen
```

Use upstream docsgen comment syntax for structured OpenSCAD API/source
documentation. API/source documentation and project design documentation serve
different purposes:

```text
.scad docsgen comments -> API / source reference
design.md               -> design intent and visual construction
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
  --build-arg SCONS_VERSION="$SCONS_VERSION" \
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

The project is in the experimental `0.x` line and uses semantic-style
versioning.

Current development target:

```text
v0.4.1
```

Dependency pins for a release are defined in `versions.env`. Release history is
recorded in [`CHANGELOG.md`](CHANGELOG.md).

Released Git tags and GHCR image tags are immutable. Never replace an existing
release tag with different contents. A release is complete only after both the
runtime image and its external consumer evidence have been made immutable.

Release sequence for v0.4.1:

```text
PR candidate
  -> build image locally in CI
  -> internal smoke PASS

main -> :edge
  -> internal smoke PASS
  -> docker.scad-toolchain.test against :edge PASS

tag docker.scad-toolchain v0.4.1
  -> publish :v0.4.1
  -> internal smoke PASS
  -> docker.scad-toolchain.test against :v0.4.1 PASS

tag docker.scad-toolchain.test test-v0.4.1-toolchain-v0.4.1
  -> permanent Pages verification evidence
```

Only after the permanent tagged verification report is green should downstream
consumers such as `tool.scad-project` be advanced to the new toolchain release.

Create releases through the permanent GitHub Actions workflow:

```text
Actions -> Release SCAD toolchain -> Run workflow
```

Provide `version` and the exact already-verified `release_sha`. The release
workflow creates the annotated tag and dispatches the normal build workflow on
that tag; the normal build workflow remains authoritative for publishing and
verification.
