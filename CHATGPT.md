# ChatGPT project handoff — docker.scad-toolchain

## Purpose

This repository builds and publishes the shared CAD runtime used by other
brainboxemb CAD repositories.

The image is a **toolchain**, not a project-specific build system. It provides
stable public commands and reusable CAD libraries. Project-specific dependency
policy, target selection, caching decisions and verification belong outside
this repository, primarily in `tool.scad-project`.

## Public runtime interface

Stable commands include:

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

Do not make consumers depend on internal installation paths when a stable
public command exists.

## Current version pins

All intentionally selected dependency versions belong in `versions.env`.
For the v0.4.1 line the important pins are:

```text
PythonSCAD          1.1.2
BOSL2               2.0.752
pybosl2             0.6.7
Shapely             2.1.2
openscad_docsgen    2.0.55
Pillow              12.3.0
SCons               4.11.1
```

OpenSCAD comes from the official development-snapshot APT repository. A
released Docker image freezes the snapshot resolved during that build.

## SCons ownership rule

Toolchain v0.4.1 adds SCons only as a **generic runtime capability**.

Keep responsibilities separated:

```text
docker.scad-toolchain
    -> provides pinned `scons`

tool.scad-project
    -> scans OpenSCAD dependencies
    -> defines build targets
    -> chooses incremental/cache policy
    -> invokes SCons

consumer project
    -> supplies project.yml and CAD sources
```

Do not move OpenSCAD dependency scanning or project-specific cache-key policy
into this Docker repository.

The initial `tool.scad-project` prototype proved that SCons `CacheDir` can
restore complete build outputs on clean GitHub runners and selectively rebuild
only targets affected by transitive `use`/`include` dependencies. That proof is
tracked in `tool.scad-project` issue #6 and draft PR #7.

## PR image validation

Starting with v0.4.1, Docker-changing pull requests must build and smoke-test a
local candidate image before merge. PR builds must **not** publish to GHCR or
trigger the external consumer repository.

After merge to `main`, the authoritative build publishes mutable `:edge`, runs
the same internal smoke test and dispatches `docker.scad-toolchain.test`.

## Release policy

The `0.x` line is experimental and uses semantic-style versioning. Released Git
and container tags are immutable. Never rebuild/re-push an existing release
with changed contents.

Use the permanent release workflow:

```text
.github/workflows/release.yml
```

Do not create temporary one-shot release workflows for normal releases.
The workflow takes:

```text
version
    immutable tag, e.g. v0.4.1

release_sha
    exact already-verified commit SHA
```

It validates the requested version against `versions.env`, refuses existing
tags, creates an annotated tag on the explicit SHA and dispatches the normal
build workflow on that tag.

## Mandatory release sequence

Do not skip or reorder these gates:

```text
1. Pull request candidate
   -> local Docker image build
   -> internal smoke PASS

2. Merge to docker.scad-toolchain main
   -> publish :edge
   -> internal smoke PASS

3. Automatic docker.scad-toolchain.test dispatch
   -> test toolchain_version=edge
   -> external consumer suite PASS

4. Release immutable docker.scad-toolchain vX.Y.Z
   -> publish :vX.Y.Z
   -> internal smoke PASS

5. Automatic docker.scad-toolchain.test dispatch
   -> test toolchain_version=vX.Y.Z
   -> external consumer suite PASS

6. Release matching immutable test-suite tag
   test-vX.Y.Z-toolchain-vX.Y.Z
   -> external suite PASS
   -> permanent Pages evidence published

7. Only then update downstream consumers such as tool.scad-project
```

Do not call a toolchain release fully verified merely because the Docker tag
exists or because `:edge` passed.

## External consumer trigger

The producer build workflow dispatches
`docker.scad-toolchain.test/.github/workflows/test.yml` only after published
`main`/tag images pass internal smoke tests. Pull requests intentionally skip
this dispatch.

Version selection:

```text
main build -> edge
tag build  -> same immutable v* version
```

The cross-repository dispatch uses `SCAD_TOOLCHAIN_TEST_TOKEN`, limited to the
external test repository and Actions permission.

## Repository responsibilities

```text
docker.scad-toolchain
    -> generic runtime image
    -> internal smoke tests

docker.scad-toolchain.test
    -> real external consumer validation
    -> verification reports / Pages evidence

tool.scad-project
    -> reusable project build orchestration
```

A capability is not fully proven merely because its binary exists in the image.
Keep internal smoke tests small; broader consumer behavior belongs in
`docker.scad-toolchain.test`.

## BOSL2 / PythonSCAD rules

BOSL2 is installed under `/opt/openscad-libraries/BOSL2` and exposed through:

```text
OPENSCADPATH=/opt/openscad-libraries
BOSL2_ROOT=/opt/openscad-libraries/BOSL2
```

Use `std.scad` as the BOSL2 entrypoint:

```text
OpenSCAD:
    include <BOSL2/std.scad>

PythonSCAD osuse() experiments:
    BOSL2_ROOT/std.scad
```

Do not use `shapes3d.scad` as a shortcut entrypoint. PythonSCAD `osuse()` needs
an actual filesystem path and must not be assumed to search `OPENSCADPATH`.

`pybosl2` is a separate Python port, not a wrapper around the installed BOSL2
SCAD tree. It is installed under `/opt/python-libs`. System Python receives that
path via `PYTHONPATH`; PythonSCAD consumers currently need to add it explicitly
to `sys.path`.

Do not name consumer scripts `pybosl2.py`, because that shadows the installed
package. Keep the explicitly pinned Shapely dependency: pybosl2 0.6.7 imports
it from its geometry/path stack.

PythonSCAD remains an available experimental capability. Do not weaken
object-oriented OpenSCAD library APIs merely to work around PythonSCAD boundary
limitations.

## OpenSCAD documentation tooling

The image includes pinned `openscad_docsgen` and exposes:

```text
openscad-docsgen
openscad-mdimggen
```

Keep API/source docs and visual design docs separate:

```text
docsgen comments -> API/source reference
design.md        -> design intent and visual construction
```

A docsgen-parsed `.scad` file must start structured documentation with
`// File:` or `// LibFile:` before Module/Function/Constant blocks. Internal
smoke coverage must prove parsing and real Markdown generation, not just command
existence.

## Lightweight image post-processing

`scad-image-watermark` is deliberately narrow generic functionality. The
Docker image provides the operation; `tool.scad-project` decides when to use it
and the consumer supplies watermark policy/text. Keep a real PNG smoke test.

## Change discipline

Before changing downstream consumers:

1. change this toolchain through a PR;
2. prove the candidate image locally in PR CI;
3. merge and prove `:edge` internally and externally;
4. publish a new immutable version;
5. prove the immutable image in `docker.scad-toolchain.test` and preserve
   permanent tagged evidence;
6. only then update downstream CAD repositories deliberately.
