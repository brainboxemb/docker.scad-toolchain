#!/usr/bin/env bash
set -euo pipefail

scad-toolchain-info
mkdir -p /tmp/scad-toolchain-test

OPENSCAD_BIN="$(command -v openscad-nightly || command -v openscad)"
"$OPENSCAD_BIN" -o /tmp/scad-toolchain-test/smoke.stl /work/test/smoke.scad

test -s /tmp/scad-toolchain-test/smoke.stl
pythonscad --version >/dev/null 2>&1 || pythonscad --help >/dev/null 2>&1

echo "Smoke test passed."
