
(defpackage #:affi
  (:use #:cl #:alexandria)
  (:export #:cast #:null-pointer #:sizeof #:allocate #:free #:stack-allocate #:addr #:deref #:slot
           #:define-struct #:define-union #:define-variable #:call-function #:define-function
           #:define-callback #:load-shared-object
           #:funcall-pointer #:free-callback #:close-shared-object #:foreign-symbol-p
           #:make-null-pointer #:make-pointer #:pointer-address #:pointer-eq
           #:copy-memory #:fill-memory #:allocate-zeroed #:with-allocate #:offsetof #:alignof
           #:foreign-string-to-lisp #:lisp-string-to-foreign #:foreign-string-size
           #:define-enum #:enum-value #:enum-key))
