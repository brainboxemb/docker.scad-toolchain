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

echo
echo "== SCons smoke test =="
command -v scons >/dev/null
scons --version >/dev/null
python3 - <<'PY'
import importlib.metadata as metadata
import os

actual = metadata.version("SCons")
expected = os.environ["SCONS_VERSION"]
assert actual == expected, f"SCons version mismatch: {actual} != {expected}"
print(f"SCons {actual} validated")
PY

mkdir -p "$OUT"

echo
echo "== OpenSCAD smoke test =="
openscad -o "$OUT/smoke.stl" "$ROOT/test/smoke.scad"
test -s "$OUT/smoke.stl"

echo
echo "== Image watermark smoke test =="
command -v scad-image-watermark >/dev/null
xvfb-run -a openscad \
  --render \
  --imgsize=640,480 \
  -o "$OUT/watermark-input.png" \
  "$ROOT/test/smoke.scad"
test -s "$OUT/watermark-input.png"

scad-image-watermark \
  "$OUT/watermark-input.png" \
  "$OUT/watermark-output.png" \
  --text "© 2026 brainboxemb"

test -s "$OUT/watermark-output.png"
if cmp -s "$OUT/watermark-input.png" "$OUT/watermark-output.png"; then
  echo "ERROR: watermark output is identical to its input." >&2
  exit 1
fi

python3 - "$OUT/watermark-output.png" <<'PY'
from pathlib import Path
import sys
from PIL import Image

path = Path(sys.argv[1])
with Image.open(path) as image:
    assert image.format == "PNG"
    assert image.size == (640, 480)
print("watermark PNG validated")
PY

echo
echo "== BOSL2_ROOT public path =="
test -n "${BOSL2_ROOT:-}"
test -f "${BOSL2_ROOT}/std.scad"
test -f "${BOSL2_ROOT}/shapes3d.scad"
printf 'BOSL2_ROOT=%s\n' "$BOSL2_ROOT"

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
echo "== OpenSCAD docsgen smoke test =="
command -v openscad-docsgen >/dev/null
command -v openscad-mdimggen >/dev/null

DOCSGEN_SOURCE="$ROOT/test/docsgen.scad"
DOCSGEN_GENERATED="${DOCSGEN_SOURCE}.md"

# Test-only mode acts as the source documentation lint check.
openscad-docsgen \
  -m \
  -T \
  "$DOCSGEN_SOURCE"

# Generate one real Markdown file as a functional smoke test.
rm -f "$DOCSGEN_GENERATED"
openscad-docsgen \
  -m \
  "$DOCSGEN_SOURCE"

test -s "$DOCSGEN_GENERATED"
grep -q "docsgen_smoke" "$DOCSGEN_GENERATED"

# This is generated test output, not repository source.
rm -f "$DOCSGEN_GENERATED"

echo "openscad-docsgen parse + generation OK"

echo
echo "Smoke test passed."
