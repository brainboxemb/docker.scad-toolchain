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
scad-image-watermark
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
Pillow       12.3.0
```

OpenSCAD still comes from the official development-snapshot APT repository.
A released Docker image freezes the snapshot that was resolved during that
build.

## Release policy

The `0.x` line is experimental and uses semantic-style versioning.

Released image tags are immutable. Never rebuild/re-push an existing released
version with changed contents. Adding BOSL2/pybosl2 is a meaningful toolchain
capability change, so it belongs in the v0.2 line rather than replacing v0.1.2.

## Mandatory release sequence

A toolchain version is released through a **two-repository verification chain**.
Do not skip or reorder these gates.

Before starting the immutable release steps, update `CHANGELOG.md` with the
new release line. Keep historical version information there; do not reintroduce
version-by-version history throughout `README.md`.

For a release such as `v0.4.0`:

```text
1. docker.scad-toolchain main
   -> publish :edge
   -> internal smoke test must pass

2. automatic docker.scad-toolchain.test dispatch
   -> test toolchain_version=edge
   -> external consumer suite must pass

3. create immutable Git tag v0.4.0 in docker.scad-toolchain
   -> workflow publishes image :v0.4.0
   -> internal smoke test must pass against the published tagged image

4. automatic docker.scad-toolchain.test dispatch
   -> test toolchain_version=v0.4.0
   -> external consumer suite must pass against the immutable tagged image
   -> this workflow_dispatch result is published under mutable Pages /latest/

5. only after step 4 is green, create the immutable test-suite tag
   test-v0.4.0-toolchain-v0.4.0 in docker.scad-toolchain.test

6. the test-suite tag runs again against image :v0.4.0
   -> it must pass
   -> it publishes the permanent Pages evidence under:
      /test-v0.4.0-toolchain-v0.4.0/

7. only after the tagged test-suite run and permanent Pages publication are
   green should downstream repositories such as tool.scad-project be advanced
   to the new toolchain release
```

The `:edge` consumer test proves the release candidate. The automatic
`v0.4.0` consumer test proves the immutable image that was actually published.
The test-suite tag preserves that proof as permanent historical Pages evidence.

**Do not call a toolchain release fully verified merely because the Docker tag
exists or because `:edge` passed.** The immutable toolchain tag must pass the
external consumer suite, and its matching released test-suite report must be
published.

## Creating release tags from ChatGPT / connected GitHub

The connected GitHub tool may expose commit/branch operations without exposing a
direct create-tag operation. In that situation, do **not** ask the user to tag
manually if the repository can safely create the tag through GitHub Actions.

Use the proven one-shot workflow pattern.

For a release such as `v0.4.0`:

```text
1. determine the exact already-tested release commit SHA
2. create a temporary workflow on main:
   .github/workflows/_release-v0.4.0.yml
3. give that workflow:
   permissions:
     contents: write
4. have the workflow create an annotated tag on the explicit release SHA:
   git tag -a v0.4.0 "$RELEASE_SHA" -m "SCAD toolchain v0.4.0"
   git push origin refs/tags/v0.4.0
5. after pushing the tag, explicitly dispatch the normal build workflow on
   the new tag ref, for example build.yml with ref=v0.4.0
6. wait for the one-shot workflow to finish successfully
7. verify refs/tags/v0.4.0 exists and points to the intended release commit
8. verify the dispatched build runs with github.ref_type=tag and publishes the
   immutable :v0.4.0 image
9. immediately remove the temporary one-shot workflow from main
10. continue with the normal immutable-image and external-consumer release gates
```

Important safeguards:

- `RELEASE_SHA` must be the exact commit that already passed the intended
  `:edge` release-candidate verification.
- Never tag the temporary workflow commit itself unless that is intentionally
  the release content.
- Never use a branch named like a version as a substitute for a Git tag.
- Never move or overwrite an existing release tag.
- Remove the one-shot workflow after it has created the tag; it is release
  tooling, not permanent project infrastructure.
- A tag pushed with the repository `GITHUB_TOKEN` does not automatically
  trigger another workflow from the resulting push. The one-shot workflow must
  therefore explicitly dispatch the normal `build.yml` on the new tag ref.
- The dispatched normal `build.yml` remains authoritative for publishing and
  verifying the released image; do not duplicate Docker build logic in the
  one-shot workflow.

This same pattern was previously used successfully for
`tool.scad-project:v0.5.0` and is the preferred fallback when direct tag
creation is unavailable through the connected GitHub interface.

## Lightweight image post-processing

Toolchain v0.4.0 adds the public `scad-image-watermark` command.

Keep this capability narrow:

```text
Docker image
    generic PNG watermark operation

tool.scad-project
    decides when to call it and reads project configuration

consumer project
    supplies watermark text/policy
```

The implementation uses pinned Pillow rather than adding a broad/heavy graphics
suite. Preserve the existing subtle bottom-right label behavior unless a
separate requirement justifies expanding the public CLI.

The external toolchain test must render a real PNG and pass it through the
public command. Command existence alone is not sufficient evidence.

## Automatic external consumer trigger

After a successful published-image smoke test, the build workflow dispatches
`docker.scad-toolchain.test/.github/workflows/test.yml`.

Version selection is deliberate:

```text
main build
    -> test toolchain_version=edge

v* tag build
    -> test the same immutable v* toolchain version
```

The cross-repository dispatch uses the repository secret:

```text
SCAD_TOOLCHAIN_TEST_TOKEN
```

That fine-grained token should remain limited to the
`docker.scad-toolchain.test` repository with only GitHub Actions read/write
permission. It is a workflow-trigger credential, not a contents-write
credential.

Keep the external test repository independently runnable through its own push
and workflow_dispatch triggers; the producer-side trigger is an orchestration
link, not a code dependency.

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


## OpenSCAD documentation tooling

Toolchain `v0.3.0` includes the pinned PyPI package `openscad_docsgen`.

Public commands:

```text
openscad-docsgen
openscad-mdimggen
```

When `.scad` files contain structured API/source comments, prefer upstream
`openscad_docsgen` syntax.

Keep API/reference documentation and design documentation separate:

```text
docsgen comments -> API/source reference
design.md        -> design intent and visual construction
```

Internal smoke coverage must prove:
- both commands exist;
- docsgen test/lint mode parses a real `.scad` file;
- normal docsgen execution produces Markdown.


## BOSL2 / PythonSCAD compatibility note

Keep the BOSL2 entrypoint rule explicit:

```text
OpenSCAD:
    include <BOSL2/std.scad>

PythonSCAD osuse() experiments:
    BOSL2_ROOT/std.scad
```

Never use `shapes3d.scad` as the BOSL2 entrypoint. It relies on constants and
support modules loaded by `std.scad`.

The external toolchain test currently records direct
`PythonSCAD -> BOSL2 .scad` as an XFAIL because BOSL2 relies on OpenSCAD's
date-based `version_num()` runtime semantics.


### Docsgen file-header requirement

Every `.scad` source parsed by `openscad-docsgen` must start its structured
documentation with exactly one of:

```scad
// File: filename.scad
```

or:

```scad
// LibFile: filename.scad
```

before any `Module`, `Function`, `Constant`, `Section`, etc. block.

The internal smoke source `test/docsgen.scad` intentionally verifies this
minimal valid structure.


### Docsgen smoke output

The internal toolchain smoke test invokes `openscad-docsgen` directly on
`test/docsgen.scad`.

For the pinned docsgen version, the file-level `-m` smoke invocation produces:

```text
test/docsgen.scad.md
```

next to the source. The smoke test therefore verifies that exact generated
file is non-empty and contains the documented module name, then removes it.

Do not infer docsgen success from a custom `find` of an assumed output
directory. The test should validate the output that the invoked command
actually creates.

