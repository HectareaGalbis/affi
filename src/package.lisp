
(defpackage #:affi
  (:use #:cl #:alexandria)
  (:export #:cast #:null-pointer #:sizeof #:allocate #:free #:stack-allocate #:addr #:deref #:slot
           #:define-struct #:define-union #:define-variable #:call-function #:define-function
           #:define-callback #:load-shared-object))
