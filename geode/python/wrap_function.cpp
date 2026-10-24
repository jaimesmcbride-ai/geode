//#####################################################################
// Function wrap_function
//#####################################################################
#include <geode/config.h>
#ifdef GEODE_PYTHON
#include <geode/python/wrap_function.h>
namespace geode {

struct PythonFunction {
  PyObject_HEAD
  FunctionWrapper wrapper;
  void* wrapped;

  static PyTypeObject pytype; 

  static PyObject* call(PyObject* self, PyObject* args, PyObject* kwds) {
    PythonFunction* self_ = (PythonFunction*)self; 
    if (kwds && PyDict_Size(kwds)) {
      PyErr_SetString(PyExc_TypeError,"function takes no keyword arguments");
      return 0;
    }
    return self_->wrapper(args,self_->wrapped);
  }

  static void dealloc(PyObject* self) {
    Py_TYPE(self)->tp_free(self);
  }
};

PyTypeObject PythonFunction::pytype = {
  .ob_base = PyVarObject_HEAD_INIT(&PyType_Type, 0)
  .tp_name = "geode.Function",
  .tp_basicsize = sizeof(PythonFunction),
  .tp_dealloc = PythonFunction::dealloc,
  .tp_call = PythonFunction::call,
  .tp_flags = Py_TPFLAGS_DEFAULT,
  .tp_doc = "Free function wrapper",
};

PyObject* wrap_function_helper(const char* name, FunctionWrapper wrapper, void* function) {
  // Allocate a function wrapper
  PyTypeObject* type=&PythonFunction::pytype;
  PythonFunction* f=(PythonFunction*)type->tp_alloc(type,0);
  if (!f) throw std::bad_alloc();

  // fill in fields
  f->wrapper = wrapper;
  f->wrapped = function;

  // all done
  return (PyObject*)f;
}

}
using namespace geode;
#endif

void wrap_python_function() {
#ifdef GEODE_PYTHON
  if (PyType_Ready(&PythonFunction::pytype)<0)
    return;
  Py_INCREF(&PythonFunction::pytype);
#endif

  // PythonFunction can't be created from python, so no need to add it to the module
}
