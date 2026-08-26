
(in-package #:tffi)


(eval-when (:compile-toplevel :load-toplevel :execute)

  
  
  ;; (defun %check-define-record-slots (slots)
  ;;   (loop for slot in slots
  ;;         do (%check-define-record-slot slot)))
  )


(defmacro cast (value type)
  "
Converts the type of VALUE into another.
VALUE must be of type array or pointer.
TYPE must be an array or pointer type.
"
  (%cast value (parse-foreign-type type)))

(defun null-pointer (value)
  "
Checks whether VALUE is the null pointer.
"
  (%null-pointer value))

(defmacro sizeof (type)
  "
Returns the size of TYPE in BYTES.
"
  (%sizeof (parse-foreign-type type)))

(defmacro allocate (type &optional (size 1))
  "
Allocates memory on the heap.
The bytes allocated are calculated from TYPE and the SIZE elements wanted.
Returns a pointer to TYPE.
"
  (%allocate (parse-foreign-type type) size))

(defun free (ptr)
  "
Deallocates the memory pointed by PTR.
"
  (%free ptr))

(defun %check-stack-allocate-definition (definition)
  (with-syntax-error-handler definition
    (unless (listp definition)
      (syntax-error "Expected a list"))
    (let ((definition-length (length definition)))
      (unless (and (>= definition-length 2)
                   (<= definition-length 3))
        (syntax-error "Expected 2 or 3 elements"))
      (unless (symbolp (car definition))
        (syntax-error "Expected a symbol as the first element")))))

(defmacro stack-allocate ((&rest definitions) &body body)
  "
Allocates memory on the stack.
This memory has dynamic extent during the body of the macro.
Each definition must be a list of a variable holding the allocated value
and the type of the value.
"
  (mapcar #'%check-stack-allocate-definition definitions)
  (loop for (name type value) in definitions
        for parsed-type = (parse-foreign-type type)
        collect `(,name ,parsed-type ,value) into parsed-definitions
        finally (return (%stack-allocate parsed-definitions body))))

(defmacro addr (expr)
  "
This macro must be used in the following scenarios to retrieve the addres of a foreign value.
  * A foreign variable: A variable defined with DEFINE-VARIABLE, DEFINE-FUNCTION or DEFINE-CALLBACK.
  * An accessor: A DEREF or SLOT expression.
"
  (%addr expr))

(defun deref (obj &rest indices)
  "
Returns the value pointed by OBJ.
OBJ must be a pointer or an array.
INDICES can be used to deref an element of a given index
from the pointer or the array.
"
  (%deref obj indices))

(defsetf deref (obj &rest indices) (new-value)
  "
Assigns NEW-VALUE to the value pointed by OBJ at the position given by INDICES.
The foreign value and NEW-VALUE must be of the same type.
"
  (%setf-deref obj indices new-value))

(defun slot (obj slot-name)
  "
Returns the slot SLOT-NAME of a record OBJ.
"
  (%slot obj slot-name))

(defsetf slot (obj slot-name) (new-value)
  "
Assigns a NEW-VALUE to the slot SLOT-NAME of a record OBJ.
"
  (%setf-slot obj slot-name new-value))

(defun %check-define-record-slot (slot)
  (with-syntax-error-handler slot
    (unless (and (listp slot)
                 (= (length slot) 2))
      (syntax-error "A record slot must be a list of two elements"))
    (when (ignore-errors (parse-foreign-type slot))
      (syntax-error "A record slot must have a name before the type"))
    (let ((name (car slot)))
      (unless (symbolp name)
        (syntax-error "The first element must be a symbol")))))

(defmacro define-struct (name &body slots)
  "
Defines a foreign structure.
Each slot must be a list with a symbol denoting the member name
and the type of that member.
"
  (loop for slot in slots
        do (%check-define-record-slot slot)
        collect (destructuring-bind (name type) slot
                  `(,name ,(parse-foreign-type type)))
          into parsed-slots
        finally (return (%define-struct name parsed-slots))))

(defmacro define-union (name &body slots)
  "
Same as DEFINE-STRUCT, but defines an union instead of a structure.
"
  (loop for slot in slots
        do (%check-define-record-slot slot)
        collect (destructuring-bind (name type) slot
                  `(,name ,(parse-foreign-type type)))
          into parsed-slots
        finally (return (%define-union name parsed-slots))))

(defmacro define-variable ((name foreign-name) type)
  "
Defines a foreign variable.
FOREIGN-NAME is a string denoting the symbol we want to retrieve from the shared library.
NAME is a symbol denoting the lisp name to be used to retrieve the foreign value.
TYPE is the type of the foreign value.
"
  (%define-variable name foreign-name (parse-foreign-type type)))

(defmacro call-function (name (res-type &rest arg-types) &rest args)
  "
Calls a function named NAME.
Returns a foreign value of type RES-TYPE.
ARG-TYPES denotes the function's argument types.
ARGS are the objects passed to the function.
"
  (%call-function name
      (make-instance 'function-type :result-type (parse-foreign-type res-type)
                                    :argument-types (mapcar #'parse-foreign-type arg-types))
      args))

(defun %check-define-function-argument (arg)
  (with-syntax-error-handler arg
    (unless (and (listp arg)
                 (= (length arg) 2))
      (syntax-error "A function argument must be a list of two elements"))
    (when (ignore-errors (parse-foreign-type arg))
      (syntax-error "An argument must have a name before the type"))
    (let ((name (car arg)))
      (unless (symbolp name)
        (syntax-error "The first element must be a symbol")))))

(defmacro define-function ((name foreign-name) res-type (&rest args))
  "
Defines a foreign function called NAME.
FOREIGN-NAME is a string denoting the symbol from the shared library.
NAME is a symbol denoting the name of the new defined function.
The function will return a value of type RES-TYPE.
ARG-TYPES denotes the types of the function's arguments.
"
  (loop for arg in args
        do (%check-define-function-argument arg)
        collect (car arg) into arg-names
        collect (parse-foreign-type (cadr arg)) into arg-types
        finally (return (%define-function name foreign-name
                                          (make-instance 'function-type
                                                         :result-type (parse-foreign-type res-type)
                                                         :argument-types arg-types)
                                          arg-names))))

(defmacro define-callback (name res-type (&rest args) &body body)
  "
Defines a function that can be called from C.
"
  (loop for arg in args
        do (%check-define-function-argument arg)
        collect (car arg) into arg-names
        collect (parse-foreign-type (cadr arg)) into arg-types
        finally (return (%define-callback name (make-instance 'function-type
                                                         :result-type (parse-foreign-type res-type)
                                                         :argument-types arg-types)
                                          arg-names body))))

(defun load-shared-object (pathname &key dont-save)
  "
Loads a shared library.
"
  (%load-shared-object pathname dont-save))


