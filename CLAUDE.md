# Geode

Computational geometry library (PhysBAM lineage). C++ core with Python bindings.

## Building

### With CMakePresets (preferred)

```bash
cmake --preset dev          # configure (native arch, Python on, RelWithDebInfo)
cmake --build --preset dev  # build using all cores
```

Available presets:

| Preset | Description |
|--------|-------------|
| `dev` | Native arch, Python on, RelWithDebInfo — daily development |
| `dev-no-python` | Native arch, no Python — fast C++ iteration |
| `release` | Native arch, Python on, Release |
| `ci` | No `-march=native` (portable binary), Python optional |

Each preset builds into `build/<presetName>`. All presets emit `compile_commands.json` for clangd/LSP.

### Manual

```bash
mkdir build && cd build
cmake .. -DGEODE_DISABLE_PYTHON=ON   # C++ only
cmake .. -DGEODE_DISABLE_PYTHON=OFF  # with Python 3 bindings
make -j$(sysctl -n hw.ncpu)
```

### Dependencies

Run the installer script (detects macOS/Debian automatically):
```bash
bash scripts/install_deps.sh
source .venv/bin/activate
```

Or manually on macOS:
```bash
brew install cmake gmp open-mesh libpng libjpeg
python3 -m venv .venv && source .venv/bin/activate
pip install numpy pytest pytest-forked scipy
```

Or manually on Ubuntu/Debian:
```bash
sudo apt install cmake libgmp-dev libopenmesh-dev libpng-dev libjpeg-dev python3-venv
python3 -m venv .venv && source .venv/bin/activate
pip install numpy pytest pytest-forked scipy
```

## Running tests

```bash
cd build          # or build/dev if using presets
python3 -m pytest --forked --tb=short
```

- Must run from the build directory so `geode/math/__init__.py` doesn't shadow stdlib `math`
- `--forked` is still required for process isolation (some tests use random seeds and SIGABRT would kill the runner)
- `setup.cfg` uses `[tool:pytest]` section
- **Expected results: 166 passed, 0 failed, 1 skipped** (as of native ARM64 build)

### Skipped tests
- `test_worker`: Worker inter-process tests were never completed (skipped since 2017); `Worker.py` is unused elsewhere in the codebase
- OpenMesh tests: `openmesh_enabled()` returns False when OpenMesh is not installed

## CMake build system

### Key options

| Option | Default | Description |
|--------|---------|-------------|
| `GEODE_DISABLE_PYTHON` | OFF | Skip Python bindings entirely |
| `GEODE_REQUIRE_PYTHON` | OFF | Fail if Python bindings can't be built |
| `GEODE_NATIVE_ARCH` | ON | Pass `-march=native -mtune=native`; set OFF for CI/packaging/cross-compile |

### OpenMesh is optional

OpenMesh is detected but not required. If not found, cmake emits a `WARNING` (not a fatal error) listing the specific functions that become unavailable:

> TriMesh, decimate_openmesh, mean_curvatures, gaussian_curvatures,
> triangulate_face, visualize, floodfill

All OpenMesh usage in the C++ source is guarded with `#ifdef GEODE_OPENMESH`. The `openmesh_enabled()` Python function returns False when not compiled in. This is intentional: the warning is loud enough to be noticed, but the build succeeds so other functionality is available.

If you need to enforce OpenMesh is present, there is no `GEODE_REQUIRE_OPENMESH` option yet — the workaround is to check for the warning in cmake output.

### GMP detection order

1. `find_library(gmp)` with Homebrew and multiarch hints (preferred — resolves full path)
2. pkg-config fallback for non-standard installs

### Linux multiarch paths

`find_library` and `find_path` include `/usr/lib/aarch64-linux-gnu` and `/usr/lib/x86_64-linux-gnu` so the build works on Debian/Ubuntu ARM64 and x86_64 without extra cmake flags.

## ARM64 / NEON support

Geode runs natively on ARM64 (Apple Silicon and Linux aarch64) with full SIMD performance via **sse2neon** (`geode/math/sse2neon.h`), a vendored single-header MIT library that maps the full SSE/SSE2/SSE4.1 intrinsic API to ARM NEON.

### How it works

- CMake detects ARM64 via `CMAKE_SYSTEM_PROCESSOR` and sets `GEODE_NEON`
- `GEODE_NEON` is propagated as a compile definition to all modules and written to `geode/config.h` via `config.h.in`
- `geode/utility/config.h`: when `GEODE_NEON` is defined, `GEODE_SSE` and `GEODE_SSE4_1` are both defined unconditionally, and the x86 compiler-flag validation block is skipped
- `geode/math/sse.h`, `geode/math/max.h`, `geode/math/min.h`: include `sse2neon.h` instead of `xmmintrin.h` etc. when `GEODE_NEON` is defined
- `Interval.h` uses the fast SSE4.1 path on ARM64 — `float64x2_t` is a native hardware type, not emulated

### FP exception control on macOS ARM64

macOS doesn't provide `feenableexcept`/`fedisableexcept`. On x86 these were implemented via MXCSR through xmmintrin.h. On ARM64 they're implemented via the FPCR register using `mrs`/`msr fpcr` inline assembly (`geode/utility/process.cpp`).

### random123 on ARM64

`R123_USE_GNU_UINT128` is enabled on `__aarch64__` in addition to `__x86_64__`. The SSE counter type (`r123m128i`) remains disabled because `R123_USE_SSE` checks `__SSE2__`, which is not defined natively on ARM64 (sse2neon provides the API but not the preprocessor macro — intentional).

## Architecture
- `geode/` contains modules: array, exact, force, geometry, image, math, mesh, openmesh, python, random, solver, structure, svg, utility, value, vector
- Each module has a `CMakeLists.txt` using `ADD_GEODE_MODULE` macro (defined in `GeodeSupport.cmake`)
- Python bindings use a custom C API layer (not pybind11/boost.python). Key files: `geode/python/Class.h`, `module.h`, `module.cpp`
- `GEODE_DEFINE_TYPE` macro creates PyTypeObject structs; `GEODE_PYTHON_MODULE` macro creates module init functions
- `PyTypeObject` initializers use C99 designated initializers (ported from positional for Python 3.12+ compat)

## Python conventions

### Namespace collision with numpy

`from geode import *` transitively imports numpy into the caller's namespace, which shadows several Python built-ins: `max`, `min`, `abs`, `sum`, `round`, and others.

**Pattern:** Any file that uses `from geode import *` and needs a Python built-in that numpy shadows must import it explicitly:

```python
import builtins

# Wrong -- calls numpy.max(a, axis, out) positionally:
e = max(e, maxabs(x), abs(y))

# Correct:
e = builtins.max(e, maxabs(x), abs(y))
```

This applies to test files and library code alike. The numpy versions accept different argument shapes and have stricter type requirements (especially `out` parameter in numpy 2.x), so relying on duck-typing across numpy versions is fragile.

## C++ / Python string binding
- `from_python<string>` accepts both `PyBytes` and `PyUnicode` (Latin-1 decode for str)
- `to_python<string>` uses `PyUnicode_DecodeLatin1` for byte-transparent round-trip
- This means C++ `std::string` with arbitrary bytes survives the Python round-trip via Latin-1 encoding

## Porting history (2026)
Originally built on x86 Linux/macOS with Python 2. Build system was SCons; migrated to CMake when SCons became insufficient for managing third-party dependencies. Ported to:
- **macOS Apple Silicon (ARM64) native**: SSE → NEON via sse2neon, FPCR-based FP exception control, ARM64 multiarch cmake paths, `GEODE_NEON` feature flag, CMakePresets.json (commit 581329f)
- macOS Apple Silicon (ARM64) under Rosetta 2: conditional `GEODE_SSE`, aarch64 in Random123, Accelerate.framework gate (earlier port, now superseded)
- Python 3.14: PyInt->PyLong, PyString->PyUnicode, PyModule_Create, PyInit_ entry points, numpy 2.x API
- Python 2->3 runtime: xrange, except syntax, map/filter iterators, cPickle/cStringIO, builtin shadowing by numpy, tryfile str->bytes, cache_method name mangling, uint128 unsigned conversion
- C++17, modern CMake (3.5+), Homebrew `/usr/local/` and `/opt/homebrew/` paths
