# docker.scad-toolchain

Shared Docker toolchain for scripted CAD builds and renders.

The image provides a single reusable CI/runtime environment for repositories that use OpenSCAD and PythonSCAD. This avoids downloading and caching a separate ~80 MB OpenSCAD installation in every CAD repository.


## v0.1.1

`v0.1.1` fixes the public OpenSCAD command exposed by the container.

The Ubuntu nightly package installs `openscad-nightly`. The toolchain now
provides a stable `/usr/local/bin/openscad` symlink, so consumer repositories
can always invoke:

```bash
openscad --version
```

`v0.1.0` remains immutable and is intentionally not replaced.


## Status

**Current development version: v0.1.x**

The `0.x` series is intentionally experimental. The image layout, included tools and versioning policy may still change while it is being tested with real CAD repositories.

Do not treat `v0.1.1` as a stable long-term interface yet.

## Included tools

- OpenSCAD development snapshot (`openscad-nightly`)
- PythonSCAD
- Python 3
- Xvfb
- basic rendering and font dependencies

Tool versions and build details can be inspected inside the image with:

```bash
scad-toolchain-info
```

## Container image

GitHub Actions publishes the image to GitHub Container Registry (GHCR):

```text
ghcr.io/brainboxemb/scad-toolchain
```

Examples of tags:

```text
ghcr.io/brainboxemb/scad-toolchain:v0.1.1
ghcr.io/brainboxemb/scad-toolchain:edge
ghcr.io/brainboxemb/scad-toolchain:sha-<commit>
```

### Which tag should I use?

Use a version tag in CAD repositories when you want reproducible builds:

```text
v0.1.1
```

`edge` always represents a build from the current `main` branch and is therefore mainly useful for testing the toolchain itself.

A released version tag should never be reused for a different image. If the contents change, create a new version such as `v0.1.1` or `v0.2.0`.

## Version policy

The project follows semantic-style versioning while it is experimental:

```text
v0.1.1  first usable test release
v0.1.1  backwards-compatible fix to v0.1
v0.2.0  meaningful toolchain or behaviour change
v1.0.0  first intentionally stable toolchain
```

PythonSCAD is explicitly pinned in `versions.env`.

OpenSCAD currently comes from the official development-snapshot APT repository while the Docker image is built. Once an image is published under a version tag, that image itself is immutable by convention: do not rebuild/re-push the same release tag with different contents.

A next refinement is to resolve and record the exact OpenSCAD snapshot/build identifier as OCI metadata before publishing a release image.

---

# Creating the first v0.1.1 release

There are two different things involved:

1. a **Git tag** in the source repository;
2. a **container image version** in GHCR.

For this repository, pushing the Git tag automatically creates the corresponding container image tag. A GitHub "Release" page is optional.

## 1. Commit the version you want to release

Make sure `main` contains exactly what you want in `v0.1.1`:

```bash
git status
git add .
git commit -m "Prepare SCAD toolchain v0.1.1"
git push origin main
```

If there is nothing new to commit, only the final `git push` is relevant.

## 2. Create the v0.1.1 Git tag

Create an annotated tag:

```bash
git tag -a v0.1.1 -m "SCAD toolchain v0.1.1"
```

Push it to GitHub:

```bash
git push origin v0.1.1
```

That tag triggers `.github/workflows/build.yml`.

The workflow builds and publishes:

```text
ghcr.io/brainboxemb/scad-toolchain:v0.1.1
```

It also performs the smoke test against the published image.

## 3. Check the workflow

On GitHub:

```text
repository
  -> Actions
  -> Build SCAD toolchain
```

The tagged workflow run should complete successfully.

## 4. Check the published container

On the GitHub repository page, use the **Packages** section in the right sidebar and open the `scad-toolchain` package.

You should see a version associated with `v0.1.1`.

From a machine with Docker you can also test it directly:

```bash
docker pull ghcr.io/brainboxemb/scad-toolchain:v0.1.1
```

Then inspect it:

```bash
docker run --rm \
  ghcr.io/brainboxemb/scad-toolchain:v0.1.1 \
  scad-toolchain-info
```

## Optional: create a GitHub Release page

A GitHub Release is **not required** for GHCR publication. The Git tag is enough for this workflow.

If you also want release notes visible under GitHub Releases, you can create them afterwards with the GitHub CLI:

```bash
gh release create v0.1.1 \
  --title "SCAD toolchain v0.1.1" \
  --notes "First experimental OpenSCAD + PythonSCAD toolchain image."
```

Or use the GitHub web interface:

```text
repository
  -> Releases
  -> Draft a new release
  -> choose tag v0.1.1
  -> Publish release
```

---

# Using v0.1.1 from another repository

A GitHub Actions job can run directly inside the toolchain container:

```yaml
jobs:
  render:
    runs-on: ubuntu-24.04

    container:
      image: ghcr.io/brainboxemb/scad-toolchain:v0.1.1

    steps:
      - uses: actions/checkout@v4

      - name: Toolchain info
        run: scad-toolchain-info

      - name: OpenSCAD version
        run: openscad-nightly --version

      - name: PythonSCAD version
        run: pythonscad --version
```

For a public GHCR package, consumers normally do not need separate registry credentials just to pull it. If the package is private, the consuming workflow must have suitable package read access/authentication.

---

# Creating the next version

Never replace `v0.1.1` with changed contents.

For a small fix:

```bash
git tag -a v0.1.1 -m "SCAD toolchain v0.1.1"
git push origin v0.1.1
```

For a more substantial change:

```bash
git tag -a v0.2.0 -m "SCAD toolchain v0.2.0"
git push origin v0.2.0
```

Existing CAD projects can then remain pinned to `v0.1.1` until they are deliberately upgraded.

---

# Removing a released container version

Container versions do not normally expire just because they are old. They remain in GitHub Packages until they are removed (subject to GitHub's package policies).

Be careful: deleting an image can break repositories that are still pinned to it.

## Delete a GHCR version in the GitHub UI

For a repository-linked package:

```text
repository
  -> Packages
  -> scad-toolchain
  -> View and manage all versions
```

Find the version you want to remove, open its `...` menu and choose:

```text
Delete version
```

GitHub asks you to confirm the deletion.

Deleted package versions may be restorable for a limited period under GitHub's package restore rules.

## Deleting the Git tag is separate

Deleting a container image does **not** automatically delete its Git tag.

If you really also want to remove the Git tag locally and remotely:

```bash
git tag -d v0.1.1
git push origin --delete v0.1.1
```

Normally, do **not** delete release tags merely because an old image is no longer interesting. Tags are useful project history.

Likewise, deleting the Git tag does not automatically delete an already-published GHCR image.

---

# Local development

Load the pinned versions:

```bash
set -a
source versions.env
set +a
```

Build locally:

```bash
docker build \
  --build-arg PYTHONSCAD_VERSION="$PYTHONSCAD_VERSION" \
  -t scad-toolchain:local .
```

Run the included smoke test:

```bash
docker run --rm \
  -v "$PWD:/work" \
  scad-toolchain:local \
  bash /work/scripts/test-toolchain.sh
```

Inspect the toolchain:

```bash
docker run --rm scad-toolchain:local scad-toolchain-info
```

## Repository responsibilities

The intended separation is:

```text
docker.scad-toolchain
    -> CAD runtime/toolchain

brainboxemb.github.actions
    -> reusable GitHub Actions/build logic

CAD repositories
    -> design source, documentation, build and verification rules
```

This keeps individual CAD repositories from each maintaining their own OpenSCAD/PythonSCAD installation logic and binary cache.
