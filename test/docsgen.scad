//////////////////////////////////////////////////////////////////////
// Module: docsgen_smoke()
//
// Description:
//   Minimal module used to verify openscad-docsgen in the toolchain.
//
// Arguments:
//   size = Side length of the generated cube.
//////////////////////////////////////////////////////////////////////
module docsgen_smoke(size = 10) {
    cube(size);
}

docsgen_smoke();
