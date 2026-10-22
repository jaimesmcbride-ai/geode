#.rst:
# FindPathPython
# ----------------
# Search for Python 3 libs that match Python executable that is present on $PATH
# Sets the following variables:
#
#  ::
#
#   NUMPY_INCLUDE_DIRS         - Include directory for NumPy
#   PYTHON_FOUND               - Evaluates to false if unsuccessful
#   PYTHON_INCLUDE_DIRS        - Path to directories that contains Python.h
#   PYTHON_LIBRARIES           - Python standard library including full path
#

find_package(PkgConfig)

# Use FindPython3 (modern CMake) instead of deprecated FindPythonInterp
find_package(Python3 3.10 COMPONENTS Interpreter Development NumPy)

if (Python3_Interpreter_FOUND)
  set(PYTHON_EXECUTABLE ${Python3_EXECUTABLE})
  message(STATUS "Python binary found at ${PYTHON_EXECUTABLE}")

  if (Python3_NumPy_FOUND)
    set(NUMPY_INCLUDE_DIRS ${Python3_NumPy_INCLUDE_DIRS})
    message(STATUS "Numpy found in ${NUMPY_INCLUDE_DIRS}")
  else()
    message(WARNING "NumPy not found")
  endif()

  if (Python3_Development_FOUND)
    set(PYTHON_INCLUDE_DIRS ${Python3_INCLUDE_DIRS})
    set(PYTHON_LIBRARIES ${Python3_LIBRARIES})
  endif()
else()
  message(WARNING " No python3 interpreter found!")
endif()

set(PYTHON_FOUND TRUE)

if(NOT PYTHON_INCLUDE_DIRS)
  set(PYTHON_FOUND PYTHON_INCLUDE_DIRS-NOTFOUND)
  message(ERROR " Python include directory invalid ${PYTHON_INCLUDE_DIRS}")
endif()

if(EXISTS "${PYTHON_LIBRARIES}")
  message(STATUS "Python lib found at: ${PYTHON_LIBRARIES}")
else()
  set(PYTHON_FOUND PYTHON_LIBRARIES-NOTFOUND)
  message(ERROR " Unable to find python library")
endif()
