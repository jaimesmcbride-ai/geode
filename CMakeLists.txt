cmake_minimum_required(VERSION 3.25)
project(geode)

option(GEODE_REQUIRE_PYTHON "Generate an error if python bindings won't be built instead of silently disabling them" FALSE)
option(GEODE_DISABLE_PYTHON "Don't build python bindings even if available" FALSE)

if (GEODE_REQUIRE_PYTHON AND GEODE_DISABLE_PYTHON)
  message(STATUS "Geode Python bindings set to required and disabled at the same time. Please choose at most one")
endif()

include(GeodeSupport.cmake)

find_package(PkgConfig)
find_package(JPEG)
find_package(PNG 1.6)

# Detect Debian/Ubuntu multiarch library suffix
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(_ARCH_LIB_SUFFIX "aarch64-linux-gnu")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|amd64")
  set(_ARCH_LIB_SUFFIX "x86_64-linux-gnu")
endif()

# GMP: try pkg-config first, fall back to find_library
find_library(GMP_LIBRARIES gmp
  HINTS /opt/homebrew/lib /usr/local/lib
        /usr/lib/${_ARCH_LIB_SUFFIX} /usr/lib64 /usr/lib)
find_path(GMP_INCLUDE gmp.h
  HINTS /opt/homebrew/include /usr/local/include
        /usr/include/${_ARCH_LIB_SUFFIX} /usr/include)
if(NOT GMP_LIBRARIES OR NOT GMP_INCLUDE)
  # fall back to pkg-config for non-standard installs
  if(PkgConfig_FOUND)
    pkg_check_modules(GMP QUIET gmp)
    if(GMP_FOUND)
      find_library(GMP_LIBRARIES gmp HINTS ${GMP_LIBRARY_DIRS})
      set(GMP_INCLUDE ${GMP_INCLUDE_DIRS})
    endif()
  endif()
endif()
if(GMP_LIBRARIES AND GMP_INCLUDE)
  set(GMP_FOUND TRUE)
  # GMP 6 or newer (mpn_neg and mpn_sqr are used unconditionally)
  file(STRINGS "${GMP_INCLUDE}/gmp.h" _gmp_ver REGEX "^#define __GNU_MP_VERSION +[0-9]+")
  string(REGEX MATCH "[0-9]+$" _gmp_major "${_gmp_ver}")
  if(_gmp_major AND _gmp_major LESS 6)
    message(FATAL_ERROR "GMP >= 6 required, found ${_gmp_major} in ${GMP_INCLUDE}")
  endif()
endif()

if (GMP_FOUND)
  message(STATUS "GMP found in ${GMP_LIBRARIES}")
else()
  message(FATAL_ERROR "Required dependency GMP not found. Set GMP_LIB_DIR and GMP_INCLUDE_DIR to inform cmake where to look")
endif()

find_library(
  OPENMESH_CORE_LIBRARY OpenMeshCore
  HINTS /opt/homebrew/lib /usr/local/lib /usr/local/lib/OpenMesh
        /usr/lib/${_ARCH_LIB_SUFFIX}/OpenMesh /usr/lib64/OpenMesh /usr/lib/OpenMesh
)
find_library(
  OPENMESH_TOOLS_LIBRARY OpenMeshTools
  HINTS /opt/homebrew/lib /usr/local/lib /usr/local/lib/OpenMesh
        /usr/lib/${_ARCH_LIB_SUFFIX}/OpenMesh /usr/lib64/OpenMesh /usr/lib/OpenMesh
)
set(OPENMESH_LIBRARIES ${OPENMESH_CORE_LIBRARY} ${OPENMESH_TOOLS_LIBRARY})

find_path(
  OPENMESH_INCLUDE OpenMesh/Core/Mesh/TriMeshT.hh
  HINTS /opt/homebrew/include /usr/local/include
        /usr/include/${_ARCH_LIB_SUFFIX} /usr/include
)

if (OPENMESH_CORE_LIBRARY AND OPENMESH_TOOLS_LIBRARY AND OPENMESH_INCLUDE)
  set(OPENMESH_FOUND TRUE)
  # OpenMesh 11 or newer: OM_VERSION is 0x0B0000 for 11.0
  file(STRINGS "${OPENMESH_INCLUDE}/OpenMesh/Core/System/config.h" _om_ver REGEX "^#define OM_VERSION +0x[0-9A-Fa-f]+")
  string(REGEX MATCH "0x[0-9A-Fa-f]+$" _om_hex "${_om_ver}")
  if(_om_hex)
    math(EXPR _om_major "(${_om_hex} & 0xf0000) >> 16")
    if(_om_major LESS 11)
      message(WARNING "OpenMesh >= 11 required, found ${_om_major} in ${OPENMESH_INCLUDE}; OpenMesh functionality disabled")
      set(OPENMESH_FOUND FALSE)
    endif()
  endif()
endif()

if (OPENMESH_FOUND)
  message(STATUS "OPENMESH found in ${OPENMESH_LIBRARIES}")
else()
  message(WARNING
    "OpenMesh not found -- the following functionality will be unavailable:\n"
    "  TriMesh, decimate_openmesh, mean_curvatures, gaussian_curvatures,\n"
    "  triangulate_face, visualize, floodfill\n"
    "Install: brew install open-mesh (macOS) or apt install libopenmesh-dev (Ubuntu)")
endif()


set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR}/)

find_package(PathPython)

add_subdirectory(geode)

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/geode.pc.in ${CMAKE_BINARY_DIR}/geode.pc
  @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/geode.pc DESTINATION lib/pkgconfig/)

if(NOT GUI_DIR)
  # Check in current directory by default
  set(GUI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gui)
endif()

if (EXISTS ${GUI_DIR})
  message(STATUS "gui found at ${GUI_DIR}")
  set(Geode_DIR ${CMAKE_CURRENT_BINARY_DIR}/geode)
  add_subdirectory(${GUI_DIR} ${CMAKE_CURRENT_BINARY_DIR}/gui)
endif()
