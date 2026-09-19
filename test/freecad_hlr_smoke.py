#!/usr/bin/env python3
"""Headless FreeCAD TechDraw HLR smoke test for the drawing runtime."""

from __future__ import annotations

import os
from pathlib import Path

import FreeCAD as App
import Part
import TechDraw


output = Path(os.environ["FREECAD_HLR_OUT"])
output.parent.mkdir(parents=True, exist_ok=True)

# A shallow top pocket gives the top view an outer silhouette plus real visible
# internal hard edges, so this validates actual HLR rather than command startup.
shape = Part.makeBox(20, 20, 6).cut(
    Part.makeBox(8, 8, 3, App.Vector(6, 6, 3))
)

projection = TechDraw.project(shape, App.Vector(0, 0, 1))
visible_edges = sum(len(group.Edges) for group in projection[:2])
hidden_edges = sum(len(group.Edges) for group in projection[2:])

if visible_edges < 8:
    raise RuntimeError(
        f"unexpectedly small visible HLR edge set: {visible_edges}"
    )

svg = TechDraw.projectToSVG(shape, App.Vector(0, 0, 1))
if "<path" not in svg:
    raise RuntimeError("TechDraw HLR SVG contains no path geometry")

marker = (
    f"<!-- FREECAD_HLR visible_edges={visible_edges} "
    f"hidden_edges={hidden_edges} -->\n"
)

if "<svg" in svg:
    svg = svg.replace(">", ">\n" + marker, 1)
else:
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" version="1.1">\n'
        + marker
        + svg
        + "\n</svg>\n"
    )

output.write_text(svg, encoding="utf-8")
print(
    "FreeCAD TechDraw HLR validated: "
    f"visible_edges={visible_edges}, hidden_edges={hidden_edges}"
)
