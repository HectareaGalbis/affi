
(in-package #:test-tffi)

;; 0. Open lib
(load-shared-object "libtest-ffi.so")

;; 1. Global variables
(define-variable (a "a") :char)
(define-variable (ten "ten") :int)
(define-variable (pi-num "pi") :float)
(define-variable (e "e") :double)

(print (code-char a))
(print ten)
(print pi-num)
(print e)


;; 2. Simple function
(define-function (get-five "get_five") :int ())
(define-function (sum "sum") :double (:int :float :double))

(print (get-five))
(print (sum 10 3.5 4.76d0))

;; 3. Global variable address
(define-function (check-vars "check_vars") :int ((:char *) (:int *) (:float *) (:double *)))

(print (check-vars (addr a) (addr ten) (addr pi-num) (addr e)))

;; 4. Arrays
(define-variable (fibo "fibo") (:int 10))
(define-function (add-array "add_array") :void ((:int 10) (:int 10) (:int 10)))

(stack-allocate ((arg2 (:int 10))
                 (arg3 (:int 10)))
  (loop for i from 0 below 10
        do (setf (deref arg2 i) i))
  (add-array fibo arg2 arg3)
  (loop for i from 0 below 10
        do (format t "~%~a + ~a = ~a" (deref fibo i) (deref arg2 i) (deref arg3 i))))

(define-function (check-fibo-7 "check_fibo_7") :int ((:int *)))

(print (check-fibo-7 (addr (deref fibo 7))))

;; 5. Strings
(define-variable (text "text") (:char *))
(define-function (text-uppercase "text_uppercase") :void ((:char *)))

(defun strlen (str)
  (loop for i from 0
        while (not (= (deref str i) 0))
        sum 1))

(defun to-lisp-string (str)
  (let ((s (make-array 0 :element-type 'character :fill-pointer 0 :adjustable t)))
    (loop for i from 0
          while (not (= (deref str i) 0))
          do (vector-push-extend (code-char (deref str i)) s))
    (values s)))

(let* ((new-text (allocate :char (1+ (strlen text)))))
  (print (to-lisp-string text))
  (text-uppercase new-text)
  (print (to-lisp-string new-text)))


;; 6. Structs
(define-struct ffi-test-t
  (n :size-t)
  (ns (:int *)))
(define-function (fill-values "fill_values") :void (((:struct ffi-test-t) *)))
(define-function (sum-values "sum_values") :void (((:struct ffi-test-t) *) (:int *)))
(define-function (free-values "free_values") :void ((:struct ffi-test-t)))

(stack-allocate ((test (:struct ffi-test-t))
                 (values :int))
  (setf (slot test 'n) 10)
  (fill-values (addr test))
  (sum-values (addr test) (addr values))
  (free-values test)
  (print values))
