(in-package #:test-affi)


;; Test framework

(defvar *failures* nil)

(defmacro check (form)
  `(handler-case
       (unless ,form
         (push ',form *failures*)
         (format t "~&FAIL: ~s~%" ',form))
     (error (e)
       (push ',form *failures*)
       (format t "~&ERROR: ~s~%  ~a~%" ',form e))))


;; 0. Build and open the C library

(defun build-test-library ()
  (let ((source (asdf:system-relative-pathname "affi" "test/c/test-ffi.c"))
        (output (asdf:apply-output-translations
                 (asdf:system-relative-pathname "affi" "test/c/libtest-ffi.so"))))
    (ensure-directories-exist output)
    (uiop:run-program (list "cc" "-shared" "-fPIC" "-std=c99"
                            "-o" (uiop:native-namestring output)
                            (uiop:native-namestring source))
                      :output t :error-output t)
    (values output)))

(load-shared-object (build-test-library))


;; 1. Global variables

(define-variable (a "a") :char)
(define-variable (ten "ten") :int)
(define-variable (pi-num "pi") :float)
(define-variable (e "e") :double)

(defun test-global-variables ()
  (check (char= (code-char a) #\a))
  (check (= ten 10))
  (check (= pi-num 3.14159274101257324219f0))
  (check (= e 2.71828182845904523536028747135266250d0)))


;; 2. Simple functions

(define-function (get-five "get_five") :int ())
(define-function (sum "sum") :double ((x :int) (y :float) (z :double)))

(defun test-simple-functions ()
  (check (= (get-five) 5))
  (check (= (sum 10 3.5 4.76d0) (+ 10d0 (float 3.5 1d0) 4.76d0))))


;; 3. Global variables address

(define-function (check-vars "check_vars") :int
  ((a-ptr (:char *)) (ten-ptr (:int *)) (pi-ptr (:float *)) (e-ptr (:double *))))

(defun test-global-variables-address ()
  (check (= (check-vars (addr a) (addr ten) (addr pi-num) (addr e)) 1)))


;; 4. Arrays

(define-variable (fibo "fibo") (:int 10))
(define-function (add-array "add_array") :void ((arr1 (:int 10)) (arr2 (:int 10)) (arr3 (:int 10))))
(define-function (check-fibo-7 "check_fibo_7") :int ((fibo7 (:int *))))

(defparameter *fibo* '(0 1 1 2 3 5 8 13 21 34))

(defun test-arrays ()
  (check (equal (loop for i from 0 below 10 collect (deref fibo i)) *fibo*))
  (stack-allocate ((arr2 (:int 10))
                   (arr3 (:int 10)))
    (loop for i from 0 below 10
          do (setf (deref arr2 i) i))
    (add-array fibo arr2 arr3)
    (check (equal (loop for i from 0 below 10 collect (deref arr3 i))
                  (loop for f in *fibo*
                        for i from 0
                        collect (+ f i)))))
  (check (= (check-fibo-7 (addr (deref fibo 7))) 1)))


;; 5. Strings

(define-variable (text "text") (:char *))
(define-function (text-uppercase "text_uppercase") :void ((dst (:char *))))

(defun foreign-strlen (str)
  (loop for i from 0
        while (/= (deref str i) 0)
        count t))

(defun to-lisp-string (str)
  (let ((len (foreign-strlen str)))
    (let ((s (make-string len)))
      (dotimes (i len)
        (setf (char s i) (code-char (deref str i))))
      (values s))))

(defun test-strings ()
  (check (string= (to-lisp-string text) "this is awesome!"))
  (let* ((len (foreign-strlen text))
         (new-text (allocate :char (1+ len))))
    (unwind-protect
         (progn
           (dotimes (i (1+ len))
             (setf (deref new-text i) (deref text i)))
           (text-uppercase new-text)
           (check (string= (to-lisp-string new-text) "THIS IS AWESOME!"))
           (check (string= (to-lisp-string text) "this is awesome!")))
      (free new-text))))


;; 6. Structs

(define-struct ffi-test-t
  (n :size-t)
  (ns (:int *)))

(define-function (get-value "get_value") (:struct ffi-test-t) ((n :size-t)))
(define-function (fill-values "fill_values") :void ((test ((:struct ffi-test-t) *))))
(define-function (sum-values "sum_values") :void ((test ((:struct ffi-test-t) *)) (value (:int *))))
(define-function (free-values "free_values") :void ((test (:struct ffi-test-t))))

(defun test-structs ()
  (stack-allocate ((test (:struct ffi-test-t) (get-value 10))
                   (result :int))
    (check (= (slot test 'n) 10))
    (fill-values (addr test))
    (check (equal (loop for i from 0 below 10 collect (deref (slot test 'ns) i))
                  '(1 2 3 4 5 6 7 8 9 10)))
    (sum-values (addr test) (addr result))
    (free-values test)
    (check (= result 55))))


;; 7. Callbacks

(define-function (mult2 "mult2") :int ((x :int)))
(define-function (check-mult2 "check_mult2") :int ((mult2-ptr ((:function :int :int) *))))
(define-variable (func-ptr "func_ptr") ((:function :int :int) *))
(define-function (op "op") :int ((op-ptr ((:function :int :int) *)) (x :int)))

(define-callback mult3 :int ((x :int))
  (* x 3))

(defun test-callbacks ()
  (check (= (mult2 4) 8))
  (check (= (check-mult2 (addr mult2)) 1))
  (check (= (op (addr mult2) 8) 16))
  (check (= (op func-ptr 10) 20))
  (check (= (mult3 3) 9))
  (check (= (op (addr mult3) 7) 21)))


;; Run

(defun run-tests ()
  (let ((*failures* nil))
    (test-global-variables)
    (test-simple-functions)
    (test-global-variables-address)
    (test-arrays)
    (test-strings)
    (test-structs)
    (test-callbacks)
    (if *failures*
        (format t "~&~a test(s) failed.~%" (length *failures*))
        (format t "~&All tests passed.~%"))
    (null *failures*)))
