# Changelog

This file records the functional history of released
`docker.scad-toolchain` versions.

Dependency pins for the current source tree live in `versions.env`.
Released Git and container tags are immutable.

## Version overview

| Version | Main change |
| --- | --- |
| `v0.5.1` | Pinned OpenSCAD dimensioning library with SVG smoke coverage |
| `v0.5.0` | Capability-focused OpenSCAD and full/dual runtime image family |
| `v0.4.1` | Pinned SCons build engine and pre-merge Docker image validation |
| `v0.4.0` | Lightweight PNG watermark tooling and automatic external-test triggering |
| `v0.3.0` | OpenSCAD documentation tooling |
| `v0.2.0` | BOSL2, pybosl2 and supporting Python geometry dependencies |
| `v0.1.2` | Git added to the runtime |
| `v0.1.1` | Stable public `openscad` command |
| `v0.1.0` | Initial OpenSCAD/PythonSCAD toolchain |

## v0.5.1

### Added

- Pinned `adrien-delhorme/openscad-new-dimensions` directly from Codeberg at
  commit `d37828e26df6067fbd872e8e291c6b0b19298243`.
- Shared installation under `/opt/openscad-libraries/openscad-new-dimensions`
  in both runtime profiles.
- Public `OPENSCAD_NEW_DIMENSIONS_ROOT` and
  `OPENSCAD_NEW_DIMENSIONS_COMMIT` diagnostics.
- Internal smoke coverage that exports the upstream dimension-library demo to
  SVG with OpenSCAD.

### Purpose

Dimensioned 2D drawings are a generic OpenSCAD runtime capability. Consumer
projects should derive drawing geometry from their CAD source and use this
shared library for annotations instead of vendoring or mirroring the Codeberg
repository independently.

## v0.5.0

### Added

- A dedicated OpenSCAD-focused runtime published as
  `ghcr.io/brainboxemb/scad-toolchain-openscad:<version>`.
- Explicit runtime profile reporting through `SCAD_TOOLCHAIN_PROFILE` and
  `scad-toolchain-info`.
- Build and smoke coverage for both runtime profiles from the same source tree.

### Changed

- The Dockerfile is now a shared multi-stage image family:
  - `openscad` contains OpenSCAD, BOSL2, docsgen, Pillow/watermark, SCons and
    the shared system/runtime tooling;
  - `full` extends that stage with PythonSCAD, pybosl2, Shapely and their
    PythonSCAD-specific dependencies.
- The existing `ghcr.io/brainboxemb/scad-toolchain:<version>` package remains
  the full/dual runtime for backwards compatibility.
- Python-only CAD dependencies are no longer distributed to consumers that
  need only the OpenSCAD capability set.

### Verification

Migration 005 qualified the two profiles externally before release preparation.
The controlled candidate measurement found:

- OpenSCAD profile: 328,098,501 compressed OCI bytes;
- full profile: 449,516,893 compressed OCI bytes;
- reduction for OpenSCAD-only consumers: 121,418,392 bytes, about 27.0%.

Both profiles passed the shared OpenSCAD/BOSL2/SCons/docs/watermark contract.
The full profile additionally passed PythonSCAD/pybosl2 coverage and retained
existing interoperability XFAIL expectations.

The release is complete only after the immutable `v0.5.0` images are externally
qualified and the matching immutable test-suite record
`test-v0.5.0-toolchain-v0.5.0` is green.

## v0.4.1

### Added

- Pinned SCons 4.11.1 as a generic public build-engine capability.
- SCons version reporting through `scad-toolchain-info`.
- Internal smoke coverage for the `scons` command and pinned package version.
- Pull-request Docker builds that load and smoke-test the candidate image
  locally without publishing it or triggering external consumer tests.

### Purpose

SCons is provided as generic runtime capability. Dependency policy, OpenSCAD
source scanning, target selection and cache policy remain owned by
`tool.scad-project` rather than this image.

## v0.4.0

### Added

- Pinned Pillow runtime dependency for lightweight image post-processing.
- Public `scad-image-watermark` command.
- Functional internal watermark smoke test.
- Automatic cross-repository trigger of `docker.scad-toolchain.test` after a
  successful published-image smoke test.

### Verification

- `main` publishes and externally verifies `:edge`.
- The immutable toolchain tag `v0.4.0` must be externally verified after it is
  published.
- The matching immutable verification record is:
  `test-v0.4.0-toolchain-v0.4.0`.

## v0.3.0

### Added

- Pinned `openscad_docsgen` package.
- Public `openscad-docsgen` command.
- Public `openscad-mdimggen` command.
- Internal functional docsgen smoke coverage.

## v0.2.0

### Added

- BOSL2 for native OpenSCAD use.
- pybosl2 for Python/PythonSCAD experiments.
- Pinned Shapely runtime dependency required by pybosl2 geometry/path code.
- Public `BOSL2_ROOT` filesystem location alongside `OPENSCADPATH`.
- Functional BOSL2 and pybosl2 smoke coverage.

## v0.1.2

### Added

- Git as a public runtime dependency and command.
- Git coverage in toolchain diagnostics/smoke tests.

## v0.1.1

### Changed

- Exposed a stable public `openscad` command instead of requiring consumers to
  know the internal OpenSCAD installation path.

## v0.1.0

### Added

- Initial shared Docker runtime for reproducible OpenSCAD and PythonSCAD builds.
- PythonSCAD 1.1.2 pin.
- Basic toolchain information and smoke-test support.
