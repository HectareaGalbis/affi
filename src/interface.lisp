
(in-package #:tffi)

(defmacro cast (value type)
  `(%cast ,value ,type))

(defmacro sizeof (type)
  `(%sizeof ,type))

(defmacro allocate (type &optional (size 1 sizep))
  `(%allocate ,type ,@(when sizep `(,size))))

(defun free (obj)
  (%free obj))

(defmacro stack-allocate ((&rest definitions) &body body)
  `(%stack-allocate (,@definitions) ,@body))

(defmacro addr (expr)
  `(%addr ,expr))

(defun deref (obj &rest indices)
  (apply #'%deref obj indices))

(defsetf deref (obj &rest indices) (new-value)
  `(setf (%deref ,obj ,@indices) ,new-value))

(defun slot (obj slot-name)
  (%slot obj slot-name))

(defsetf slot (obj slot-name) (new-value)
  `(setf (%slot ,obj ,slot-name) ,new-value))

(defmacro define-struct (name &body slots)
  `(%define-struct ,name ,@slots))

(defmacro define-union (name &body slots)
  `(%define-union ,name ,@slots))

(defmacro call-function (name res-type (&rest arg-types) (&rest args))
  `(%call-function ,name ,res-type ,arg-types ,args))

(defmacro call-function-into (name res-type (&rest arg-types) (&rest args) obj)
  `(%call-function-into ,name ,res-type ,arg-types ,args ,obj))

(defmacro define-callback (name res-type (&rest args) &body body)
  `(%define-callback ,name ,res-type (,@args) ,@body))

(defun get-callback (name)
  (%get-callback name))

(defun load-shared-object (pathname &key dont-save)
  (%load-shared-object pathname :dont-save dont-save))

(defmacro define-variable ((name foreign-name) type)
  `(%define-variable (,name ,foreign-name) ,type))

(defmacro define-function ((name foreign-name) res-type (&rest arg-types))
  (loop for arg-type in arg-types
        collect (gensym) into function-args
        finally
           (return
             `(defun ,name (,@function-args)
                (call-function ,foreign-name ,res-type ,arg-types ,function-args)))))


