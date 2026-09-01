# docker.scad-toolchain

Docker-based toolchain for reproducible OpenSCAD and PythonSCAD builds, renders and CI workflows.

The image provides a shared CAD build environment for GitHub Actions and local Docker-based workflows.

It is intended for projects that use OpenSCAD, PythonSCAD or both.

## Purpose

Without a shared toolchain, every CAD repository has to install and maintain its own OpenSCAD and PythonSCAD environment.

This repository centralizes that environment:

```text
docker.scad-toolchain
        |
        | builds and publishes
        v
GitHub Container Registry
        |
        | consumed by
        v
CAD repositories
```

The container provides:

- OpenSCAD
- PythonSCAD
- Python
- Xvfb for headless rendering
- required runtime libraries
- fonts and basic render dependencies
- toolchain information helpers

Individual CAD repositories can therefore focus on design, build and verification instead of repeatedly installing CAD tooling.

## Container image

Images are published to:

```text
ghcr.io/brainboxemb/scad-toolchain
```

Released versions should be consumed using an explicit tag:

```text
ghcr.io/brainboxemb/scad-toolchain:<version>
```

For example:

```yaml
container:
  image: ghcr.io/brainboxemb/scad-toolchain:v0.1.1
```

Moving tags such as `latest` or `edge` should not be used for reproducible CAD builds.

## Design decisions

### Stable public command names

The toolchain exposes a stable command interface to consuming repositories:

```text
openscad
pythonscad
python3
scad-toolchain-info
```

Consumers should depend on these names rather than on implementation details of the underlying packages.

For example, an OpenSCAD development package may internally install:

```text
openscad-nightly
```

The container deliberately normalizes this to:

```text
openscad
```

This keeps downstream workflows independent from how a particular OpenSCAD package is named or distributed.

### Explicit toolchain versions

CAD repositories should pin an explicit toolchain image version.

A CAD build should not silently start using a newer OpenSCAD or PythonSCAD merely because a moving container tag changed.

Instead, a toolchain update should be a deliberate repository change:

```text
toolchain vX.Y.Z
        |
        | validate
        v
update consuming project
        |
        | rebuild / render / verify
        v
commit toolchain upgrade
```

This makes changes in geometry, rendering or export behavior easier to identify and reproduce.

### Centralized CAD environment

The toolchain image contains the common CAD runtime instead of requiring every consuming repository to download and cache its own copy.

Conceptually:

```text
                    scad-toolchain
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
        CAD project   CAD library   CAD project
```

This avoids maintaining separate OpenSCAD installation logic and large binary caches in every repository.

### External validation

The image is not considered validated merely because it successfully builds.

Published images are tested from a separate consumer repository:

```text
docker.scad-toolchain.test
```

This distinction is intentional.

```text
docker.scad-toolchain
        |
        | proves
        v
the image can be built

docker.scad-toolchain.test
        |
        | proves
        v
the published image can be consumed
```

The external tests verify the public CLI interface and real OpenSCAD/PythonSCAD render and export operations.

### Tool versions outside the README

Exact installed versions of OpenSCAD, PythonSCAD and Python are deliberately not duplicated in this README.

The actual image is authoritative.

Versions can be inspected with:

```bash
scad-toolchain-info
```

Example output:

```text
SCAD toolchain
==============

OpenSCAD   : <installed OpenSCAD version>
PythonSCAD : <installed PythonSCAD version>
Python     : <installed Python version>
```

Build-version selection is maintained in the repository configuration rather than copied into descriptive README text.

This avoids stale version documentation.

### Immutable releases

Once a toolchain version has been published, that version should not be changed.

For example, if:

```text
ghcr.io/brainboxemb/scad-toolchain:v0.1.0
```

has been published, a later fix should result in another version such as:

```text
v0.1.1
```

rather than replacing the existing `v0.1.0` image.

This makes historical CAD builds reproducible.

## Repository layout

```text
docker.scad-toolchain/
├── Dockerfile
├── versions.env
├── README.md
├── scripts/
│   ├── scad-toolchain-info
│   └── test-toolchain.sh
├── test/
│   └── smoke.scad
└── .github/
    └── workflows/
        └── build.yml
```

## `versions.env`

Tool-version selection used during the container build is maintained in:

```text
versions.env
```

This makes dependency changes visible in Git history without duplicating them throughout the documentation.

Changes to the actual toolchain contents should normally lead to a new toolchain release.

## Public interface

The following commands form the expected consumer-facing interface:

```bash
openscad
pythonscad
python3
scad-toolchain-info
```

Internal package names or installation paths are implementation details and should not be used by downstream repositories.

## Building locally

Build the image from the repository root:

```bash
docker build -t scad-toolchain:local .
```

Inspect the resulting environment:

```bash
docker run --rm \
  scad-toolchain:local \
  scad-toolchain-info
```

## Using the toolchain locally

A CAD project can be mounted into the container.

For example, an OpenSCAD STL export:

```bash
docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  ghcr.io/brainboxemb/scad-toolchain:<version> \
  openscad \
    -o out/model.stl \
    model.scad
```

A headless PNG render can use Xvfb:

```bash
docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  ghcr.io/brainboxemb/scad-toolchain:<version> \
  xvfb-run -a openscad \
    --render \
    -o out/model.png \
    model.scad
```

## Using the toolchain in GitHub Actions

A consuming repository can run a complete job inside the published image:

```yaml
jobs:
  render:
    runs-on: ubuntu-24.04

    container:
      image: ghcr.io/brainboxemb/scad-toolchain:<version>

    steps:
      - uses: actions/checkout@v4

      - name: Show toolchain
        run: scad-toolchain-info

      - name: Render model
        run: |
          xvfb-run -a openscad \
            --render \
            -o out/model.png \
            model.scad
```

If the GHCR package is private, appropriate package permissions and container credentials must be configured.

## Release model

The toolchain uses semantic version tags:

```text
vMAJOR.MINOR.PATCH
```

During development and experimentation, releases remain below `v1.0.0`.

Typical interpretation:

- **PATCH** — compatible fix to the existing toolchain;
- **MINOR** — new capability or meaningful toolchain change;
- **MAJOR** — incompatible change to the established toolchain contract.

The exact meaning can evolve while the project remains in the `v0.x` phase, but existing released tags remain immutable.

## Creating a release

First commit the intended toolchain state:

```bash
git add .
git commit -m "Describe the toolchain change"
git push
```

Create an annotated release tag:

```bash
git tag -a vX.Y.Z -m "SCAD toolchain vX.Y.Z"
```

Push it:

```bash
git push origin vX.Y.Z
```

The GitHub Actions workflow builds the image and publishes:

```text
ghcr.io/brainboxemb/scad-toolchain:vX.Y.Z
```

A GitHub Release page may additionally be created for human-readable release notes.

The Git tag and published container image are the important immutable technical references.

## Release notes versus design documentation

Release notes describe **what changed in a particular version**.

For example:

```text
Fixed OpenSCAD command exposure
Added additional rendering dependency
Updated PythonSCAD
```

Those details belong in GitHub Releases or another changelog mechanism.

The README instead documents **why the toolchain is structured the way it is**.

For example, normalizing package-specific OpenSCAD executables to a stable `openscad` command is a permanent design decision and therefore belongs in this README.

## External verification

Published toolchain versions are validated by:

```text
docker.scad-toolchain.test
```

The intended release flow is:

```text
toolchain source
      |
      v
build image
      |
      v
publish GHCR version
      |
      v
external test suite
      |
      v
validated toolchain
      |
      v
adopt in CAD projects
```

Test results are published separately by the test repository.

A toolchain version should preferably be externally validated before it is adopted broadly by consuming CAD repositories.

## Updating a consuming CAD repository

A CAD project should pin an explicit version:

```yaml
container:
  image: ghcr.io/brainboxemb/scad-toolchain:<version>
```

When upgrading:

1. publish the new toolchain version;
2. validate it using `docker.scad-toolchain.test`;
3. update the pinned version in the consuming repository;
4. regenerate relevant CAD output;
5. inspect renders and geometry;
6. run project verification;
7. commit the explicit toolchain upgrade.

This makes the environment change visible as part of the project history.

## Removing a package version

Container versions are managed through GitHub Container Registry.

On GitHub:

1. open the `scad-toolchain` package;
2. choose **View and manage all versions**;
3. locate the desired package version;
4. open its menu;
5. choose **Delete version**.

Deleting a GHCR package version does not automatically delete the Git tag.

A tag created by mistake can be removed separately.

Delete the local tag:

```bash
git tag -d vX.Y.Z
```

Delete the remote tag:

```bash
git push origin :refs/tags/vX.Y.Z
```

Published versions that have already been consumed by other projects should normally remain available.

## Related repositories

### `docker.scad-toolchain`

Builds and publishes the shared OpenSCAD/PythonSCAD toolchain.

### `docker.scad-toolchain.test`

Externally validates published toolchain images and publishes browsable verification results.

### CAD and library repositories

Consume an explicitly versioned and validated SCAD toolchain as their build and render environment.