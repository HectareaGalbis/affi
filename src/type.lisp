
(in-package #:tffi)


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
      :long-double
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
      :uint64-t))

  (defun %check-type-name (type-name)
    (cond
      ((symbolp type-name)
       (unless (member type-name *primitive-types*)
         (error "Unknown primitive type: ~a" type-name)))
      ((consp type-name)
       (case (car type-name)
         ((:struct :union)
          (unless (= (length type-name) 2)
            (error "Bad type: ~a" type-name))
          (let ((name (cadr type-name)))
            (unless (symbolp name)
              (error "Expected a symbol as name: ~a" type-name))
            (unless (gethash name *record-types*)
              (error "Record type not defined: ~a" type-name))))
         ((:function)
          (unless (not (null (cdr type-name)))
            (error "Expected at least the result type: ~a" type-name))
          (loop for arg-type in (cdr type-name)
                do (check-foreign-type arg-type)))
         (otherwise
          (error "Expected :struct, :union or :function : ~a" type-name))))
      (t (error "Expected a symbol or a list: ~a" type-name)))
    (values t))

  (defun %check-type-specifier (specifier)
    (cond
      ((integerp specifier)
       (unless (plusp specifier)
         (error "Expected a positive integer: ~a" specifier)))
      (t
       (unless (eq specifier '*)
         (error "Expected a positive integer or the symbol *: ~a" specifier)))))
  
  (defun %check-foreign-type (%type &aux (type (canonize-type %type)))
    (%check-type-name (car type))
    (%check-type-specifiers (cdr type)))

  (defun %canonize-type (type)
    (let ((ltype (ensure-list type)))
      (if (member (car ltype) '(:struct :union :function))
          (list ltype)
          ltype))))
