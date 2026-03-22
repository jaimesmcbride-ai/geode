# Plan Windows — Geode Build Investigation

**Goal:** Attempt a build on Windows, collect errors, and document what needs fixing. Not necessarily a fully working build in one pass.

**This must run on the Windows machine** — cross-compiling from macOS is not practical.

## Context

The codebase has substantial Windows platform guards already: `process.cpp` Windows block (`GetProcessTimes`, `GetProcessMemoryInfo`), MSVC `__declspec(dllexport)` in `config.h`, MinGW-specific workarounds in `python/config.h` (`_hypot`, `MS_WIN64`, `gnu_printf`), MSVC operator overloads in `sse.h`, `_alloca` in `array/alloca.h`, `__popcnt` in `math/popcount.h`. However, Windows has not been validated recently and several `process.cpp` functions are stubbed (`GEODE_NOT_IMPLEMENTED()`): backtrace, set_backtrace, block_interrupts, set_float_exceptions.

## Toolchain: MSYS2 + MinGW-w64

MinGW is better supported by existing guards than MSVC. MSYS2 provides a Unix-like `pacman` package manager for dependencies.

If MinGW stalls, try MSVC as a secondary path.

## Phase 1: Install prerequisites — COMPLETE

MSYS2 installed at `C:\msys64` with all dependencies. OpenMesh not available in MSYS2; built without it.

| Package | Version |
|---------|---------|
| GCC | 15.2.0 |
| CMake | 4.2.3 |
| Ninja | 1.13.2 |
| Python | 3.14.3 |
| NumPy | 2.4.1 |
| GMP | installed (static + shared) |
| libpng | 1.6.55 |
| libjpeg-turbo | 80 |
| OpenMesh | not available |

## Phase 2: C++ only build (no Python) — COMPLETE

CMake configure succeeded with no issues. GMP, PNG, JPEG all auto-detected.

One fix required:
- `geode/utility/type_traits.h`: GCC 15 broke the `__is_trivially_destructible` builtin wrapper in `mpl::bool_`. Replaced with `std::is_trivially_destructible` (C++17 standard).

## Phase 3: Python bindings — COMPLETE

Two build fixes:
- `geode/python/Class.h`: `tp_hash` callback must return `Py_hash_t` (not `long`) — Windows `long` is 32-bit.
- `GeodeSupport.cmake`: Set `.pyd` suffix for Python extension modules on `WIN32`.

Import fixes:
- Removed legacy `geode_all` import paths from all `__init__.py` files — all platforms now use `geode_wrap`.

**Test results: 166 passed, 0 failed, 1 skipped**

## Expected issues — actual results

| Issue | Expected | Actual |
|-------|----------|--------|
| GMP not found by cmake | Might need hints | Auto-detected, no issue |
| OpenMesh not in MSYS2 | Skip or build from source | Skipped, built without it (as designed) |
| `GEODE_NOT_IMPLEMENTED()` at runtime | Tests might crash | Not triggered by any test |
| DLL symbol visibility | Missing exports | No issue |
| Python extension naming | `.so` → `.pyd` | Fixed in `GeodeSupport.cmake` |
| `uint128` on MinGW | Might not support `__uint128_t` | No issue — MinGW-w64 x86_64 supports it |
| `OM_STATIC_BUILD` mismatch | Linking issues | N/A (no OpenMesh) |

### Issues NOT predicted

| Issue | Where | Fix |
|-------|-------|-----|
| `is_trivially_destructible` GCC 15 | `type_traits.h` | Use `std::is_trivially_destructible` |
| `tp_hash` returns wrong type | `Class.h` | Use `Py_hash_t` instead of `long` |
| `geode_all` import paths | all `__init__.py` | Removed, all platforms use `geode_wrap` |
| `NPY_LONGLONG` not handled | `Prop.cpp`, `Vector.cpp`, `Array.cpp` | Added `long long` template instantiations |

## Files to watch

- `geode/utility/process.cpp` — Windows block (~lines 37-65) and `GEODE_NOT_IMPLEMENTED()` stubs
- `geode/utility/config.h` — MSVC vs GCC export macros (~lines 52-150)
- `geode/python/config.h` — MinGW workarounds (~lines 24-74)
- `geode/openmesh/config.h` — WIN32/OM_STATIC_BUILD guards
- `geode/math/sse.h` — MSVC operator overloads (~lines 24-43)
- `geode/array/alloca.h` — `_alloca` on Windows
- `CMakeLists.txt` — GMP detection, Windows path hints

## What to record

For each phase: full cmake output, build errors with file/line, test results. Save to `build-windows.log`. Note exact MSYS2 package versions for reproducibility.

## Phase 4: Fix int64 (long long) support on Windows

On Windows (LLP64), `sizeof(long)==4` and `sizeof(long long)==8`. numpy's default int is `int64` which maps to `NPY_LONGLONG`. Most of the `long long` plumbing already exists (`FromPython<long long>`, `ToPython`, `NumpyScalar<long long>`, `NdArray<long long>` conversions). The gap is:

- [x] **`geode/value/Prop.cpp`**: `make_prop_shape` switch needs `NPY_LONGLONG` case. Can't use a regular `case` because `NPY_LONG == NPY_LONGLONG` as enum values on LP64 platforms (duplicate case error). Use runtime `sizeof(long)` check before the switch.
- [x] **`geode/vector/Vector.cpp`**: Need `GEODE_DEFINE_VECTOR_CONVERSIONS` for `long long` (2D, 3D, 4D) — `make_prop_shape_helper<long long>` instantiates `Vector<long long, N>`. Use `ENABLE_IF_UNIQUE` pattern to avoid duplicate instantiation on LP64 where `long == long long`.
- [x] **`geode/array/Array.cpp`**: `ENABLE_IF_UNIQUE(int64_t, int, long)` already handles 1D. Verify 2D int64 is covered if needed by `make_prop_shape_helper` (`Array<const Vector<long long, N>>`).

### Investigation findings

| Component | long long support | Status |
|-----------|------------------|--------|
| `FromPython<long long>` | Already in `from_python.cpp` | OK |
| `ToPython(long long)` | Already in `to_python.h` | OK |
| `NumpyScalar<long long>` | Already in `numpy-types.h` | OK |
| `NdArray<long long>` conversions | Already in `NdArray.cpp` | OK |
| `Array<long long>` (1D) | `ENABLE_IF_UNIQUE` in `Array.cpp` | OK |
| `Vector<long long, N>` conversions | Missing in `Vector.cpp` | FIXED |
| `make_prop_shape` type dispatch | Missing `NPY_LONGLONG` | FIXED |
| `module.cpp` static assertions | Already checks `NPY_LONGLONG` | OK |
| `numpy.cpp` fill_numpy_header | Already handles `LONGLONG` | OK |

### Preprocessor gotcha

`NPY_LONG` and `NPY_LONGLONG` are **enum values**, not `#define` macros. `#if NPY_LONGLONG != NPY_LONG` evaluates both as 0 (undefined preprocessor symbols) and always takes the `#else` branch. Use `sizeof(long) < sizeof(long long)` or `std::is_same` for compile-time dispatch, or `ENABLE_IF_UNIQUE` for template instantiation dedup.

**Last updated:** 2026-03-21 (Phase 4 — int64/long long investigation and fix)
**Previously:** 2026-03-20 (initial)
