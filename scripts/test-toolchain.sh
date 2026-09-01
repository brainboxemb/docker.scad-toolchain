#!/usr/bin/env bash
set -euo pipefail

scad-toolchain-info


echo "== Git smoke test =="
command -v git >/dev/null
git --version

GIT_TEST_DIR="$(mktemp -d)"
git -C "$GIT_TEST_DIR" init -q
git -C "$GIT_TEST_DIR" config user.name "SCAD Toolchain Test"
git -C "$GIT_TEST_DIR" config user.email "scad-toolchain-test@example.invalid"
printf 'toolchain test\n' > "$GIT_TEST_DIR/test.txt"
git -C "$GIT_TEST_DIR" add test.txt
git -C "$GIT_TEST_DIR" commit -q -m "Git smoke test"
git -C "$GIT_TEST_DIR" rev-parse --verify HEAD >/dev/null
rm -rf "$GIT_TEST_DIR"

mkdir -p /tmp/scad-toolchain-test

OPENSCAD_BIN="$(command -v openscad-nightly || command -v openscad)"
"$OPENSCAD_BIN" -o /tmp/scad-toolchain-test/smoke.stl /work/test/smoke.scad

test -s /tmp/scad-toolchain-test/smoke.stl
pythonscad --version >/dev/null 2>&1 || pythonscad --help >/dev/null 2>&1

echo "Smoke test passed."
