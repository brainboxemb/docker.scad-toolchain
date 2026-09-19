// Smoke-test the shared Codeberg dimension library in a true 2D OpenSCAD
// entrypoint. The runtime test only owns availability + SVG export; consumer
// drawings own the actual annotation choices.
include <openscad-new-dimensions/dimensions.scad>

square([10, 6], center = true);
