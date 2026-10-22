//#####################################################################
// Conversion for functions
//#####################################################################
#include <geode/python/function.h>
namespace geode {

#ifdef GEODE_PYTHON

void throw_callable_error(PyObject* object) {
  PyErr_Format(PyExc_TypeError,"expected callable object, got %s",Py_TYPE(object)->tp_name);
  throw PythonError();
}

#endif
}
