// Minimal 2D source used to prove the drawing runtime pipeline.
$fn = 48;

difference() {
    square([40, 25], center = true);
    circle(d = 8);
}

translate([0, 18])
    text("SCAD DRAWING", size = 4, halign = "center");
