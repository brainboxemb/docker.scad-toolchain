#!/usr/bin/env bash
set -euo pipefail

ROOT="/work"
OUT="/tmp/scad-toolchain-test"
PROFILE="${SCAD_TOOLCHAIN_PROFILE:-unknown}"

scad-toolchain-info

echo
echo "== Runtime profile =="
printf 'SCAD_TOOLCHAIN_PROFILE=%s\n' "$PROFILE"
case "$PROFILE" in
  openscad|full) ;;
  *)
    echo "ERROR: unsupported SCAD_TOOLCHAIN_PROFILE=${PROFILE}" >&2
    exit 1
    ;;
esac

echo
echo "== Open-source acknowledgment documents =="
ACK_ROOT="/usr/share/doc/scad-toolchain"
for path in \
  "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.txt" \
  "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.pdf" \
  "${ACK_ROOT}/DIRECT_LICENSE_FILES.txt" \
  "${ACK_ROOT}/DEBIAN_PACKAGES.txt" \
  "${ACK_ROOT}/PYTHON_DISTRIBUTIONS.txt"
do
  test -s "${path}"
done

grep -q 'SCAD TOOLCHAIN - OPEN SOURCE ACKNOWLEDGMENTS' \
  "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.txt"
grep -q "Runtime profile   : ${PROFILE}" \
  "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.txt"
head -c 8 "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.pdf" | grep -q '%PDF-1.4'
tail -c 64 "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.pdf" | grep -q '%%EOF'

ACK_TXT="${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.txt"
DEBIAN_INVENTORY="${ACK_ROOT}/DEBIAN_PACKAGES.txt"
PYTHON_INVENTORY="${ACK_ROOT}/PYTHON_DISTRIBUTIONS.txt"

if grep -Eq '^OpenSCAD package[[:space:]]*: [$]' "${ACK_TXT}"; then
  echo "ERROR: malformed OpenSCAD package version in acknowledgments." >&2
  exit 1
fi

grep -Eq '^openscad-nightly[[:space:]]' "${DEBIAN_INVENTORY}"
grep -Eiq '^openscad[-_]docsgen[[:space:]]' "${PYTHON_INVENTORY}"
grep -Eiq '^Pillow[[:space:]]' "${PYTHON_INVENTORY}"
grep -Eiq '^SCons[[:space:]]' "${PYTHON_INVENTORY}"
if [[ "$PROFILE" == "full" ]]; then
  grep -Eiq '^pybosl2[[:space:]]' "${PYTHON_INVENTORY}"
  grep -Eiq '^Shapely[[:space:]]' "${PYTHON_INVENTORY}"
fi
printf 'Acknowledgments: %s and %s\n' \
  "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.txt" \
  "${ACK_ROOT}/OPEN_SOURCE_ACKNOWLEDGMENTS.pdf"

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
echo "== openscad-new-dimensions SVG smoke test =="
test -n "${OPENSCAD_NEW_DIMENSIONS_ROOT:-}"
test -n "${OPENSCAD_NEW_DIMENSIONS_COMMIT:-}"
test -f "${OPENSCAD_NEW_DIMENSIONS_ROOT}/dimensions.scad"

echo "Public declarations in dimensions.scad:"
grep -E '^[[:space:]]*(module|function)[[:space:]]+' \
  "${OPENSCAD_NEW_DIMENSIONS_ROOT}/dimensions.scad" \
  | head -n 40 || true

openscad \
  -o "$OUT/openscad-new-dimensions.svg" \
  "$ROOT/test/dimensions_2d.scad"

test -s "$OUT/openscad-new-dimensions.svg"
grep -qi '<svg' "$OUT/openscad-new-dimensions.svg"
printf 'openscad-new-dimensions=%s\n' "$OPENSCAD_NEW_DIMENSIONS_COMMIT"

if [[ "$PROFILE" == "full" ]]; then
  echo
  echo "== pybosl2 Python dependencies =="
  PYTHONPATH="${PYTHONPATH:-/opt/python-libs}" \
    python3 -c 'import pybosl2, shapely; print("pybosl2 + Shapely imports OK")'

  echo
  echo "== PythonSCAD smoke test =="
  command -v pythonscad >/dev/null
  pythonscad --version >/dev/null 2>&1 || pythonscad --help >/dev/null 2>&1

  echo
  echo "== PythonSCAD + pybosl2 smoke test =="
  xvfb-run -a pythonscad \
    --trust-python \
    -o "$OUT/pybosl2.stl" \
    "$ROOT/test/pybosl2_smoke.py"
  test -s "$OUT/pybosl2.stl"
else
  echo
  echo "== PythonSCAD-specific smoke tests =="
  echo "Skipped for OpenSCAD-focused runtime."
fi

echo
echo "== OpenSCAD docsgen smoke test =="
command -v openscad-docsgen >/dev/null
command -v openscad-mdimggen >/dev/null

DOCSGEN_SOURCE="$ROOT/test/docsgen.scad"
DOCSGEN_GENERATED="${DOCSGEN_SOURCE}.md"

openscad-docsgen \
  -m \
  -T \
  "$DOCSGEN_SOURCE"

rm -f "$DOCSGEN_GENERATED"
openscad-docsgen \
  -m \
  "$DOCSGEN_SOURCE"

test -s "$DOCSGEN_GENERATED"
grep -q "docsgen_smoke" "$DOCSGEN_GENERATED"
rm -f "$DOCSGEN_GENERATED"

echo "openscad-docsgen parse + generation OK"

echo
echo "Smoke test passed for ${PROFILE} runtime."
