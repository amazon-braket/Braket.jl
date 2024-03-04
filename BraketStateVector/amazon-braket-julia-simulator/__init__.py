# This must be imported as early as possible to prevent
# library linking issues caused by numpy/pytorch/etc. importing
# old libraries:
from .julia_import import jl, BraketStateVector  # isort:skip

# This file is created by setuptools_scm during the build process:
from .version import __version__

__all__ = [
    "jl",
    "BraketStateVector",
    "braket_sv",
    "amazon-braket-julia-simulator",
    "__version__",
]
