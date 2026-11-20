(in-package #:affi)


;; Package where the Lisp names used internally by the CLISP backend are interned
;; (C types of records, foreign variables, foreign functions and callbacks).
;; Gensyms can't be used because CLISP doesn't preserve the identity of uninterned
;; symbols between different top-level forms of a compiled file.
(defpackage #:affi.clisp
  (:use))

;; Representation of foreign values in CLISP:
;;
;;   * Primitive values are Lisp numbers.
;;   * Arrays, structs and unions are FFI:FOREIGN-VARIABLE objects (a typed place).
;;   * A pointer to T is a FFI:FOREIGN-VARIABLE of type T located at the pointed address
;;     (this is what CLISP does with (FFI:C-POINTER T)). The null pointer is NIL.
;;   * A pointer to void is a FFI:FOREIGN-ADDRESS.
;;   * A pointer to a function is a FFI:FOREIGN-FUNCTION.
;;
;; INCOMPATIBILITY: As a consequence, a pointer to an aggregate (array, struct or union)
;; and the aggregate itself have the same representation. In particular, a pointer to an
;; array is indistinguishable from the array: (DEREF PTR-TO-ARRAY I) returns the I-th
;; element of the array and not the I-th array as in SBCL.
;;
;; INCOMPATIBILITY: Some operations rely on internal (non exported) functions of the FFI
;; package: FFI::FOREIGN-TYPE, FFI::%SIZEOF, FFI::FIND-FOREIGN-VARIABLE and
;; FFI::FIND-FOREIGN-FUNCTION. They could change in other versions of CLISP.

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defun %make-primitive-type-names ()
    (let ((types (make-hash-table :test 'eq)))
      (%setf-key-value types
                      :void                   nil
                      :char                   ffi:char
                      :signed-char            ffi:char
                      :unsigned-char          ffi:uchar
                      :short                  ffi:short
                      :short-int              ffi:short
                      :signed-short           ffi:short
                      :signed-short-int       ffi:short
                      :unsigned-short         ffi:ushort
                      :unsigned-short-int     ffi:ushort
                      :int                    ffi:int
                      :signed                 ffi:int
                      :signed-int             ffi:int
                      :unsigned               ffi:uint
                      :unsigned-int           ffi:uint
                      :long                   ffi:long
                      :long-int               ffi:long
                      :signed-long            ffi:long
                      :signed-long-int        ffi:long
                      :unsigned-long          ffi:ulong
                      :unsigned-long-int      ffi:ulong
                      ;; INCOMPATIBILITY: CLISP has no 'long long' type.
                      ;; We assume it is a 64 bits integer.
                      :long-long              ffi:sint64
                      :long-long-int          ffi:sint64
                      :signed-long-long       ffi:sint64
                      :signed-long-long-int   ffi:sint64
                      :unsigned-long-long     ffi:uint64
                      :unsigned-long-long-int ffi:uint64
                      :float                  ffi:single-float
                      :double                 ffi:double-float
                      ; :long-double          Not supported
                      :size-t                 ffi:size_t
                      :ssize-t                ffi:ssize_t
                      :ptrdiff-t              ffi:ssize_t
                      :int8-t                 ffi:sint8
                      :uint8-t                ffi:uint8
                      :int16-t                ffi:sint16
                      :uint16-t               ffi:uint16
                      :int32-t                ffi:sint32
                      :uint32-t               ffi:uint32
                      :int64-t                ffi:sint64
                      :uint64-t               ffi:uint64
                      :bool                   ffi:uint8
                      :intptr-t               #+word-size=64 ffi:sint64 #-word-size=64 ffi:sint32
                      :uintptr-t              #+word-size=64 ffi:uint64 #-word-size=64 ffi:uint32
                      :wchar-t                #+win32 ffi:uint16 #-win32 ffi:sint32)
      (values types)))

  (defparameter *primitive-type-names* (%make-primitive-type-names))

  (defclass function-info ()
    ((callbackp :initarg :callbackp :initform nil)
     (funcvar   :initarg :funcvar)
     (functype  :initarg :functype)))

  (defparameter *functions* (make-hash-table :test 'eq))

  (defun function-info (func)
    (values (gethash func *functions*)))

  (defun (setf function-info) (info func)
    (setf (gethash func *functions*) info))

  (defun %internal-name (kind name)
    (intern (format nil "~a ~a::~a"
                    kind
                    (if-let ((package (symbol-package name)))
                      (package-name package)
                      "")
                    (symbol-name name))
            '#:affi.clisp))

  (defun %void-type-p (ptype)
    (and (typep ptype 'primitive-type)
         (eq (primitive-type-name ptype) :void)))

  (defun %record-type-p (ptype)
    (typep ptype '(or struct-type union-type)))

  (defun %function-pointer-type-p (ptype)
    (and (typep ptype 'pointer-type)
         (typep (pointer-type-data-type ptype) 'function-type)))

  ;; MODE indicates the direction of the conversion of the value:
  ;;   :OUT -> From C to Lisp (variables, slots, returned values, callback arguments)
  ;;   :IN  -> From Lisp to C (function arguments and callback returned values)
  ;; Pointers are translated in :IN mode to FFI:C-POINTER because CLISP checks that the type
  ;; of a FFI:FOREIGN-VARIABLE matches exactly the type of a (FFI:C-POINTER TYPE) argument.
  (defgeneric %translate-type (ptype &optional mode))

  (defmethod %translate-type ((ptype primitive-type) &optional mode)
    (declare (ignore mode))
    (gethash (primitive-type-name ptype) *primitive-type-names*))

  (defmethod %translate-type ((ptype struct-type) &optional mode)
    (declare (ignore mode))
    (%internal-name "STRUCT" (struct-type-name ptype)))

  (defmethod %translate-type ((ptype union-type) &optional mode)
    (declare (ignore mode))
    (%internal-name "UNION" (union-type-name ptype)))

  ;; INCOMPATIBILITY: CLISP checks strictly the signature of a FFI:FOREIGN-FUNCTION when
  ;; it is passed as a function pointer. For that reason, the translation of a function type
  ;; is always the same: arguments are translated in :OUT mode and the result in :IN mode
  ;; (the direction used by callbacks).
  (defun %translate-convention (functype)
    (ecase (function-type-convention functype)
      (:cdecl :stdc)
      (:stdcall :stdc-stdcall)))

  (defmethod %translate-type ((ptype function-type) &optional mode)
    (declare (ignore mode))
    `(ffi:c-function
      (:arguments ,@(loop for arg-type in (function-type-argument-types ptype)
                          for i from 0
                          collect `(,(intern (format nil "ARG~a" i) '#:affi.clisp)
                                    ,(%translate-type arg-type :out))))
      (:return-type ,(%translate-type (function-type-result-type ptype) :in))
      (:language ,(%translate-convention ptype))))

  (defmethod %translate-type ((ptype array-type) &optional (mode :out))
    (ecase mode
      ;; Arrays as arguments decay to pointers
      (:in 'ffi:c-pointer)
      (:out `(ffi:c-array ,(%translate-type (array-type-data-type ptype) :out)
                          ,(array-type-size ptype)))))

  (defmethod %translate-type ((ptype pointer-type) &optional (mode :out))
    (let ((data-type (pointer-type-data-type ptype)))
      (cond
        ((typep data-type 'function-type)
         (%translate-type data-type mode))
        ((%void-type-p data-type)
         'ffi:c-pointer)
        (t
         (ecase mode
           (:in 'ffi:c-pointer)
           (:out `(ffi:c-pointer ,(%translate-type data-type :out))))))))

  (defun %translate-function-type (functype)
    `(ffi:c-function
      (:arguments ,@(loop for arg-type in (function-type-argument-types functype)
                          for i from 0
                          collect `(,(intern (format nil "ARG~a" i) '#:affi.clisp)
                                    ,(%translate-type arg-type :in))))
      (:return-type ,(%translate-type (function-type-result-type functype) :out))
      (:language ,(%translate-convention functype))))

  ;; Forms converting values from Lisp to C
  (defun %to-foreign-form (form ptype)
    (cond
      ((%function-pointer-type-p ptype)
       `(%to-function ,form ',(%translate-type ptype)))
      ((typep ptype '(or pointer-type array-type))
       `(%to-pointer ,form))
      ((%record-type-p ptype)
       `(%to-record ,form))
      (t form)))

  ;; Forms converting values from C to Lisp
  (defun %from-foreign-form (form ptype)
    (if (%record-type-p ptype)
        `(%from-record ,form ',(%translate-type ptype))
        form))

  (defun %cast (value type)
    `(%cast-value ,value ',(%translate-type type)))

  (defun %null-pointer (value)
    (or (null value)
        (zerop (ffi:foreign-address-unsigned (%address value)))))

  (defun %sizeof (type)
    `(ffi:sizeof ',(%translate-type type)))

  (defun %allocate (type size)
    `(%allocate-memory ',(%translate-type type) ,size))

  (defun %free (obj)
    (ffi:foreign-free obj))

  (defun %stack-allocate (definitions body)
    (if (null definitions)
        `(locally ,@body)
        (destructuring-bind ((var type value) &rest rest-definitions) definitions
          (let ((place (%internal-name "STACK" var)))
            `(ffi:with-foreign-object (,place ',(%translate-type type))
               ,@(when value
                   `((%store ,place ,value)))
               (symbol-macrolet ((,var ,(if (typep type '(or array-type struct-type union-type))
                                            place
                                            `(%value ,place))))
                 ,@(if rest-definitions
                       `(,(%stack-allocate rest-definitions body))
                       body)))))))

  (defun %addr (expr)
    (if (symbolp expr)
        (if-let ((func-info (function-info expr)))
          (slot-value func-info 'funcvar)
          `(%variable-address ,expr))
        (case (car expr)
          (deref `(%deref-place ,(cadr expr) (list ,@(cddr expr))))
          (slot `(%slot-place ,@(cdr expr))))))

  (defun %deref (obj indices)
    (%read-place (%deref-place obj indices)))

  (defun %setf-deref (obj indices new-value)
    `(%store (%deref-place ,obj (list ,@indices)) ,new-value))

  (defun %slot (obj slot-name)
    (%read-place (%slot-place obj slot-name)))

  (defun %setf-slot (obj slot-name new-value)
    `(%store (%slot-place ,obj ,slot-name) ,new-value))

  (defun %define-record (struct-or-union name slots)
    (let ((translated-slots (loop for (name type) in slots
                                  collect `(,name ,(%translate-type type :out)))))
      (ecase struct-or-union
        (:struct
         `(ffi:def-c-type ,(%internal-name "STRUCT" name)
              (ffi:c-struct vector ,@translated-slots)))
        ;; INCOMPATIBILITY: CLISP converts an union to Lisp using only its first member.
        ;; Passing or returning an union by value (or a struct containing an union) only
        ;; preserves the value of the first member of the union.
        (:union
         `(ffi:def-c-type ,(%internal-name "UNION" name)
              (ffi:c-union ,@translated-slots))))))

  ;; INCOMPATIBILITY: CLISP doesn't support incomplete types. A pointer to a struct or
  ;; union can be used only if the struct or union was previously defined.
  (defun %define-struct (name slots)
    (%define-record :struct name slots))

  (defun %define-union (name slots)
    (%define-record :union name slots))

  (defun %define-variable (name foreign-name type)
    (let ((var (%internal-name "VARIABLE" name)))
      `(progn
         (defparameter ,var (%find-variable ,foreign-name ',(%translate-type type :out)))
         (define-symbol-macro ,name ,(if (typep type '(or array-type struct-type union-type))
                                         var
                                         `(%value ,var))))))

  (defun %call-function (name functype args)
    (let ((translated-functype (%translate-function-type functype)))
      (%from-foreign-form
       `(funcall (%cached-function ,name ',translated-functype)
                 ,@(loop for arg in args
                         for arg-type in (function-type-argument-types functype)
                         collect (%to-foreign-form arg arg-type)))
       (function-type-result-type functype))))

  (defun %define-function (name foreign-name functype args)
    (let ((translated-functype (%translate-function-type functype))
          (func-var (%internal-name "FUNCTION" name)))
      `(progn
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (setf (function-info ',name)
                 (make-instance 'function-info :funcvar ',func-var
                                               :functype ',translated-functype)))
         (defparameter ,func-var (%find-function ,foreign-name ',translated-functype))
         (defun ,name (,@args)
           ,(%from-foreign-form
             `(funcall ,func-var ,@(loop for arg in args
                                         for arg-type in (function-type-argument-types functype)
                                         collect (%to-foreign-form arg arg-type)))
             (function-type-result-type functype))))))

  (defun %define-callback (name functype args body)
    (let ((translated-functype (%translate-type functype))
          (callback-var (%internal-name "CALLBACK" name)))
      `(progn
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (setf (function-info ',name)
                 (make-instance 'function-info :callbackp t
                                               :funcvar ',callback-var
                                               :functype ',translated-functype)))
         (defparameter ,callback-var
           (%make-callback
            (lambda (,@args)
              ,(%to-foreign-form
                `(let (,@(loop for arg in args
                               for arg-type in (function-type-argument-types functype)
                               when (%record-type-p arg-type)
                                 collect `(,arg ,(%from-foreign-form arg arg-type))))
                   ,@body)
                (function-type-result-type functype)))
            ',translated-functype))
         (defun ,name (,@args)
           ,@body))))

  ;; INCOMPATIBILITY: DONT-SAVE is ignored. CLISP doesn't reopen the libraries when an
  ;; image saved with EXT:SAVEINITMEM is started.
  (defparameter *shared-objects* (make-hash-table :test 'equal))

  (defun %load-shared-object (pathname dont-save)
    (declare (ignore dont-save))
    (let ((name (if (pathnamep pathname)
                    (namestring pathname)
                    pathname)))
      (setf (gethash name *shared-objects*)
            (ffi:open-foreign-library name))))

  ;; INCOMPATIBILITY: After FFI:CLOSE-FOREIGN-LIBRARY the symbols of the library can still be
  ;; found, so FOREIGN-SYMBOL-P may keep returning T for them.
  (defun %close-shared-object (pathname)
    (let ((name (if (pathnamep pathname)
                    (namestring pathname)
                    pathname)))
      (when-let ((library (gethash name *shared-objects*)))
        (ffi:close-foreign-library library)
        (remhash name *shared-objects*)
        t)))

  (defun %foreign-symbol-p (foreign-name)
    (handler-case
        (progn
          (ffi::find-foreign-variable foreign-name (ffi:parse-c-type 'ffi:char) :default nil nil)
          t)
      (error () nil)))

  (defun %funcall-pointer (ptr functype args)
    (let ((translated-functype (%translate-function-type functype)))
      (%from-foreign-form
       `(funcall (%to-function ,ptr ',translated-functype)
                 ,@(loop for arg in args
                         for arg-type in (function-type-argument-types functype)
                         collect (%to-foreign-form arg arg-type)))
       (function-type-result-type functype))))

  (defun %make-null-pointer (type)
    (declare (ignore type))
    nil)

  (defun %make-pointer (address type)
    `(%make-pointer-value ,address ',(%translate-type type)))

  (defun %pointer-address (ptr)
    (if (null ptr)
        0
        (ffi:foreign-address-unsigned (%address ptr))))

  (defun %offsetof (type slot-name)
    `(%clisp-offsetof ',(%translate-type type) ',slot-name))

  (defun %alignof (type)
    `(%clisp-alignof ',(%translate-type type)))

  (defun %free-callback (name)
    (let ((func-info (function-info name)))
      (unless (and func-info (slot-value func-info 'callbackp))
        (error "~s is not a callback" name))
      `(%clisp-free-callback ',(slot-value func-info 'funcvar))))

  ;; INCOMPATIBILITY: Encodings are CLISP charsets. Keywords are translated to the charset
  ;; with the same name (:LATIN-1 and :LATIN1 are translated to ISO-8859-1).
  (defun %encoding (encoding)
    (let* ((name (case encoding
                   ((:latin-1 :latin1) "ISO-8859-1")
                   (t (symbol-name encoding))))
           (charset (find-symbol name "CHARSET")))
      (unless charset
        (error "Unknown encoding ~s" encoding))
      (ext:make-encoding :charset (symbol-value charset))))

  (defun %string-to-octets (string encoding)
    (ext:convert-string-to-bytes string (%encoding encoding)))

  (defun %octets-to-string (octets encoding)
    (ext:convert-string-from-bytes octets (%encoding encoding))))


;; Runtime helpers

(defun %aggregate-c-type-p (c-type)
  (and (simple-vector-p c-type)
       (member (svref c-type 0) '(ffi:c-struct ffi:c-union ffi:c-array ffi:c-array-max))))

(defun %foreign-type (fv)
  (ffi::foreign-type fv))

(defun %address (obj)
  (ffi:foreign-address obj))

(defun %offset-address (address offset)
  (ffi:unsigned-foreign-address (+ (ffi:foreign-address-unsigned address) offset)))

(defun %retype (obj c-type)
  (ffi:foreign-variable (%address obj) c-type))

(defun %value (fv)
  (ffi:foreign-value fv))

(defun %store (fv new-value)
  (let ((c-type (%foreign-type fv)))
    (cond
      ((%aggregate-c-type-p c-type)
       (if (typep new-value 'ffi:foreign-variable)
           (let ((bytes (ffi:parse-c-type `(ffi:c-array ffi:uint8 ,(ffi::%sizeof c-type)))))
             (setf (ffi:memory-as (%address fv) bytes)
                   (ffi:memory-as (%address new-value) bytes)))
           (setf (ffi:foreign-value fv) new-value)))
      ((and (simple-vector-p c-type)
            (eq (svref c-type 0) 'ffi:c-pointer))
       (setf (ffi:foreign-value fv)
             (and new-value (%retype new-value (svref c-type 1)))))
      ((and (simple-vector-p c-type)
            (eq (svref c-type 0) 'ffi:c-function))
       (setf (ffi:foreign-value fv)
             (if (functionp new-value)
                 (if (typep new-value 'ffi:foreign-function)
                     (ffi:foreign-function (%address new-value) c-type)
                     new-value)
                 (and new-value (ffi:foreign-function (%address new-value) c-type)))))
      ((eq c-type 'ffi:c-pointer)
       (setf (ffi:foreign-value fv) (and new-value (%address new-value))))
      (t
       (setf (ffi:foreign-value fv) new-value))))
  (values new-value))

(defsetf %value %store)

(defun %read-place (fv)
  (if (%aggregate-c-type-p (%foreign-type fv))
      fv
      (ffi:foreign-value fv)))

(defun %index-place (fv index)
  (let* ((c-type (%foreign-type fv))
         (element-type (if (and (simple-vector-p c-type)
                                (member (svref c-type 0) '(ffi:c-array ffi:c-array-max)))
                           (svref c-type 1)
                           c-type)))
    (ffi:foreign-variable (%offset-address fv (* index (ffi::%sizeof element-type)))
                          element-type)))

(defun %deref-place (obj indices)
  (let ((fv obj))
    (dolist (index indices)
      (setf fv (%index-place fv index)))
    (values fv)))

(defun %slot-place (obj slot-name)
  (ffi:with-c-place (place obj)
    (ffi:c-var-object (ffi:slot place slot-name))))

(defmacro %variable-address (expr &environment env)
  (let ((expansion (macroexpand-1 expr env)))
    (if (and (consp expansion)
             (eq (car expansion) '%value))
        (cadr expansion)
        expr)))

(defun %cast-value (value c-type)
  (when value
    (let ((parsed-type (ffi:parse-c-type c-type)))
      (cond
        ((eq parsed-type 'ffi:c-pointer)
         (%address value))
        ((and (simple-vector-p parsed-type)
              (eq (svref parsed-type 0) 'ffi:c-pointer))
         (%retype value (svref parsed-type 1)))
        ((and (simple-vector-p parsed-type)
              (eq (svref parsed-type 0) 'ffi:c-function))
         (ffi:foreign-function (%address value) parsed-type))
        (t
         (%retype value parsed-type))))))

(defun %allocate-memory (c-type size)
  (%retype (ffi:allocate-shallow c-type :count size)
           (ffi:parse-c-type c-type)))

(defun %to-pointer (obj)
  (if (typep obj 'ffi:foreign-function)
      (%address obj)
      obj))

(defun %to-function (obj c-type)
  (cond
    ((null obj) nil)
    ((typep obj 'ffi:foreign-function)
     (ffi:foreign-function (%address obj) (ffi:parse-c-type c-type)))
    ((functionp obj) obj)
    (t (ffi:foreign-function (%address obj) (ffi:parse-c-type c-type)))))

(defun %to-record (obj)
  (if (typep obj 'ffi:foreign-variable)
      (ffi:foreign-value obj)
      obj))

(defun %from-record (value c-type)
  (let ((fv (ffi:allocate-shallow c-type)))
    (setf (ffi:foreign-value fv) value)
    (ext:finalize fv #'ffi:foreign-free)
    (values fv)))

(defun %find-variable (foreign-name c-type)
  (ffi::find-foreign-variable foreign-name (ffi:parse-c-type c-type) :default nil nil))

(defun %find-function (foreign-name c-type)
  (ffi::find-foreign-function foreign-name (ffi:parse-c-type c-type) nil :default nil nil))

(defvar *cached-functions* (make-hash-table :test 'equal))

(defun %cached-function (foreign-name c-type)
  (let ((key (cons foreign-name c-type)))
    (or (gethash key *cached-functions*)
        (setf (gethash key *cached-functions*) (%find-function foreign-name c-type)))))

(defun %make-callback (function c-type)
  (ffi:with-foreign-object (fv c-type function)
    (ffi:foreign-value fv)))

(defun %make-pointer-value (address c-type)
  (unless (zerop address)
    (%cast-value (ffi:unsigned-foreign-address address) c-type)))

(defun %clisp-offsetof (c-type slot-name)
  (ffi:with-foreign-object (fv c-type)
    (- (ffi:foreign-address-unsigned (%slot-place fv slot-name))
       (ffi:foreign-address-unsigned fv))))

(defun %clisp-alignof (c-type)
  (ffi:with-foreign-object (fv `(ffi:c-struct vector
                                  (affi.clisp::padding ffi:char)
                                  (affi.clisp::value ,c-type)))
    (- (ffi:foreign-address-unsigned (%slot-place fv 'affi.clisp::value))
       (ffi:foreign-address-unsigned fv))))

(defun %clisp-free-callback (callback-var)
  (when-let ((callback (symbol-value callback-var)))
    (ffi:foreign-free callback)
    (setf (symbol-value callback-var) nil))
  (values))
