# docker.scad-toolchain

Shared Docker toolchain for reproducible scripted CAD builds and renders.

The image provides a single reusable environment for repositories using
OpenSCAD and PythonSCAD.

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

Inspect the actual image with:

```bash
scad-toolchain-info
```

## BOSL2

BOSL2 is installed as a normal OpenSCAD library and exposed through
`OPENSCADPATH`:

```scad
include <BOSL2/std.scad>

cuboid([30, 20, 10], rounding=3);
```

The BOSL2 version is pinned independently in `versions.env`.

## pybosl2

The Python port is also pinned independently and exposed through `PYTHONPATH`:

```python
from pythonscad import *
from pybosl2 import cuboid

part = cuboid([30, 20, 10], rounding=3)
part.show()
```

BOSL2 and pybosl2 are separate implementations and may have different release
cadences.

### pybosl2 runtime dependencies

`pybosl2` is installed together with an explicitly pinned Shapely dependency.

With pybosl2 0.6.7 we observed that importing geometry code reaches
`pybosl2.path2d`, which imports `shapely`, while the pybosl2 package installation
did not install Shapely automatically. The toolchain therefore pins it
explicitly rather than relying on an undeclared/transitive dependency.

The actual geometry smoke test still runs under PythonSCAD. Plain system Python
only verifies that the installed Python packages and dependencies can be
imported.

### Python module shadowing

Consumer/test files must not be named `pybosl2.py`. Python places the script
directory on its import path, so a local file with that name shadows the
installed `pybosl2` package and causes a circular/partially-initialized import.

Use names such as:

```text
pybosl2_smoke.py
pybosl2_consumer.py
```

## Version policy

The project is still in the experimental `0.x` line.

Released tags are immutable. Never replace an existing image tag with different
contents.

The BOSL2/pybosl2 capability is a meaningful toolchain extension and is planned
for:

```text
v0.2.0
```

Current pins are stored in `versions.env`.

## Container image

Published image:

```text
ghcr.io/brainboxemb/scad-toolchain
```

Use a version tag for reproducible consumer workflows:

```text
ghcr.io/brainboxemb/scad-toolchain:v0.2.0
```

`edge` is only the current `main` build and should not be used as an immutable
consumer dependency.

## Local build

```bash
set -a
source versions.env
set +a

docker build   --build-arg PYTHONSCAD_VERSION="$PYTHONSCAD_VERSION"   --build-arg BOSL2_VERSION="$BOSL2_VERSION"   --build-arg PYBOSL2_VERSION="$PYBOSL2_VERSION"   -t scad-toolchain:local .
```

Run the internal smoke test:

```bash
docker run --rm   -v "$PWD:/work"   scad-toolchain:local   bash /work/scripts/test-toolchain.sh
```

## Repository responsibilities

```text
docker.scad-toolchain
    -> CAD runtime/toolchain

docker.scad-toolchain.test
    -> external validation of the published runtime

brainboxemb.github.actions
    -> reusable GitHub Actions/build logic

CAD repositories
    -> design source, documentation, build and verification rules
```

The external test repository must prove the actual consumer paths. For the v0.2
line this includes normal OpenSCAD+BOSL2 use, PythonSCAD using BOSL2 `.scad`
code, and PythonSCAD using pybosl2.

## Release

Commit the intended contents to `main`, then create a new immutable tag:

```bash
git tag -a v0.2.0 -m "SCAD toolchain v0.2.0"
git push origin v0.2.0
```

The build workflow publishes the corresponding GHCR image and runs the internal
smoke tests.
