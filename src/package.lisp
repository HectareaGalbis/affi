
(defpackage #:trivial-ffi
  (:use #:cl #:alexandria)
  (:nicknames #:tffi)
  (:export #:cast #:sizeof #:allocate #:free #:stack-allocate #:addr #:deref #:slot
           #:define-struct #:define-union #:extern #:define-variable #:call-function #:define-function
           #:call-function-into #:define-callback #:get-callback #:load-shared-object))
