# Do not name this file pybosl2.py: that would shadow the installed
# pybosl2 package on Python's import path and cause a circular import.

from pythonscad import *
from pybosl2 import cuboid

part = cuboid([30, 20, 10], rounding=3)
part.show()
