# Do not name this file pybosl2.py: that would shadow the installed
# pybosl2 package on Python's import path and cause a circular import.

import sys

# PythonSCAD embeds CPython and does not reliably inherit the container's
# PYTHONPATH. External packages installed by this toolchain live here.
sys.path.insert(0, "/opt/python-libs")

from pythonscad import *
from pybosl2 import cuboid

part = cuboid([30, 20, 10], rounding=3)
part.show()
