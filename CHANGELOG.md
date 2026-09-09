# Changelog

This file records the functional history of released
`docker.scad-toolchain` versions.

Dependency pins for the current source tree live in `versions.env`.
Released Git and container tags are immutable.

## Version overview

| Version | Main change |
| --- | --- |
| `v0.4.0` | Lightweight PNG watermark tooling and automatic external-test triggering |
| `v0.3.0` | OpenSCAD documentation tooling |
| `v0.2.0` | BOSL2, pybosl2 and supporting Python geometry dependencies |
| `v0.1.2` | Git added to the runtime |
| `v0.1.1` | Stable public `openscad` command |
| `v0.1.0` | Initial OpenSCAD/PythonSCAD toolchain |

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
