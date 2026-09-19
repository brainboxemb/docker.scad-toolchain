# docker.scad-toolchain

Shared Docker toolchain for reproducible scripted CAD builds and renders.

The repository publishes a related runtime-image family from one multi-stage
source. Project-specific build and dependency policy belongs outside this
repository.

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
- `openscad-new-dimensions` for dimensioned 2D OpenSCAD/SVG drawings;
- `openscad_docsgen` / `openscad-docsgen` / `openscad-mdimggen`;
- Pillow and `scad-image-watermark`;
- SCons.

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
`/usr/share/doc/*/copyright`. Release-tag builds also retain the generated TXT,
PDF and inventory files as a CI release artifact for both profiles.

`scad-toolchain-info` prints the in-image TXT/PDF paths.

## Inspecting a runtime

Both profiles expose:

```bash
scad-toolchain-info
```

The output includes `SCAD_TOOLCHAIN_PROFILE` and reports optional full-runtime
components as `not installed` in the OpenSCAD profile.

## Public runtime interface

Shared commands available in both profiles include:

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

## openscad-new-dimensions

The Codeberg-hosted `adrien-delhorme/openscad-new-dimensions` library is
installed in both runtime profiles as a normal OpenSCAD library at:

```text
/opt/openscad-libraries/openscad-new-dimensions
```

The exact upstream commit is pinned in `versions.env` and exposed through:

```text
OPENSCAD_NEW_DIMENSIONS_ROOT
OPENSCAD_NEW_DIMENSIONS_COMMIT
```

Because `OPENSCADPATH=/opt/openscad-libraries`, consumers can include the
library without carrying a Codeberg submodule or GitHub mirror. The internal
smoke test runs the upstream `demo/demo.scad` and requires OpenSCAD to export
a non-empty SVG.

## BOSL2

BOSL2 is installed as a normal OpenSCAD library in both profiles. Public
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

Both profiles include the upstream `openscad_docsgen` package and expose:

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
  --build-arg OPENSCAD_NEW_DIMENSIONS_COMMIT="$OPENSCAD_NEW_DIMENSIONS_COMMIT" \
  --build-arg OPENSCAD_DOCSGEN_VERSION="$OPENSCAD_DOCSGEN_VERSION" \
  --build-arg PILLOW_VERSION="$PILLOW_VERSION" \
  --build-arg SCONS_VERSION="$SCONS_VERSION" \
  -t scad-toolchain-openscad:local .
```

Build the full profile:

```bash
docker build \
  --target full \
  --build-arg PYTHONSCAD_VERSION="$PYTHONSCAD_VERSION" \
  --build-arg BOSL2_VERSION="$BOSL2_VERSION" \
  --build-arg OPENSCAD_NEW_DIMENSIONS_COMMIT="$OPENSCAD_NEW_DIMENSIONS_COMMIT" \
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

It runs the shared OpenSCAD-facing contract against both profiles and runs the
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
    -> builds and publishes both CAD runtime profiles

docker.scad-toolchain.test
    -> externally validates both published profiles
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
v0.5.0
```

Dependency pins and the release version are defined in `versions.env`.
Release history lives in [`CHANGELOG.md`](CHANGELOG.md).

Released Git tags and GHCR image tags are immutable. Never replace an existing
release tag with different contents.

A release is complete only after both runtime profiles and their external
consumer evidence are immutable.

For `v0.5.2` the sequence is:

```text
main
  -> publish both :edge profiles
  -> internal smoke PASS
  -> docker.scad-toolchain.test against :edge PASS

tag docker.scad-toolchain v0.5.2
  -> publish both :v0.5.2 profiles
  -> internal smoke PASS
  -> automatic docker.scad-toolchain.test against :v0.5.2 PASS
  -> mutable Pages /latest/ updated

tag docker.scad-toolchain.test test-v0.5.2-toolchain-v0.5.2
  -> external suite against both :v0.5.2 profiles PASS
  -> permanent Pages report:
     /test-v0.5.2-toolchain-v0.5.2/
```

Only after the permanent tagged verification report is green should downstream
consumers such as `tool.scad-project` move to the new runtime release.

Create the runtime release through the permanent GitHub Actions Release
workflow using:

```text
version      v0.5.2
release_sha  exact already-verified main commit SHA
```

The release workflow creates the annotated tag and explicitly starts the normal
Build workflow on that tag. The Build workflow remains authoritative for
publishing both images and triggering external verification.
