
(in-package #:affi)


(eval-when (:compile-toplevel :load-toplevel :execute)

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
                      ; :long-double          Not supported
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
                      :uint64-t               (sb-alien:unsigned 64)
                      :bool                   (sb-alien:unsigned 8)
                      :intptr-t               (sb-alien:signed #.sb-vm:n-machine-word-bits)
                      :uintptr-t              (sb-alien:unsigned #.sb-vm:n-machine-word-bits)
                      :wchar-t                #+win32 (sb-alien:unsigned 16) #-win32 (sb-alien:signed 32))
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

  (defgeneric %translate-type (ptype))

  (defmethod %translate-type ((ptype primitive-type))
    (gethash (primitive-type-name ptype) *primitive-type-names*))

  (defmethod %translate-type ((ptype struct-type))
    `(sb-alien:struct ,(struct-type-name ptype)))

  (defmethod %translate-type ((ptype union-type))
    `(sb-alien:union ,(union-type-name ptype)))

  (defun %translate-result-type (ret-type)
    (if (and (typep ret-type 'primitive-type)
             (eq (primitive-type-name ret-type) :void))
        'sb-alien:void
        (%translate-type ret-type)))

  (defmethod %translate-type ((ptype function-type))
    (let ((t-ret-type (%translate-result-type (function-type-result-type ptype))))
      `(sb-alien:function ,(if (eq (function-type-convention ptype) :stdcall)
                               `(:stdcall ,t-ret-type)
                               t-ret-type)
                          ,@(mapcar #'%translate-type (function-type-argument-types ptype))
                          ,@(when (function-type-variadic-p ptype)
                              '(&rest)))))

  (defmethod %translate-type ((ptype array-type))
    `(sb-alien:array ,(%translate-type (array-type-data-type ptype)) ,(array-type-size ptype)))

  (defmethod %translate-type ((ptype pointer-type))
    `(sb-alien:* ,(%translate-type (pointer-type-data-type ptype))))

  (defun %cast (value type)
    `(sb-alien:cast ,value ,(%translate-type type)))

  (defun %null-pointer (value)
    (sb-alien:null-alien value))
  
  (defun %sizeof (type)
    `(sb-alien:alien-size ,(%translate-type type) :bytes))

  (defun %allocate (type size)
    `(sb-alien:make-alien ,(%translate-type type) ,size))

  (defun %free (obj)
    (sb-alien:free-alien obj))

  (defun %stack-allocate (definitions body)
    (loop for (var type value) in definitions
          collect `(,var ,(%translate-type type) ,@(when value `(,value))) into alien-definitions
          finally
             (return
               `(sb-alien:with-alien (,@alien-definitions)
                  ,@body))))

  (defun %addr (expr)
    (if (symbolp expr)
        (if-let ((func-info (function-info expr)))
          (with-slots (callbackp funcvar functype) func-info
            (if callbackp
                `(sb-alien:cast (sb-alien:alien-callable-function ',funcvar) (* ,functype))
                `(sb-alien:addr ,funcvar)))
          `(sb-alien:addr ,expr))
        (case (car expr)
          (deref `(sb-alien:addr (sb-alien:deref ,@(cdr expr))))
          (slot `(sb-alien:addr (sb-alien:slot ,@(cdr expr)))))))
  
  (defun %deref (obj indices)
    (apply #'sb-alien:deref obj indices))

  (defun %setf-deref (obj indices new-value)
    `(setf (sb-alien:deref ,obj ,@indices) ,new-value))

  (defun %slot (obj slot-name)
    (sb-alien:slot obj slot-name))

  (define-compiler-macro %slot (obj slot-name)
    `(sb-alien:slot ,obj ,slot-name))

  (defun %setf-slot (obj slot-name new-value)
    `(setf (sb-alien:slot ,obj ,slot-name) ,new-value))

  (defun %define-record (struct-or-union name slots)
    (let ((translated-slots (loop for (name type) in slots
                                  collect `(,name ,(%translate-type type)))))
      `(sb-alien:define-alien-type nil
           (,struct-or-union ,name ,@translated-slots))))

  (defun %define-struct (name slots)
    (%define-record 'sb-alien:struct name slots))

  (defun %define-union (name slots)
    (%define-record 'sb-alien:union name slots))

  (defun %define-variable (name foreign-name type)
    `(sb-alien:define-alien-variable (,foreign-name ,name) ,(%translate-type type)))
  
  (defun %call-function (name functype args)
    `(sb-alien:alien-funcall
      (sb-alien:extern-alien ,name ,(%translate-type functype)) ,@args))

  (defun %define-function (name foreign-name functype args)
    (let* ((translated-functype (%translate-type functype))
           (translated-result-type (%translate-result-type (function-type-result-type functype)))
           (translated-arg-types (mapcar #'%translate-type (function-type-argument-types functype)))
           (translated-args (loop for translated-arg-type in translated-arg-types
                                  for arg in args
                                  collect (list arg translated-arg-type)))
           (func-var (or (if-let ((finfo (function-info name)))
                           (slot-value finfo 'funcvar))
                         (gensym (symbol-name name)))))
      `(progn
         (eval-when (:compile-toplevel :load-toplevel :execute)
           (setf (function-info ',name)
                 (make-instance 'function-info :funcvar ',func-var
                                               :functype ',translated-functype)))
         (sb-alien:define-alien-variable (,foreign-name ,func-var) ,translated-functype)
         ,(if (eq (function-type-convention functype) :stdcall)
              `(defun ,name (,@args)
                 (sb-alien:alien-funcall
                  (sb-alien:extern-alien ,foreign-name ,translated-functype) ,@args))
              `(sb-alien:define-alien-routine (,foreign-name ,name) ,translated-result-type
                 ,@translated-args)))))

  (defun %define-callback (name functype args body)
    (with-gensyms (alien-callback)
      (let* ((translated-functype (%translate-type functype))
             (translated-result-type (%translate-result-type (function-type-result-type functype)))
             (translated-arg-types (mapcar #'%translate-type (function-type-argument-types functype)))
             (translated-args (loop for arg in args
                                    for type in translated-arg-types
                                    collect (list arg type))))
        `(progn
           (eval-when (:compile-toplevel :load-toplevel :execute)
             (setf (function-info ',name)
                   (make-instance 'function-info :callbackp t
                                                 :funcvar ',alien-callback
                                                 :functype ',translated-functype)))
           (sb-alien:define-alien-callable ,alien-callback ,translated-result-type (,@translated-args)
             ,@body)
           (defun ,name (,@args)
             ,@body)))))

  (defun %load-shared-object (pathname dont-save)
    (sb-alien:load-shared-object pathname :dont-save dont-save))

  (defun %close-shared-object (pathname)
    (sb-alien:unload-shared-object pathname))

  (defun %foreign-symbol-p (foreign-name)
    (and (sb-sys:find-foreign-symbol-address foreign-name) t))

  (defun %funcall-pointer (ptr functype args)
    `(sb-alien:alien-funcall
      (sb-alien:cast ,ptr (sb-alien:* ,(%translate-type functype))) ,@args))

  (defun %make-null-pointer (type)
    `(sb-alien:sap-alien (sb-sys:int-sap 0) ,(%translate-type type)))

  (defun %make-pointer (address type)
    `(sb-alien:sap-alien (sb-sys:int-sap ,address) ,(%translate-type type)))

  (defun %pointer-address (ptr)
    (sb-sys:sap-int (sb-alien:alien-sap ptr)))

  (defun %offsetof (type slot-name)
    `(%sbcl-offsetof ',(%translate-type type) ',slot-name))

  (defun %alignof (type)
    `(%sbcl-alignof ',(%translate-type type)))

  (defun %free-callback (name)
    (let ((func-info (function-info name)))
      (unless (and func-info (slot-value func-info 'callbackp))
        (error "~s is not a callback" name))
      (with-slots (funcvar functype) func-info
        `(%sbcl-free-callback ',funcvar ',functype))))

  (defun %string-to-octets (string encoding)
    (sb-ext:string-to-octets string :external-format encoding))

  (defun %octets-to-string (octets encoding)
    (sb-ext:octets-to-string octets :external-format encoding)))


(defun %sbcl-offsetof (translated-type slot-name)
  (let ((alien-type (sb-alien::parse-alien-type translated-type nil)))
    (/ (sb-alien-internals:alien-record-field-offset
        (sb-alien::slot-or-lose alien-type slot-name))
       8)))

(defun %sbcl-alignof (translated-type)
  (/ (sb-alien-internals:alien-type-alignment
      (sb-alien::parse-alien-type translated-type nil))
     8))

(defun %sbcl-free-callback (funcvar functype)
  (when-let ((callback (gethash funcvar sb-alien::*alien-callables*)))
    (sb-alien::free-alien-callable callback functype)
    (remhash funcvar sb-alien::*alien-callables*))
  (values))
