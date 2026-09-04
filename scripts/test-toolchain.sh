#!/usr/bin/env bash
set -euo pipefail

ROOT="/work"
OUT="/tmp/scad-toolchain-test"

scad-toolchain-info

echo
echo "== Git smoke test =="
command -v git >/dev/null
git --version

GIT_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$GIT_TEST_DIR"' EXIT

git -C "$GIT_TEST_DIR" init -q
git -C "$GIT_TEST_DIR" config user.name "SCAD Toolchain Test"
git -C "$GIT_TEST_DIR" config user.email "scad-toolchain-test@example.invalid"
printf 'toolchain test\n' > "$GIT_TEST_DIR/test.txt"
git -C "$GIT_TEST_DIR" add test.txt
git -C "$GIT_TEST_DIR" commit -q -m "Git smoke test"
git -C "$GIT_TEST_DIR" rev-parse --verify HEAD >/dev/null

mkdir -p "$OUT"

echo
echo "== OpenSCAD smoke test =="
openscad -o "$OUT/smoke.stl" "$ROOT/test/smoke.scad"
test -s "$OUT/smoke.stl"

echo
echo "== BOSL2 OpenSCAD smoke test =="
openscad -o "$OUT/bosl2.stl" "$ROOT/test/bosl2.scad"
test -s "$OUT/bosl2.stl"

echo
echo "== pybosl2 Python dependencies =="
python3 -c 'import pybosl2, shapely; print("pybosl2 + Shapely imports OK")'

echo
echo "== PythonSCAD smoke test =="
pythonscad --version >/dev/null 2>&1 || pythonscad --help >/dev/null 2>&1

echo
echo "== PythonSCAD + pybosl2 smoke test =="
xvfb-run -a pythonscad \
  --trust-python \
  -o "$OUT/pybosl2.stl" \
  "$ROOT/test/pybosl2_smoke.py"
test -s "$OUT/pybosl2.stl"

echo
echo "Smoke test passed."
