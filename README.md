# docker.scad-toolchain

Shared Docker toolchain for reproducible scripted CAD builds and renders.

The repository publishes a related runtime-image family from one multi-stage
source. Project-specific build and dependency policy belongs outside this
repository. Drawing/publication tooling is isolated in an opt-in profile.

## Runtime profiles

### OpenSCAD-focused runtime

Published as:

```text
ghcr.io/brainboxemb/scad-toolchain-openscad:<version>
```

It contains the capabilities needed by normal OpenSCAD projects:

- OpenSCAD development snapshot with stable `openscad` command;
- Python 3 and Git;
- Xvfb plus rendering/font dependencies;
- BOSL2 for OpenSCAD;
- `openscad_docsgen` / `openscad-docsgen` / `openscad-mdimggen`;
- Pillow and `scad-image-watermark`;
- SCons.

### Drawing runtime

Published as:

```text
ghcr.io/brainboxemb/scad-toolchain-drawing:<version>
```

It extends the OpenSCAD-focused runtime with drawsvg for readable Python SVG
authoring, Inkscape CLI for deterministic rendering/export, and a checksum-
pinned official FreeCAD Linux bundle for headless TechDraw CAD-style hidden-
line-removal reference projections.

The normal publication path remains:

```text
OpenSCAD geometry/projections
    -> Python + drawsvg composition
    -> canonical SVG
    -> Inkscape CLI
    -> SVG / PNG / PDF
```

For geometry-validation work the same profile additionally supports:

```text
OpenSCAD -> STL
    -> FreeCAD mesh -> refined Part shape
    -> TechDraw HLR
    -> visible/hidden 2D edge reference
```

The drawing profile deliberately does not rely on an OpenSCAD dimensioning
library; dimensioning and sheet composition belong to the scripted SVG layer.
FreeCAD HLR is an independent projection/reference capability rather than a
replacement geometry source.

### Full / dual runtime

Published as the existing compatibility image:

```text
ghcr.io/brainboxemb/scad-toolchain:<version>
```

It extends the OpenSCAD runtime with:

- PythonSCAD;
- pybosl2;
- Shapely;
- PythonSCAD-specific runtime dependencies.

The existing `scad-toolchain` package therefore remains the full runtime.
Consumers that intentionally support both OpenSCAD and PythonSCAD keep the
same image name; OpenSCAD-only consumers may opt into the smaller focused
profile.

Use immutable version tags in normal consumers. The mutable `:edge` tags
represent current `main` and exist for development/pre-release validation.

## Profile selection

The image repository does not decide which profile a project needs.
`tool.scad-project` owns that project-level policy.

Conceptually:

```text
OpenSCAD-only project
    -> scad-toolchain-openscad:<version>

project with technical-drawing publication capability
    -> scad-toolchain-drawing:<version>

project with PythonSCAD capability
    -> scad-toolchain:<version>
```

Do not maintain repository-name allowlists in CI. Runtime choice should follow
the effective project capabilities/configuration.

## Open-source acknowledgments

Both distributed runtime profiles carry the same release documentation
contract under:

```text
/usr/share/doc/scad-toolchain/
  OPEN_SOURCE_ACKNOWLEDGMENTS.txt
  OPEN_SOURCE_ACKNOWLEDGMENTS.pdf
  DIRECT_LICENSE_FILES.txt
  DEBIAN_PACKAGES.txt
  PYTHON_DISTRIBUTIONS.txt
```

`compliance/OPEN_SOURCE_ACKNOWLEDGMENTS.txt` is the maintained authoring input.
The image build injects the actual release/profile versions, appends the
license/copyright files for the direct runtime components and generates the PDF
from the same assembled text with a standard-library-only generator.

The normal Ubuntu package copyright files remain present under
`/usr/share/doc/*/copyright`. Release-tag builds retain the generated TXT, PDF and inventory files as a CI
artifact and publish the profile-specific TXT/PDF files directly on the GitHub
Release page. Supporting license/package inventories are attached as one ZIP.

`scad-toolchain-info` prints the in-image TXT/PDF paths.

## Inspecting a runtime

All runtime profiles expose:

```bash
scad-toolchain-info
```

The output includes `SCAD_TOOLCHAIN_PROFILE` and reports optional full-runtime
components as `not installed` in the OpenSCAD profile.

## Public runtime interface

Shared commands available in all runtime profiles include:

```text
openscad
python3
git
scons
scad-toolchain-info
openscad-docsgen
openscad-mdimggen
scad-image-watermark
```

The drawing profile additionally exposes:

```text
inkscape
freecadcmd
Python package: drawsvg
```

The full profile additionally exposes:

```text
pythonscad
```

Consumers should depend on these public commands/environment variables rather
than internal installation paths.

## Image watermark tooling

The shared runtime exposes:

```text
scad-image-watermark
```

It uses Pillow and the fonts already present in the rendering environment. The
command adds a small bottom-right label and is not intended as a general image
processing framework.

Example:

```bash
scad-image-watermark input.png output.png --text "© 2026 brainboxemb"
```

The consuming project decides whether watermarking is enabled and what text is
used.

## BOSL2

BOSL2 is installed as a normal OpenSCAD library in all runtime profiles. Public
environment variables expose it:

```text
OPENSCADPATH=/opt/openscad-libraries
BOSL2_ROOT=/opt/openscad-libraries/BOSL2
```

Typical OpenSCAD usage:

```scad
include <BOSL2/std.scad>

cuboid([30, 20, 10], rounding=3);
```

Use `std.scad` as the normal BOSL2 entrypoint.

### PythonSCAD consuming BOSL2 SCAD files

This is relevant only to the full runtime. PythonSCAD `osuse()` requires a
real path; it should not assume `OPENSCADPATH` search behaviour.

```python
import os
from pathlib import Path
from pythonscad import *

bosl2_file = Path(os.environ["BOSL2_ROOT"]) / "std.scad"
bosl2 = osuse(str(bosl2_file))
```

This keeps the physical installation path out of consumer configuration while
using the BOSL2 tree supplied by the runtime.

## pybosl2 and external Python packages

The full runtime installs pybosl2 and its pinned Shapely dependency under:

```text
/opt/python-libs
```

BOSL2 and pybosl2 are separate implementations and can have different release
cadences.

System Python sees the directory through `PYTHONPATH`. PythonSCAD embeds its
own CPython runtime and may require consumers to add the path explicitly:

```python
import sys
sys.path.insert(0, "/opt/python-libs")

from pythonscad import *
from pybosl2 import cuboid

part = cuboid([30, 20, 10], rounding=3)
part.show()
```

Consumer/test files must not be named `pybosl2.py`, because that would shadow
the installed package.

The external test repository keeps the known PythonSCAD/OpenSCAD
interoperability limitations as explicit XFAIL probes. The existence of those
boundaries does not mean PythonSCAD is removed from projects that intentionally
support it.

## OpenSCAD documentation tooling

All runtime profiles include the upstream `openscad_docsgen` package and expose:

```text
openscad-docsgen
openscad-mdimggen
```

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

API/source documentation and project design documentation remain separate
concerns:

```text
.scad docsgen comments -> API/source reference

design.md              -> design intent and visual explanation
```

## Local build

All selected dependency versions are stored in `versions.env`.

```bash
set -a
source versions.env
set +a
```

Build the OpenSCAD profile:

```bash
docker build \
  --target openscad \
  --build-arg BOSL2_VERSION="$BOSL2_VERSION" \
  --build-arg OPENSCAD_DOCSGEN_VERSION="$OPENSCAD_DOCSGEN_VERSION" \
  --build-arg PILLOW_VERSION="$PILLOW_VERSION" \
  --build-arg SCONS_VERSION="$SCONS_VERSION" \
  -t scad-toolchain-openscad:local .
```

Build the drawing profile:

```bash
docker build \\
  --target drawing \\
  --build-arg BOSL2_VERSION="$BOSL2_VERSION" \\
  --build-arg OPENSCAD_DOCSGEN_VERSION="$OPENSCAD_DOCSGEN_VERSION" \\
  --build-arg PILLOW_VERSION="$PILLOW_VERSION" \\
  --build-arg SCONS_VERSION="$SCONS_VERSION" \\
  --build-arg DRAWSVG_VERSION="$DRAWSVG_VERSION" \\
  --build-arg FREECAD_VERSION="$FREECAD_VERSION" \\
  --build-arg FREECAD_APPIMAGE_SHA256="$FREECAD_APPIMAGE_SHA256" \\
  -t scad-toolchain-drawing:local .
```

Build the full profile:

```bash
docker build \
  --target full \
  --build-arg PYTHONSCAD_VERSION="$PYTHONSCAD_VERSION" \
  --build-arg BOSL2_VERSION="$BOSL2_VERSION" \
  --build-arg PYBOSL2_VERSION="$PYBOSL2_VERSION" \
  --build-arg SHAPELY_VERSION="$SHAPELY_VERSION" \
  --build-arg OPENSCAD_DOCSGEN_VERSION="$OPENSCAD_DOCSGEN_VERSION" \
  --build-arg PILLOW_VERSION="$PILLOW_VERSION" \
  --build-arg SCONS_VERSION="$SCONS_VERSION" \
  -t scad-toolchain:local .
```

Run the internal smoke tests:

```bash
docker run --rm \
  -v "$PWD:/work" \
  scad-toolchain-openscad:local \
  bash /work/scripts/test-toolchain.sh

docker run --rm \
  -v "$PWD:/work" \
  scad-toolchain:local \
  bash /work/scripts/test-toolchain.sh
```

The smoke script detects the profile and verifies the appropriate contract.

## External qualification

`brainboxemb/docker.scad-toolchain.test` is the external consumer contract for
the published image family.

It runs the shared OpenSCAD-facing contract against all three profiles,
qualifies the Inkscape publication path only in the drawing profile, and runs
PythonSCAD/pybosl2-specific coverage only against the full profile.

For Migration 005 the qualified candidate measured:

| Profile | Compressed OCI bytes |
| --- | ---: |
| OpenSCAD-focused | 328,098,501 |
| full/dual | 449,516,893 |

The focused profile therefore avoids 121,418,392 compressed bytes, about 27%,
for consumers that do not need PythonSCAD.

Routine qualification pulls the OpenSCAD profile first and lets the full
profile reuse shared local Docker layers. A separate controlled benchmark was
used to compare independent cold pulls; destructive Docker pruning is not part
of normal CI.

## Repository responsibilities

```text
docker.scad-toolchain
    -> builds and publishes the OpenSCAD, drawing and full CAD runtime profiles

docker.scad-toolchain.test
    -> externally validates all published profiles
    -> publishes verification reports

tool.scad-project
    -> selects a runtime from effective project capabilities
    -> owns project workflow and build orchestration

CAD projects and libraries
    -> design source, project configuration and project-specific verification
```

The runtime repository contains generic capabilities only. Project policy
belongs in `tool.scad-project` or the consuming project.

## Versioning and release

The project is in the experimental `0.x` line and uses semantic-style
versioning.

Current development target:

```text
v0.7.0
```

Dependency pins and the release version are defined in `versions.env`.
Release history lives in [`CHANGELOG.md`](CHANGELOG.md).

Released Git tags and GHCR image tags are immutable. Never replace an existing
release tag with different contents.

A release is complete only after all published runtime profiles and their
external consumer evidence are immutable.

The external test-suite version is independent from the toolchain version. A
toolchain-only release does not force a test-suite version bump when the
functional consumer contract is unchanged.

For `v0.6.0` the sequence is:

```text
main
  -> publish OpenSCAD, drawing and full :edge profiles
  -> internal smoke PASS for all three
  -> docker.scad-toolchain.test against :edge PASS for all three

tag docker.scad-toolchain v0.6.0
  -> publish OpenSCAD, drawing and full :v0.6.0 profiles
  -> internal smoke PASS for all three
  -> publish GitHub Release with profile-specific acknowledgment TXT/PDF assets
  -> automatic docker.scad-toolchain.test against :v0.6.0 PASS
  -> mutable Pages /latest/ updated

tag docker.scad-toolchain.test test-v0.6.0-toolchain-v0.6.0
  -> complete external suite against all three :v0.6.0 profiles PASS
  -> permanent Pages report:
     /test-v0.6.0-toolchain-v0.6.0/
```

Only after that permanent three-profile verification record is green should
downstream consumers such as `tool.scad-project` move to v0.6.0.

Create the runtime release through the permanent GitHub Actions Release
workflow using:

```text
version      v0.5.3
release_sha  exact already-verified main commit SHA
```

The release workflow creates the annotated tag and explicitly starts the normal
Build workflow on that tag. The Build workflow remains authoritative for
publishing both images, generating the release documents, creating/updating the
GitHub Release assets and triggering external verification.

The Git tag and GHCR image tags remain the immutable software identity. GitHub
Release assets are publication metadata for that same tag and may be re-uploaded
only from the exact tag build when a workflow rerun is required.
