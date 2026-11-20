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


;; 8. Foreign strings

(defun test-foreign-strings ()
  (check (string= (foreign-string-to-lisp text) "this is awesome!"))
  (check (string= (foreign-string-to-lisp text :count 4) "this"))
  (check (null (foreign-string-to-lisp (make-null-pointer (:char *)))))
  (let ((str (lisp-string-to-foreign "año ñu")))
    (unwind-protect
         (progn
           (check (= (foreign-strlen str) 8))
           (check (string= (foreign-string-to-lisp str) "año ñu")))
      (free str)))
  (with-foreign-string ((str "hello")
                        (latin "año" :encoding :latin-1))
    (text-uppercase str)
    (check (string= (foreign-string-to-lisp str) "HELLO"))
    (check (= (foreign-strlen latin) 3))
    (check (string= (foreign-string-to-lisp latin :encoding :latin-1) "año"))))


;; 9. Pointers

(define-struct opaque-t)

(defun test-pointers ()
  (check (null-pointer (make-null-pointer)))
  (check (null-pointer (make-null-pointer (:int *))))
  (check (null-pointer (make-null-pointer ((:struct opaque-t) *))))
  (check (= (pointer-address (make-null-pointer (:int *))) 0))
  (check (not (null-pointer (addr ten))))
  (check (pointer-eq (addr (deref fibo 7)) (addr (deref fibo 7))))
  (check (not (pointer-eq (addr (deref fibo 7)) (addr (deref fibo 8)))))
  (check (= (- (pointer-address (addr (deref fibo 8)))
               (pointer-address (addr (deref fibo 7))))
            (sizeof :int)))
  (let ((ptr (make-pointer (pointer-address (addr (deref fibo 0))) (:int *))))
    (check (pointer-eq ptr (addr (deref fibo 0))))
    (check (= (deref ptr 9) 34))
    (check (= (check-fibo-7 (make-pointer (pointer-address (addr (deref fibo 7))) (:int *))) 1))))


;; 10. Function pointers

(define-callback (mult4 :convention :cdecl) :int ((x :int))
  (* x 4))

(define-callback mult5 :int ((x :int))
  (* x 5))

(defun test-function-pointers ()
  (check (= (funcall-pointer func-ptr (:int :int) 10) 20))
  (check (= (funcall-pointer (addr mult2) (:int :int) 7) 14))
  (check (= (funcall-pointer (addr mult3) (:int :int) 7) 21))
  (check (= (funcall-pointer (addr mult2) ((:convention :cdecl) :int :int) 3) 6))
  (check (= (call-function "mult2" ((:convention :cdecl) :int :int) 5) 10))
  (check (= (op (addr mult4) 5) 20))
  (check (= (op (addr mult5) 2) 10))
  (free-callback mult5)
  (check (= (mult5 3) 15)))


;; 11. Memory

(defun test-memory ()
  (let ((ptr (allocate-zeroed :int 8)))
    (unwind-protect
         (check (loop for i from 0 below 8
                      always (zerop (deref ptr i))))
      (free ptr)))
  (with-allocate ((src :int 4)
                  (dst :int 4))
    (dotimes (i 4)
      (setf (deref src i) (* 10 i)))
    (check (eq (fill-memory dst 0 (* 4 (sizeof :int))) dst))
    (check (loop for i from 0 below 4
                 always (zerop (deref dst i))))
    (check (eq (copy-memory dst src (* 4 (sizeof :int))) dst))
    (check (equal (loop for i from 0 below 4 collect (deref dst i))
                  '(0 10 20 30))))
  (with-allocate ((bytes :uint8-t 4))
    (fill-memory bytes 255 4)
    (check (loop for i from 0 below 4
                 always (= (deref bytes i) 255)))))


;; 12. Type aliases and enumerations

(define-type my-int :int)
(define-type int-ptr (:int *))

(define-enum color
  :red
  (:green 5)
  :blue)

(define-function (mult2-alias "mult2") my-int ((x my-int)))
(define-function (check-fibo-7-alias "check_fibo_7") my-int ((fibo7 int-ptr)))

(defun test-aliases-and-enums ()
  (check (= (sizeof my-int) (sizeof :int)))
  (check (= (sizeof int-ptr) (sizeof (:int *))))
  (check (= (sizeof (my-int 10)) (sizeof (:int 10))))
  (check (= (mult2-alias 21) 42))
  (check (= (check-fibo-7-alias (addr (deref fibo 7))) 1))
  (check (= (sizeof color) (sizeof :int)))
  (check (= (enum-value 'color :red) 0))
  (check (= (enum-value 'color :green) 5))
  (check (= (enum-value 'color :blue) 6))
  (check (eq (enum-key 'color 5) :green))
  (check (null (enum-key 'color 1)))
  (check (= (mult2 (enum-value 'color :blue)) 12))
  (stack-allocate ((c color (enum-value 'color :green)))
    (check (eq (enum-key 'color c) :green))))


;; 13. New primitive types

(defun test-new-primitive-types ()
  (check (= (sizeof :bool) 1))
  (check (= (sizeof :intptr-t) (sizeof (:void *))))
  (check (= (sizeof :uintptr-t) (sizeof (:void *))))
  (check (member (sizeof :wchar-t) '(2 4)))
  (stack-allocate ((b :bool 1)
                   (i :intptr-t -5)
                   (u :uintptr-t (pointer-address (addr ten))))
    (check (= b 1))
    (check (= i -5))
    (check (= u (pointer-address (addr ten))))))


;; 14. Offsets and alignment

(define-struct record-t
  (c :char)
  (d :double)
  (i :int))

(define-union number-u
  (c :char)
  (d :double))

(defun test-offsets-and-alignment ()
  (check (= (alignof :char) 1))
  (check (= (alignof :int) 4))
  (check (= (alignof :double) 8))
  (check (= (alignof (:struct record-t)) 8))
  (check (= (offsetof (:struct record-t) c) 0))
  (check (= (offsetof (:struct record-t) d) 8))
  (check (= (offsetof (:struct record-t) i) 16))
  (check (= (sizeof (:struct record-t)) 24))
  (check (= (offsetof (:union number-u) c) 0))
  (check (= (offsetof (:union number-u) d) 0))
  (stack-allocate ((r (:struct record-t)))
    (check (= (- (pointer-address (addr (slot r 'd)))
                 (pointer-address (addr r)))
              (offsetof (:struct record-t) d)))))


;; 15. Variadic functions

(define-function (snprintf "snprintf") :int ((buffer (:char *)) (size :size-t) (format (:char *)) &rest))

(defun test-variadic-functions ()
  (with-allocate ((buffer :char 64))
    (with-foreign-string ((format "%d %.2f %c %s"))
      (check (= (snprintf buffer 64 format :int 3 :float 2.5 :char (char-code #\z) (:char *) text)
                25))
      (check (string= (foreign-string-to-lisp buffer) "3 2.50 z this is awesome!")))
    (with-foreign-string ((format "%ld|%u|%f"))
      (check (= (call-function "snprintf" (:int (:char *) :size-t (:char *) &rest)
                               buffer 64 format :long 1234567890123 :unsigned-short 7 :double 0.5d0)
                24))
      (check (string= (foreign-string-to-lisp buffer) "1234567890123|7|0.500000")))
    (with-foreign-string ((format "no arguments"))
      (check (= (snprintf buffer 64 format) 12))
      (check (string= (foreign-string-to-lisp buffer) "no arguments")))))


;; 16. Shared objects and symbols

(defun test-shared-objects ()
  (check (foreign-symbol-p "get_five"))
  (check (foreign-symbol-p "ten"))
  (check (not (foreign-symbol-p "this_symbol_does_not_exist")))
  (load-shared-object "libm.so.6")
  (check (foreign-symbol-p "cos"))
  (check (= (call-function "cos" (:double :double) 0d0) 1d0))
  (close-shared-object "libm.so.6"))


;; 17. Documentation

(define-function (get-five-doc "get_five") :int ()
  "Returns five")

(define-callback mult6 :int ((x :int))
  "Multiplies by six"
  (* x 6))

(define-struct doc-struct-t
  "A documented struct"
  (n :int))

(define-union doc-union-u
  "A documented union"
  (n :int)
  (f :float))

(defun test-documentation ()
  (check (= (get-five-doc) 5))
  (check (equal (documentation 'get-five-doc 'function) "Returns five"))
  (check (= (mult6 2) 12))
  (check (equal (documentation 'mult6 'function) "Multiplies by six"))
  (check (equal (documentation 'doc-struct-t 'type) "A documented struct"))
  (check (equal (documentation 'doc-union-u 'type) "A documented union"))
  (check (= (sizeof (:struct doc-struct-t)) (sizeof :int)))
  (check (equal (documentation 'snprintf 'function) nil)))


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
    (test-foreign-strings)
    (test-pointers)
    (test-function-pointers)
    (test-memory)
    (test-aliases-and-enums)
    (test-new-primitive-types)
    (test-offsets-and-alignment)
    (test-variadic-functions)
    (test-shared-objects)
    (test-documentation)
    (if *failures*
        (format t "~&~a test(s) failed.~%" (length *failures*))
        (format t "~&All tests passed.~%"))
    (null *failures*)))
