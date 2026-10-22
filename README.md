Geode: The Otherlab computational geometry library
==================================================

Geode is an open source library of computational geometry and associated mathematical utilities
together with a fast, lightweight python binding layer.  The license is standard three-clause BSD
(see the included `LICENSE` file or [LICENSE](https://github.com/otherlab/core/blob/master/LICENSE)).

For questions or discussion, email geode-dev@googlegroups.com.

### Dependencies

For C++:

* [cmake >= 3.25](https://cmake.org): A build system (BSD)
* [gmp >= 6](http://gmplib.org): Arbitrary precision arithmetic (LGPL)
* [libpng >= 1.6](http://www.libpng.org): Lossless image format (optional)
* [libjpeg-turbo](https://libjpeg-turbo.org): Lossy image format (optional)
* [OpenMesh >= 11](https://www.graphics.rwth-aachen.de/software/openmesh/): Half-edge meshes (optional)

For Python:

* [python >= 3.10](http://python.org): A scripting language (Python Software Foundation (PSF) license)
* [numpy >= 2](http://numpy.org): Efficient multidimensional arrays for Python (BSD license)

Optional, for the tests: pytest >= 9, pytest-forked < 2, scipy (see `requirements.txt`).

Geode makes extensive use of C++11 features, so a relatively recent C++ compiler is necessary.

### Windows

Build with MSYS2 MINGW64 (see `.github/workflows/ci.yml` for the package list) and `cmake --preset windows`.

### Installation

Dependencies can be installed via one of

    # Debian/Ubuntu
    sudo apt install cmake g++ python3-dev python3-venv pkg-config libjpeg-dev libpng-dev libgmp-dev libopenmesh-dev

    # Homebrew
    brew install cmake gmp libpng jpeg-turbo open-mesh python

    # then, on either
    python3 -m venv .venv && source .venv/bin/activate
    pip install -r requirements.txt

Geode can then be built from source via

    git clone https://github.com/otherlab/geode.git
    cd geode
    cmake --preset dev && cmake --build --preset dev

The libraries are built into `build/dev`; point `PYTHONPATH` there (or at the build tree's `geode` directory) to import
them without installing.  To link against the built tree from another CMake project:

    include(path/to/geode/CMakeLists.txt)
    target_link_libraries(foo geode)

### Post install

On linux you may have to update the shared library cache via ldconfig if this is the first time you've installed. Make sure /usr/local/lib (or wherever you installed libgeode.so) is included in the cache's search path.

### Testing

Unit tests can be run via

    cd build/dev
    python -m pytest --forked

### Extra configuration

If additional build configuration is necessary, run ccmake instead of cmake.
CMake includes documentation generated from the geode build system.

For developers wishing to use without installing, see more options in Developer mode section below

These options can also be passed via command line to cmake.  Run `ccmake` for a complete list.
Use `CMAKE_BUILD_TYPE=Debug` for a much slower build with many more assertions:

    cmake -DCMAKE_BUILD_TYPE=Debug

### Acknowledgements

Parts of geode come from the [PhysBAM simulation library](http://physbam.stanford.edu) developed by
Ron Fedkiw et al. at Stanford University.

For random numbers, we use the [Random123 library](http://www.deshawresearch.com/resources_random123.html) of
John Salmon et al. at D. E. Shaw Research.  Random123 is included inline in `core/random/random123`.

The interval arithmetic in `exact/Interval` is based on code by [Robert Bridson](http://www.cs.ubc.ca/~rbridson)
and [Tyson Brochu](http://www.cs.ubc.ca/~tbrochu).

