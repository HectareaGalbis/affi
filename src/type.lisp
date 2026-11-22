
(in-package #:affi)


(eval-when (:compile-toplevel :load-toplevel :execute)

  (defparameter *primitive-types*
    '(:void
      :char
      :signed-char
      :unsigned-char
      :short
      :short-int
      :signed-short
      :signed-short-int
      :unsigned-short
      :unsigned-short-int
      :int
      :signed
      :signed-int
      :unsigned
      :unsigned-int
      :long
      :long-int
      :signed-long
      :signed-long-int
      :unsigned-long
      :unsigned-long-int
      :long-long
      :long-long-int
      :signed-long-long
      :signed-long-long-int
      :unsigned-long-long
      :unsigned-long-long-int
      :float
      :double
      ; :long-double
      :size-t
      :ssize-t
      :ptrdiff-t
      :int8-t
      :uint8-t
      :int16-t
      :uint16-t
      :int32-t
      :uint32-t
      :int64-t
      :uint64-t
      :bool
      :intptr-t
      :uintptr-t
      :wchar-t))

  (defparameter *calling-conventions* '(:cdecl :stdcall))

  (defparameter *complex-types*
    '(:struct
      :union
      :function))

  (defclass ffi-type () ())
  
  (defclass primitive-type (ffi-type)
    ((name :initarg :name
           :initform (error "Expected type argument")
           :accessor primitive-type-name)))

  (defclass struct-type (ffi-type)
    ((name :initarg :name
           :initform (error "Expected name argument")
           :accessor struct-type-name)))

  (defclass union-type (ffi-type)
    ((name :initarg :name
           :initform (error "Expected name argument")
           :accessor union-type-name)))

  (defclass function-type (ffi-type)
    ((result-type :initarg :result-type
                  :initform (error "Expected result-type argument")
                  :accessor function-type-result-type)
     (argument-types :initarg :argument-types
                     :initform (error "Expected argument-types argument")
                     :accessor function-type-argument-types)
     (convention :initarg :convention
                 :initform :cdecl
                 :accessor function-type-convention)
     (variadicp :initarg :variadicp
                :initform nil
                :accessor function-type-variadic-p)))

  (defclass array-type (ffi-type)
    ((data-type :initarg :data-type
                :initform (error "Expected data-type argument")
                :accessor array-type-data-type)
     (size :initarg :size
           :initform (error "Expected size argument")
           :accessor array-type-size)))

  (defclass pointer-type (ffi-type)
    ((data-type :initarg :data-type
                :initform (error "Expected data-type argument")
                :accessor pointer-type-data-type)))

  (defun %canonize-type (type)
    (let ((ltype (ensure-list type)))
      (if (member (car ltype) *complex-types*)
          (list ltype)
          ltype)))

  (define-condition bad-type-error (program-error)
    ((sources :initform nil :accessor bad-type-error-sources)
     (message :initarg :message :initform (error "Need a message") :reader bad-type-error-message))
    (:report (lambda (c s)
               (let ((*print-circle* nil))
                 (loop for source in (bad-type-error-sources c)
                       do (format s "> ~s~%" source))
                 (format s "~a" (bad-type-error-message c))))))
  
  (defun %parse-convention (convention)
    (unless (member convention *calling-conventions*)
      (syntax-error "Expected a calling convention: ~{~s~^, ~}" *calling-conventions*))
    (values convention))

  (defun parse-convention (convention)
    (with-syntax-error-handler convention
      (%parse-convention convention)))

  (defun %convention-spec-p (spec)
    (and (consp spec)
         (eq (car spec) :convention)))

  (defun %parse-convention-spec (spec)
    (unless (= (length spec) 2)
      (syntax-error "Expected 1 and only 1 element after :CONVENTION"))
    (parse-convention (cadr spec)))

  (defun parse-convention-spec (spec)
    (with-syntax-error-handler spec
      (%parse-convention-spec spec)))

  (defun %parse-function-types (types)
    (let ((convention :cdecl)
          (variadicp nil))
      (when (%convention-spec-p (car types))
        (setf convention (parse-convention-spec (car types)))
        (setf types (cdr types)))
      (when (null types)
        (syntax-error "Expected at least the result type"))
      (when-let ((rest-position (position '&rest types)))
        (unless (= rest-position (1- (length types)))
          (syntax-error "&REST must be the last element"))
        (when (zerop rest-position)
          (syntax-error "Expected the result type before &REST"))
        (setf variadicp t)
        (setf types (butlast types)))
      (make-instance 'function-type :result-type (parse-foreign-type (car types))
                                    :argument-types (mapcar #'parse-foreign-type (cdr types))
                                    :convention convention
                                    :variadicp variadicp)))

  (defun parse-function-types (types)
    (with-syntax-error-handler types
      (unless (listp types)
        (syntax-error "Expected a list of types"))
      (%parse-function-types types)))

  (defun %parse-type-name (type-name)
    (cond
      ((symbolp type-name)
       (unless (member type-name *primitive-types*)
         (syntax-error "Unknown type"))
       (make-instance 'primitive-type :name type-name))
      ((consp type-name)
       (case (car type-name)
         ((:struct :union)
          (unless (= (length type-name) 2)
            (syntax-error "Expected 1 and only 1 element after ~s" (car type-name)))
          (let ((name (cadr type-name)))
            (unless (symbolp name)
              (syntax-error "Expected a symbol after ~s" (car type-name)))
            (let ((instance-type (if (eq (car type-name) :struct) 'struct-type 'union-type)))
              (make-instance instance-type :name name))))
         ((:function)
          (%parse-function-types (cdr type-name)))
         (otherwise
          (syntax-error "Expected :STRUCT, :UNION or :FUNCTION"))))
      (t (syntax-error "Expected a symbol or a list"))))

  (defun parse-type-name (type-name)
    (with-syntax-error-handler type-name
      (%parse-type-name type-name)))

  (defun %parse-type-specifier (specifier data-type)
    (cond
      ((integerp specifier)
       (unless (plusp specifier)
         (syntax-error "Expected a positive integer"))
       (make-instance 'array-type :data-type data-type :size specifier))
      ((eq specifier '*)
       (make-instance 'pointer-type :data-type data-type))
      (t (syntax-error "Expected a positive integer or the symbol *"))))

  (defun parse-type-specifier (specifier data-type)
    (with-syntax-error-handler specifier
      (%parse-type-specifier specifier data-type)))

  ;; Specifiers are applied from left to right, except consecutive array dimensions,
  ;; which are read in the same order as in C: (:INT 4 3) is int[4][3], an array of
  ;; 4 arrays of 3 integers.
  (defun parse-type-specifiers (specifiers data-type)
    (loop while specifiers
          do (if (integerp (car specifiers))
                 (let ((dimensions (loop while (integerp (car specifiers))
                                         collect (pop specifiers))))
                   (dolist (dimension (reverse dimensions))
                     (setf data-type (parse-type-specifier dimension data-type))))
                 (setf data-type (parse-type-specifier (pop specifiers) data-type))))
    (values data-type))
  
  (defun %parse-foreign-type (ctype)
    (let ((data-type (parse-type-name (car ctype))))
      (parse-type-specifiers (cdr ctype) data-type)))

  (defun parse-foreign-type (type)
    (with-syntax-error-handler type
      (%parse-foreign-type (%canonize-type type))))

  (defun type-name (%type &aux (type (%canonize-type %type)))
    (car type))

  (defun type-specifiers (%type &aux (type (%canonize-type %type)))
    (cdr type))

  )
