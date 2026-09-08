// File: docsgen.scad
//   Minimal OpenSCAD source used to verify openscad-docsgen in the
//   published SCAD toolchain.
//
// FileSummary: Minimal openscad-docsgen smoke-test source.
//
// Module: docsgen_smoke()
// Usage:
//   docsgen_smoke();
//   docsgen_smoke(size=12);
// Description:
//   Creates a cube for the documentation generator smoke test.
// Arguments:
//   size = Side length of the generated cube.
module docsgen_smoke(size = 10) {
    cube(size);
}

docsgen_smoke();
