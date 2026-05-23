
(in-package #:tffi)


(eval-when (:compile-toplevel :load-toplevel :execute)

  (defun %make-primitive-type-names ()
    (let ((types (make-hash-table :test 'eq)))
      (%setf-key-value types
                      :void                   nil
                      :char                   ffi:character
                      :signed-char            ffi:character
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
                      :long-long              ffi:sint64
                      :long-long-int          ffi:sint64
                      :signed-long-long       ffi:sint64
                      :signed-long-long-int   ffi:sint64
                      :unsigned-long-long     ffi:uint64
                      :unsigned-long-long-int ffi:uint64
                      :float                  ffi:single-float
                      :double                 ffi:double-float
                      :long-double            ffi:lon
                      :size-t                 sb-alien:size-t
                      :ssize-t                sb-alien:ssize-t
                      :ptrdiff-t              sb-alien:ssize-t
                      :int8-t                 (sb-alien:signed 8)
                      :uint8-t                (sb-alien:unsigned 8)
                      :int16-t                (sb-alien:signed 16)
                      :uint16-t               (sb-alien:unsigned 16)
                      :int32-t                (sb-alien:signed 32)
                      :uint32-t               (sb-alien:unsigned 32)
                      :int64-t                (sb-alien:signed 64)
                      :uint64-t               (sb-alien:unsigned 64))
      (values types)))
  
  (defparameter *primitive-type-names* (%make-primitive-type-names))

  (defun %type-name-type (type-name)
    (if (consp type-name)(eval-when (:compile-toplevel :load-toplevel :execute)

  (defun %make-primitive-type-names ()
    (let ((types (make-hash-table :test 'eq)))
      (%setf-key-value types
                      :void                   t
                      :char                   sb-alien:char
                      :signed-char            sb-alien:char
                      :unsigned-char          sb-alien:unsigned-char
                      :short                  sb-alien:short
                      :short-int              sb-alien:short
                      :signed-short           sb-alien:short
                      :signed-short-int       sb-alien:short
                      :unsigned-short         sb-alien:unsigned-short
                      :unsigned-short-int     sb-alien:unsigned-short
                      :int                    sb-alien:int
                      :signed                 sb-alien:int
                      :signed-int             sb-alien:int
                      :unsigned               sb-alien:unsigned
                      :unsigned-int           sb-alien:unsigned-int
                      :long                   sb-alien:long
                      :long-int               sb-alien:long
                      :signed-long            sb-alien:long
                      :signed-long-int        sb-alien:long
                      :unsigned-long          sb-alien:unsigned-long
                      :unsigned-long-int      sb-alien:unsigned-long
                      :long-long              sb-alien:long-long
                      :long-long-int          sb-alien:long-long
                      :signed-long-long       sb-alien:long-long
                      :signed-long-long-int   sb-alien:long-long
                      :unsigned-long-long     sb-alien:unsigned-long-long
                      :unsigned-long-long-int sb-alien:unsigned-long-long
                      :float                  sb-alien:float
                      :double                 sb-alien:double
                      :long-double            sb-alien:long-float
                      :size-t                 sb-alien:size-t
                      :ssize-t                sb-alien:ssize-t
                      :ptrdiff-t              sb-alien:ssize-t
                      :int8-t                 (sb-alien:signed 8)
                      :uint8-t                (sb-alien:unsigned 8)
                      :int16-t                (sb-alien:signed 16)
                      :uint16-t               (sb-alien:unsigned 16)
                      :int32-t                (sb-alien:signed 32)
                      :uint32-t               (sb-alien:unsigned 32)
                      :int64-t                (sb-alien:signed 64)
                      :uint64-t               (sb-alien:unsigned 64))
      (values types)))
  
  (defparameter *primitive-type-names* (%make-primitive-type-names))

  (defun %type-name-type (type-name)
    (if (consp type-name)
        (car type-name)
        :primitive))

  (defun %make-primitive-type (type-name)
    (gethash type-name *primitive-type-names*))
  
  (defun %make-struct-type (name)
    `(sb-alien:struct ,name))

  (defun %make-union-type (name)
    `(sb-alien:union ,name))

  (defun %make-array-type (subtype dimensions)
    `(sb-alien:array ,subtype ,@dimensions))

  (defun %make-pointer-type (subtype)
    `(sb-alien:* ,subtype))

  (defun %make-function-type (types)
    (list* 'sb-alien:function types))

  
  (defun %extract-next-specifier (specifiers)
    (if (eq '* (car specifiers))
        (values '* (cdr specifiers) :pointer)
        (loop for num-specs on specifiers
              while (not (eq (car num-specs) '*))
              collect (car num-specs) into nums
              finally (return (values nums num-specs :dimensions)))))

  (defun %translate-type (%type &aux (type (%canonize-type %type)))
    (let* ((type-name (car type))
           (specifiers (cdr type))
           (result-type (case (%type-name-type type-name)
                          (:primitive (%make-primitive-type type-name))
                          (:struct    (%make-struct-type (cadr type-name)))
                          (:union     (%make-union-type (cadr type-name)))
                          (:function  (%make-function-type (mapcar #'%translate-type (cdr type-name)))))))
      (loop while (not (null specifiers))
            do (multiple-value-bind (next-specifier rest-specifiers specifier-type)
                   (%extract-next-specifier specifiers)
                 (case specifier-type
                   (:pointer    (setf result-type (%make-pointer-type result-type)))
                   (:dimensions (setf result-type (%make-array-type result-type next-specifier))))
                 (setf specifiers rest-specifiers)))
      (values result-type)))

  (defmacro %cast (value type)
    `(sb-alien:cast ,value ,(%translate-type type)))
  
  (defmacro %sizeof (type)
    `(sb-alien:alien-size ,(%translate-type type) :bytes))

  (defmacro %allocate (type &optional (size 1 sizep))
    `(sb-alien:make-alien ,type ,@(when sizep `(,size))))

  (defun %free (obj)
    (sb-alien:free-alien obj))

  (defmacro %stack-allocate ((&rest definitions) &body body)
    (loop for (var type value) in definitions
          collect `(,var ,(%translate-type type) ,@(when value `(,value))) into alien-definitions
          finally
             (return
               `(sb-alien:with-alien (,@alien-definitions)
                  ,@body))))

  (defmacro %addr (expr)
    `(sb-alien:addr ,expr))
  
  (defun %deref (obj &rest indices)
    (apply #'sb-alien:deref obj indices))

  (defsetf %deref (obj &rest indices) (new-value)
    `(setf (sb-alien:deref ,obj ,@indices) ,new-value))

  (defun %slot (obj slot-name)
    (sb-alien:addr (sb-alien:slot obj slot-name)))

  (define-compiler-macro %slot (obj slot-name)
    `(sb-alien:addr (sb-alien:slot ,obj ,slot-name)))

  (defsetf %slot (obj slot-name) (new-value)
    `(setf (sb-alien:slot ,obj ,slot-name) ,new-value))

  (defmacro %define-record (struct-or-union name &rest slots)
    (let ((translated-slots (loop for (name type) in slots
                                  collect `(,name ,(%translate-type type)))))
      `(sb-alien:define-alien-type nil
           (,struct-or-union ,name ,@translated-slots))))

  (defmacro %define-struct (name &rest slots)
    `(%define-record sb-alien:struct ,name ,@slots))

  (defmacro %define-union (name &rest slots)
    `(%define-record sb-alien:union ,name ,@slots))

  (defmacro %call-function (name res-type (&rest arg-types) (&rest args))
    (let ((translated-res-type (%translate-type res-type))
          (translated-arg-types (mapcar #'%translate-type arg-types)))
      `(sb-alien:alien-funcall
        (sb-alien:extern-alien ,name (sb-alien:function ,translated-res-type ,@translated-arg-types))
        ,@args)))

  (defmacro %call-function-into (name res-type (&rest arg-types) (&rest args) obj)
    (let ((translated-res-type (%translate-type res-type))
          (translated-arg-types (mapcar #'%translate-type arg-types)))
      `(sb-alien:alien-funcall-into
        (extern-alien ,name (sb-alien:function ,translated-res-type ,@translated-arg-types))
        (sb-alien:alien-sap ,obj) ,@args)))

  (defmacro %define-callback (name res-type (&rest args) &body body)
    (let ((translated-res-type (%translate-type res-type))
          (translated-args (loop for (arg type) in args
                                 collect (list arg (%translate-type type)))))
      `(sb-alien:define-alien-callable ,name ,translated-res-type (,@translated-args)
         ,@body)))

  (defun %get-callback (name)
    (sb-alien:alien-callable-function name))

  (defun %load-shared-object (pathname &key dont-save)
    (sb-alien:load-shared-object pathname :dont-save dont-save)))
        (car type-name)
        :primitive))

  (defun %make-primitive-type (type-name)
    (gethash type-name *primitive-type-names*))
  
  (defun %make-struct-type (name)
    `(sb-alien:struct ,name))

  (defun %make-union-type (name)
    `(sb-alien:union ,name))

  (defun %make-array-type (subtype dimensions)
    `(sb-alien:array ,subtype ,@dimensions))

  (defun %make-pointer-type (subtype)
    `(sb-alien:* ,subtype))

  (defun %make-function-type (types)
    (list* 'sb-alien:function types))

  
  (defun %extract-next-specifier (specifiers)
    (if (eq '* (car specifiers))
        (values '* (cdr specifiers) :pointer)
        (loop for num-specs on specifiers
              while (not (eq (car num-specs) '*))
              collect (car num-specs) into nums
              finally (return (values nums num-specs :dimensions)))))

  (defun %translate-type (%type &aux (type (%canonize-type %type)))
    (let* ((type-name (car type))
           (specifiers (cdr type))
           (result-type (case (%type-name-type type-name)
                          (:primitive (%make-primitive-type type-name))
                          (:struct    (%make-struct-type (cadr type-name)))
                          (:union     (%make-union-type (cadr type-name)))
                          (:function  (%make-function-type (mapcar #'%translate-type (cdr type-name)))))))
      (loop while (not (null specifiers))
            do (multiple-value-bind (next-specifier rest-specifiers specifier-type)
                   (%extract-next-specifier specifiers)
                 (case specifier-type
                   (:pointer    (setf result-type (%make-pointer-type result-type)))
                   (:dimensions (setf result-type (%make-array-type result-type next-specifier))))
                 (setf specifiers rest-specifiers)))
      (values result-type)))

  (defmacro %cast (value type)
    `(sb-alien:cast ,value ,(%translate-type type)))
  
  (defmacro %sizeof (type)
    `(sb-alien:alien-size ,(%translate-type type) :bytes))

  (defmacro %allocate (type &optional (size 1 sizep))
    `(sb-alien:make-alien ,type ,@(when sizep `(,size))))

  (defun %free (obj)
    (sb-alien:free-alien obj))

  (defmacro %stack-allocate ((&rest definitions) &body body)
    (loop for (var type value) in definitions
          collect `(,var ,(%translate-type type) ,@(when value `(,value))) into alien-definitions
          finally
             (return
               `(sb-alien:with-alien (,@alien-definitions)
                  ,@body))))

  (defmacro %addr (expr)
    `(sb-alien:addr ,expr))
  
  (defun %deref (obj &rest indices)
    (apply #'sb-alien:deref obj indices))

  (defsetf %deref (obj &rest indices) (new-value)
    `(setf (sb-alien:deref ,obj ,@indices) ,new-value))

  (defun %slot (obj slot-name)
    (sb-alien:addr (sb-alien:slot obj slot-name)))

  (define-compiler-macro %slot (obj slot-name)
    `(sb-alien:addr (sb-alien:slot ,obj ,slot-name)))

  (defsetf %slot (obj slot-name) (new-value)
    `(setf (sb-alien:slot ,obj ,slot-name) ,new-value))

  (defmacro %define-record (struct-or-union name &rest slots)
    (let ((translated-slots (loop for (name type) in slots
                                  collect `(,name ,(%translate-type type)))))
      `(sb-alien:define-alien-type nil
           (,struct-or-union ,name ,@translated-slots))))

  (defmacro %define-struct (name &rest slots)
    `(%define-record sb-alien:struct ,name ,@slots))

  (defmacro %define-union (name &rest slots)
    `(%define-record sb-alien:union ,name ,@slots))

  (defmacro %call-function (name res-type (&rest arg-types) (&rest args))
    (let ((translated-res-type (%translate-type res-type))
          (translated-arg-types (mapcar #'%translate-type arg-types)))
      `(sb-alien:alien-funcall
        (sb-alien:extern-alien ,name (sb-alien:function ,translated-res-type ,@translated-arg-types))
        ,@args)))

  (defmacro %call-function-into (name res-type (&rest arg-types) (&rest args) obj)
    (let ((translated-res-type (%translate-type res-type))
          (translated-arg-types (mapcar #'%translate-type arg-types)))
      `(sb-alien:alien-funcall-into
        (extern-alien ,name (sb-alien:function ,translated-res-type ,@translated-arg-types))
        (sb-alien:alien-sap ,obj) ,@args)))

  (defmacro %define-callback (name res-type (&rest args) &body body)
    (let ((translated-res-type (%translate-type res-type))
          (translated-args (loop for (arg type) in args
                                 collect (list arg (%translate-type type)))))
      `(sb-alien:define-alien-callable ,name ,translated-res-type (,@translated-args)
         ,@body)))

  (defun %get-callback (name)
    (sb-alien:alien-callable-function name))

  (defun %load-shared-object (pathname &key dont-save)
    (sb-alien:load-shared-object pathname :dont-save dont-save)))
