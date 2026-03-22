# Plan Windows — Geode Build Investigation

**Goal:** Attempt a build on Windows, collect errors, and document what needs fixing. Not necessarily a fully working build in one pass.

**This must run on the Windows machine** — cross-compiling from macOS is not practical.

## Context

The codebase has substantial Windows platform guards already: `process.cpp` Windows block (`GetProcessTimes`, `GetProcessMemoryInfo`), MSVC `__declspec(dllexport)` in `config.h`, MinGW-specific workarounds in `python/config.h` (`_hypot`, `MS_WIN64`, `gnu_printf`), MSVC operator overloads in `sse.h`, `_alloca` in `array/alloca.h`, `__popcnt` in `math/popcount.h`. However, Windows has not been validated recently and several `process.cpp` functions are stubbed (`GEODE_NOT_IMPLEMENTED()`): backtrace, set_backtrace, block_interrupts, set_float_exceptions.

## Toolchain: MSYS2 + MinGW-w64

MinGW is better supported by existing guards than MSVC. MSYS2 provides a Unix-like `pacman` package manager for dependencies.

If MinGW stalls, try MSVC as a secondary path.

## Phase 1: Install prerequisites

- [ ] Install [MSYS2](https://www.msys2.org/) from official site
- [ ] Open MSYS2 MINGW64 shell and run:
  ```
  pacman -Syu
  pacman -S mingw-w64-x86_64-cmake mingw-w64-x86_64-gcc mingw-w64-x86_64-ninja
  pacman -S mingw-w64-x86_64-gmp
  pacman -S mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo
  ```
- [ ] Check if OpenMesh is available: `pacman -Ss openmesh` — if not, note it and build C++ without OpenMesh first (`-DGEODE_OPENMESH=OFF` or it will auto-detect absent)
- [ ] Check Python: `python --version` in MSYS2 shell; install if needed: `pacman -S mingw-w64-x86_64-python mingw-w64-x86_64-python-numpy`
- [ ] Record all installed package versions

## Phase 2: C++ only build (no Python)

Start here to isolate C++ issues from Python binding issues.

- [ ] From MSYS2 MINGW64 shell in the repo root:
  ```
  cmake -B build-win -G "Ninja" -DGEODE_NATIVE_ARCH=OFF -DGEODE_DISABLE_PYTHON=ON
  ```
- [ ] Capture full cmake configure output — note GMP, OpenMesh, PNG, JPEG detection results
- [ ] If configure succeeds: `cmake --build build-win`
- [ ] Record all errors with file and line number

## Phase 3: Python bindings (if Phase 2 succeeds)

- [ ] Re-run cmake with Python enabled:
  ```
  cmake -B build-win -G "Ninja" -DGEODE_NATIVE_ARCH=OFF -DGEODE_DISABLE_PYTHON=OFF
  cmake --build build-win
  ```
- [ ] Note any `.pyd` vs `.so` naming issues (Python extensions on Windows use `.pyd`)
- [ ] If build succeeds: `cd build-win && python -m pytest --forked --tb=short`
- [ ] Record test results and any `GEODE_NOT_IMPLEMENTED()` hits

## Expected issues

| Issue | Where | Notes |
|-------|-------|-------|
| GMP not found by cmake | `CMakeLists.txt` | May need `-DGMP_LIBRARY=C:/msys64/mingw64/lib/libgmp.dll.a` hint |
| OpenMesh not in MSYS2 | `geode/openmesh/` | May need to build from source or skip |
| `GEODE_NOT_IMPLEMENTED()` at runtime | `geode/utility/process.cpp` | backtrace, FP exceptions — confirm tests xfail, not crash |
| DLL symbol visibility | linker | Missing `GEODE_EXPORT` on any recently-added symbols |
| Python extension naming | cmake | `.so` → `.pyd` may need cmake adjustment |
| `uint128` on MinGW | `geode/random/` | Confirm MinGW-w64 supports `__uint128_t` on x86_64 |
| `OM_STATIC_BUILD` mismatch | `geode/openmesh/config.h` | Static vs dynamic OpenMesh linking |

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

**Last updated:** 2026-03-20 (initial)
