//#####################################################################
// Class Buffer
//#####################################################################
#include <geode/python/Buffer.h>
using namespace geode;

// Must match memory allocation routine in header
#ifndef _WIN32
#define free_buffer free
#else
#define free_buffer _aligned_free
#endif

#ifdef GEODE_PYTHON

PyTypeObject Buffer::pytype = {
    .ob_base = PyVarObject_HEAD_INIT(&PyType_Type, 0)
    .tp_name = "geode.Buffer",
    .tp_basicsize = sizeof(Buffer),
    .tp_dealloc = (destructor)free_buffer,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_doc = "Raw memory buffer",
};

// All necessary Buffer::pytpe fields are filled in, so no PyType_Ready is needed

#else // non-python stub

PyTypeObject Buffer::pytype = {
  "geode.Buffer",                  // tp_name
  (void(*)(PyObject*))free_buffer, // tp_dealloc
};

#endif
