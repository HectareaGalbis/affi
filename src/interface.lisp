
(in-package #:affi)


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

(defun %split-docstring (body)
  (if (and (stringp (car body))
           (cdr body))
      (values (cdr body) (car body))
      (if (stringp (car body))
          (values nil (car body))
          (values body nil))))

(defun %with-documentation (form name doc-type docstring)
  (if docstring
      `(progn
         ,form
         (setf (documentation ',name ',doc-type) ,docstring)
         ',name)
      form))

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
  (multiple-value-bind (slots docstring) (%split-docstring slots)
    (loop for slot in slots
          do (%check-define-record-slot slot)
          collect (destructuring-bind (name type) slot
                    `(,name ,(parse-foreign-type type)))
            into parsed-slots
          finally (return (%with-documentation (%define-struct name parsed-slots)
                                               name 'type docstring)))))

(defmacro define-union (name &body slots)
  "
Same as DEFINE-STRUCT, but defines an union instead of a structure.
"
  (multiple-value-bind (slots docstring) (%split-docstring slots)
    (loop for slot in slots
          do (%check-define-record-slot slot)
          collect (destructuring-bind (name type) slot
                    `(,name ,(parse-foreign-type type)))
            into parsed-slots
          finally (return (%with-documentation (%define-union name parsed-slots)
                                               name 'type docstring)))))

(defmacro define-variable ((name foreign-name) type)
  "
Defines a foreign variable.
FOREIGN-NAME is a string denoting the symbol we want to retrieve from the shared library.
NAME is a symbol denoting the lisp name to be used to retrieve the foreign value.
TYPE is the type of the foreign value.
"
  (%define-variable name foreign-name (parse-foreign-type type)))

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defparameter *variadic-int-promotions*
    '(:char :signed-char :short :short-int :signed-short :signed-short-int
      :int8-t :int16-t :bool))

  (defparameter *variadic-unsigned-promotions*
    '(:unsigned-char :unsigned-short :unsigned-short-int :uint8-t :uint16-t))

  (defun %promote-variadic-type (ptype)
    (if (typep ptype 'primitive-type)
        (let ((name (primitive-type-name ptype)))
          (cond
            ((eq name :float) (make-instance 'primitive-type :name :double))
            ((member name *variadic-int-promotions*) (make-instance 'primitive-type :name :int))
            ((member name *variadic-unsigned-promotions*) (make-instance 'primitive-type :name :unsigned-int))
            (t ptype)))
        ptype))

  (defun %split-function-arguments (functype args)
    (let ((num-fixed (length (function-type-argument-types functype))))
      (unless (if (function-type-variadic-p functype)
                  (>= (length args) num-fixed)
                  (= (length args) num-fixed))
        (syntax-error "Expected ~:[~;at least ~]~a arguments"
                      (function-type-variadic-p functype) num-fixed))
      (if (not (function-type-variadic-p functype))
          (values functype args)
          (let ((fixed-args (subseq args 0 num-fixed))
                (variadic-args (nthcdr num-fixed args)))
            (unless (evenp (length variadic-args))
              (syntax-error "Variadic arguments must be pairs of a type and a value"))
            (loop for (type value) on variadic-args by #'cddr
                  for parsed-type = (parse-foreign-type type)
                  collect (%promote-variadic-type parsed-type) into types
                  collect (if (and (typep parsed-type 'primitive-type)
                                   (eq (primitive-type-name parsed-type) :float))
                              `(coerce ,value 'double-float)
                              value)
                    into values
                  finally (return
                            (values (make-instance 'function-type
                                                   :result-type (function-type-result-type functype)
                                                   :argument-types (append (function-type-argument-types functype)
                                                                           types)
                                                   :convention (function-type-convention functype)
                                                   :variadicp t)
                                    (append fixed-args values)))))))))

(defmacro call-function (name (&rest types) &rest args)
  "
Calls a function named NAME.
Returns a foreign value of type RES-TYPE.
ARG-TYPES denotes the function's argument types.
ARGS are the objects passed to the function.
"
  (with-syntax-error-handler `(call-function ,name ,types ,@args)
    (multiple-value-bind (functype args) (%split-function-arguments (parse-function-types types) args)
      (%call-function name functype args))))

(defmacro funcall-pointer (ptr (&rest types) &rest args)
  (with-syntax-error-handler `(funcall-pointer ,ptr ,types ,@args)
    (multiple-value-bind (functype args) (%split-function-arguments (parse-function-types types) args)
      (%funcall-pointer ptr functype args))))

(defun %variadic-call-form (foreign-name res-type arg-types convention fixed-args variadic-args)
  (let ((functype (make-instance 'function-type
                                 :result-type (parse-foreign-type res-type)
                                 :argument-types (mapcar #'parse-foreign-type arg-types)
                                 :convention convention
                                 :variadicp t)))
    (multiple-value-bind (functype args) (%split-function-arguments functype
                                                                    (append fixed-args variadic-args))
      (%call-function foreign-name functype args))))

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

(defmacro define-function ((name foreign-name &key (convention :cdecl)) res-type (&rest args)
                           &optional docstring)
  "
Defines a foreign function called NAME.
FOREIGN-NAME is a string denoting the symbol from the shared library.
NAME is a symbol denoting the name of the new defined function.
The function will return a value of type RES-TYPE.
ARG-TYPES denotes the types of the function's arguments.
"
  (parse-convention convention)
  (let* ((rest-position (position '&rest args))
         (fixed-args (if rest-position (subseq args 0 rest-position) args)))
    (when (and rest-position (/= rest-position (1- (length args))))
      (syntax-error "&REST must be the last element"))
    (loop for arg in fixed-args
          do (%check-define-function-argument arg)
          collect (car arg) into arg-names
          collect (cadr arg) into arg-type-specs
          collect (parse-foreign-type (cadr arg)) into arg-types
          finally (return
                    (if rest-position
                        (with-gensyms (variadic-args)
                          (parse-foreign-type res-type)
                          (%with-documentation
                           `(defmacro ,name (,@arg-names &rest ,variadic-args)
                              (%variadic-call-form ,foreign-name ',res-type ',arg-type-specs ,convention
                                                   (list ,@arg-names) ,variadic-args))
                           name 'function docstring))
                        (%with-documentation
                         (%define-function name foreign-name
                                           (make-instance 'function-type
                                                          :result-type (parse-foreign-type res-type)
                                                          :argument-types arg-types
                                                          :convention convention)
                                           arg-names)
                         name 'function docstring))))))

(defmacro define-callback (name-spec res-type (&rest args) &body body)
  "
Defines a function that can be called from C.
"
  (destructuring-bind (name &key (convention :cdecl)) (ensure-list name-spec)
    (parse-convention convention)
    (loop for arg in args
          do (%check-define-function-argument arg)
          collect (car arg) into arg-names
          collect (parse-foreign-type (cadr arg)) into arg-types
          finally (return (%define-callback name (make-instance 'function-type
                                                                :result-type (parse-foreign-type res-type)
                                                                :argument-types arg-types
                                                                :convention convention)
                                            arg-names body)))))

(defmacro free-callback (name)
  (%free-callback name))

(defun load-shared-object (pathname &key dont-save)
  "
Loads a shared library.
"
  (%load-shared-object pathname dont-save))



(defun close-shared-object (pathname)
  (%close-shared-object pathname))

(defun foreign-symbol-p (foreign-name)
  (%foreign-symbol-p foreign-name))


;; Pointers

(defun %check-pointer-type (type)
  (let ((parsed-type (parse-foreign-type type)))
    (unless (typep parsed-type 'pointer-type)
      (with-syntax-error-handler type
        (syntax-error "Expected a pointer type")))
    (values parsed-type)))

(defmacro make-null-pointer (&optional (type '(:void *)))
  (%make-null-pointer (%check-pointer-type type)))

(defmacro make-pointer (address &optional (type '(:void *)))
  (%make-pointer address (%check-pointer-type type)))

(defun pointer-address (ptr)
  (%pointer-address ptr))

(defun pointer-eq (ptr1 ptr2)
  (= (pointer-address ptr1) (pointer-address ptr2)))


;; Memory

(defun copy-memory (destination source size)
  (call-function "memmove" ((:void *) (:void *) (:void *) :size-t) destination source size)
  (values destination))

(defun fill-memory (ptr byte size)
  (call-function "memset" ((:void *) (:void *) :int :size-t) ptr byte size)
  (values ptr))

(defmacro allocate-zeroed (type &optional (size 1))
  (with-gensyms (ptr size-sym)
    `(let* ((,size-sym ,size)
            (,ptr (allocate ,type ,size-sym)))
       (fill-memory ,ptr 0 (* ,size-sym (sizeof ,type)))
       ,ptr)))

(defun %check-with-allocate-definition (definition)
  (with-syntax-error-handler definition
    (unless (listp definition)
      (syntax-error "Expected a list"))
    (unless (<= 2 (length definition) 3)
      (syntax-error "Expected 2 or 3 elements"))
    (unless (symbolp (car definition))
      (syntax-error "Expected a symbol as the first element"))))

(defmacro with-allocate ((&rest definitions) &body body)
  (mapc #'%check-with-allocate-definition definitions)
  (if (null definitions)
      `(locally ,@body)
      (destructuring-bind ((var type &optional (size 1)) &rest rest-definitions) definitions
        `(let ((,var (allocate ,type ,size)))
           (unwind-protect
                (with-allocate (,@rest-definitions)
                  ,@body)
             (free ,var))))))

(defmacro offsetof (type slot-name)
  (let ((parsed-type (parse-foreign-type type)))
    (unless (typep parsed-type '(or struct-type union-type))
      (with-syntax-error-handler type
        (syntax-error "Expected a struct or union type")))
    (%offsetof parsed-type slot-name)))

(defmacro alignof (type)
  (%alignof (parse-foreign-type type)))


;; Strings

(defun foreign-string-to-lisp (ptr &key (encoding :utf-8) count)
  (unless (null-pointer ptr)
    (let* ((bytes (cast ptr (:uint8-t *)))
           (len (or count
                    (loop for i from 0
                          until (zerop (deref bytes i))
                          finally (return i))))
           (octets (make-array len :element-type '(unsigned-byte 8))))
      (dotimes (i len)
        (setf (aref octets i) (deref bytes i)))
      (%octets-to-string octets encoding))))

(defun lisp-string-to-foreign (string &key (encoding :utf-8))
  (let* ((octets (%string-to-octets string encoding))
         (len (length octets))
         (ptr (allocate :char (+ len 4)))
         (bytes (cast ptr (:uint8-t *))))
    (dotimes (i len)
      (setf (deref bytes i) (aref octets i)))
    (dotimes (i 4)
      (setf (deref bytes (+ len i)) 0))
    (values ptr)))

(defun %check-with-foreign-string-definition (definition)
  (with-syntax-error-handler definition
    (unless (and (listp definition)
                 (>= (length definition) 2)
                 (evenp (length (cddr definition))))
      (syntax-error "Expected a list (VAR STRING &key ENCODING)"))
    (unless (symbolp (car definition))
      (syntax-error "Expected a symbol as the first element"))))

(defmacro with-foreign-string ((&rest definitions) &body body)
  (mapc #'%check-with-foreign-string-definition definitions)
  (if (null definitions)
      `(locally ,@body)
      (destructuring-bind ((var string &rest keys) &rest rest-definitions) definitions
        `(let ((,var (lisp-string-to-foreign ,string ,@keys)))
           (unwind-protect
                (with-foreign-string (,@rest-definitions)
                  ,@body)
             (free ,var))))))


;; Types

(defmacro define-type (name type)
  (with-syntax-error-handler `(define-type ,name ,type)
    (unless (and (symbolp name) name)
      (syntax-error "Expected a symbol as the name"))
    (when (member name *primitive-types*)
      (syntax-error "~s is a primitive type" name))
    (parse-foreign-type type))
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (setf (gethash ',name *type-aliases*) ',type)
     ',name))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *enums* (make-hash-table :test 'eq)))

(defmacro define-enum (name &body specs)
  (with-syntax-error-handler `(define-enum ,name ,@specs)
    (unless (and (symbolp name) name)
      (syntax-error "Expected a symbol as the name"))
    (when (member name *primitive-types*)
      (syntax-error "~s is a primitive type" name))
    (let ((next-value 0))
      (loop for spec in specs
            for (key value) = (with-syntax-error-handler spec
                                (cond
                                  ((and (symbolp spec) spec)
                                   (list spec next-value))
                                  ((and (consp spec)
                                        (= (length spec) 2)
                                        (symbolp (car spec))
                                        (integerp (cadr spec)))
                                   spec)
                                  (t (syntax-error "Expected a symbol or a list (SYMBOL INTEGER)"))))
            do (setf next-value (1+ value))
            collect (cons key value) into alist
            finally (return
                      `(eval-when (:compile-toplevel :load-toplevel :execute)
                         (setf (gethash ',name *type-aliases*) :int)
                         (setf (gethash ',name *enums*) ',alist)
                         ',name))))))

(defun %enum-alist (enum)
  (multiple-value-bind (alist foundp) (gethash enum *enums*)
    (unless foundp
      (error "~s is not an enumeration" enum))
    (values alist)))

(defun enum-value (enum key)
  (if-let ((pair (assoc key (%enum-alist enum))))
    (cdr pair)
    (error "~s is not a key of the enumeration ~s" key enum)))

(defun enum-key (enum value)
  (car (rassoc value (%enum-alist enum))))
