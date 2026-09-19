#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

import drawsvg as draw


def main() -> None:
    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)

    sheet = draw.Drawing(297, 210, origin=(0, 0))
    sheet.append(draw.Rectangle(
        10, 10, 277, 190,
        fill="white",
        stroke="black",
        stroke_width=0.35,
    ))
    sheet.append(draw.Text(
        "DRAWING RUNTIME",
        5,
        20,
        25,
        fill="black",
        font_family="DejaVu Sans",
    ))
    sheet.append(draw.Line(
        35, 55, 140, 55,
        stroke="black",
        stroke_width=0.35,
    ))
    sheet.append(draw.Text(
        "105",
        4,
        87.5,
        50,
        center=True,
        fill="black",
        font_family="DejaVu Sans",
    ))
    sheet.save_svg(str(output))


if __name__ == "__main__":
    main()
