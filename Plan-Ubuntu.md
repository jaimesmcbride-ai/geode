# Plan Ubuntu — Geode Build Investigation

**Status (2026-03-21):** Phase 1 fully complete — **165 passed, 0 failed, 2 skipped** on Ubuntu 24.04 ARM64 via lima VM.
All fixes committed in `099762b` and `d08e055`. **Next step:** Validate on real x86_64 Ubuntu hardware.

---

**Goal:** Attempt a build on Ubuntu, collect errors, and document what needs fixing. Not necessarily a fully working build in one pass.

**Execution order:** Start with Docker on Mac (ARM64 Ubuntu) to get a fast baseline, then validate on the real Ubuntu machine (x86_64).

## Context

Geode was originally a Linux/x86 codebase (SCons, Python 2, GCC). The 2026 work ported it to macOS ARM64 and Python 3.14. Ubuntu should be the closest non-Mac platform to working — CMake already includes Debian/Ubuntu multiarch library paths, `install_deps.sh` already has a Debian branch, and the Jenkinsfile is clearly Linux/GCC-oriented.

Main unknowns: Python 3.14 availability on Ubuntu, and whether anything broke during the ARM64/Python 3 port that only manifests on Linux.

## Phase 1: Docker on Mac / lima VM (ARM64 Ubuntu) — DONE

- [x] lima VM (`ubuntu:24.04 ARM64`) used instead of Docker (Docker Desktop had startup issues)
- [x] `bash scripts/install_deps.sh` — succeeded; all apt packages resolved including `libopenmesh-dev 9.0`
- [x] Python 3.12.3 available from apt (3.14 not in standard repos) — **Python 3.12 works fine**
- [x] `cmake --preset ci` — succeeded; GMP and OpenMesh found; numpy initially missing (system Python3 vs venv)
- [x] `cmake --build --preset ci` — 3 build errors found and fixed (see Fixes section below)
- [x] Tests: 164 passed, 2 skipped, 1 failed (`test_interval`)

### Fixes applied (commit 099762b)

1. **`geode/python/numpy.h`**: shim guard `!defined(PyArray_CLEARFLAGS)` didn't catch NumPy 1.x's static inline definitions — added `&& !defined(PyArray_SetBaseObject)` which is a macro in NumPy 1.7+.
2. **`geode/python/numpy.h`**: added `GEODE_NPY_LEGACY_DESCR(d)` macro to abstract NumPy 2.0's split of `PyArray_Descr` into `_PyArray_LegacyDescr` for subarray/fields access. Detected via `NPY_VERSION >= 0x2000000`.
3. **`geode/mesh/TriangleTopology.cpp`**: replaced `_PyArray_LegacyDescr` casts with `GEODE_NPY_LEGACY_DESCR()`.
4. **`geode/config.h.in`**: guarded `#cmakedefine GEODE_NEON` with `#ifndef GEODE_NEON` to suppress redefinition warnings.

### Remaining issue: `test_interval` on Linux ARM64

- Test prints `GEODE_INTERVAL_SSE = 1` and fails: `contains(i0*i1, e0*e1)` assertion
- Interval arithmetic requires directed FP rounding modes (round-up for upper bound, round-down for lower bound)
- On macOS ARM64: works (FPCR-based FP control via `mrs`/`msr fpcr` in `process.cpp`)
- On Linux ARM64: `process.cpp` FP exception/rounding code path — check whether `set_float_exceptions` is properly setting rounding mode, or whether sse2neon's rounding emulation differs between compilers (clang vs GCC)
- **Hypothesis**: GCC on Linux ARM64 generates different NEON code for sse2neon interval ops than clang on macOS, or the rounding mode isn't being set before the test

## Phase 2: Real Ubuntu Machine (x86_64)

- [ ] `git pull` to get commit `099762b` fixes
- [ ] Run `bash scripts/install_deps.sh` (installs Python 3.12 + numpy via apt + venv)
- [ ] **Note**: cmake picks system Python3 at `/usr/bin/python3`; numpy must be installed via `sudo apt install python3-numpy` not just in the venv
- [ ] `cmake --preset ci && cmake --build --preset ci -j2` (use -j2 or -j4, not -j$(nproc); parallel build may cause OOM kills on machines with <4GB RAM per core)
- [ ] `cd build/ci && sudo apt install python3-pytest python3-pytest-forked python3-scipy && python3 -m pytest --forked --tb=short`
- [ ] Record results; expect 164 passed, 2 skipped, 1 failed (test_interval) — or possibly all pass if x86_64 SSE rounding works correctly
- [ ] Note GCC version, Python version, OpenMesh version

## Expected issues

| Issue | Where | Notes |
|-------|-------|-------|
| Python 3.14 not in apt | `install_deps.sh` | Try deadsnakes PPA or use 3.12 |
| OpenMesh version mismatch | `geode/openmesh/` | Ubuntu repo version may differ from Homebrew |
| FP exceptions on Linux x86 | `geode/utility/process.cpp` | Uses `feenableexcept`/`fedisableexcept` — check glibc availability |
| Symbol visibility | linker | `.so` shared lib behavior differs from macOS |
| GMP detection | `CMakeLists.txt` | Should work via `libgmp-dev`, but cmake hints are macOS-path-heavy |

## Files to watch

- `scripts/install_deps.sh` — Debian branch
- `CMakeLists.txt` — multiarch path logic (~lines 18-22), GMP detection
- `GeodeSupport.cmake` — compiler flags, ARM64/NEON detection
- `geode/utility/process.cpp` — Linux memory (`/proc/self/statm`) and FP exception paths
- `geode/utility/config.h` — GCC visibility macros
- `CMakePresets.json` — use `ci` preset

## What to record

For each step: success/failure, full error output, environment details (Ubuntu version, GCC version, Python version, OpenMesh version). Save full output to `build-ubuntu.log`.

**Last updated:** 2026-03-21 (Phase 1 fully complete — 165/0/2 on ARM64 Ubuntu)
**Previously:** 2026-03-20 (Phase 1 complete — ARM64 Ubuntu via lima VM)
**Previously:** 2026-03-20 (initial)
