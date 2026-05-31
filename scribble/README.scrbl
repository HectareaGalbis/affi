
(in-package :tffi-docs)

@output-file["/README.md"]

@title[:toc nil]{Trivial FFI}

Welcome to Trivial FFI :D

@table-of-contents[]

@subtitle{Introduction}

Trivial FFI tries to export a simple and unified interface to access C variables and functions.

@subtitle{Getting started}

@subsubtitle{Loading a shared library}

@fref[load-shared-object]

@code-block{
(load-shared-object "libmyobject.so")
}

@subtitle{Defining structs}

@code-block[:lang "C"]{
struct my_struct {
  int k;
  char p;
};
}

@code-block[:lang "common-lisp"]{
(define-struct my-struct
  (k :int)
  (p :char))
}

@subtitle{Accessing to global variables}

@fref[define-variable]

@code-block[:lang "C"]{
extern int my_int;
extern float* my_float;
extern char[5] my_chars;
extern int (*my_func_ptr)(char, double);

// Array of 5 pointers to arrays of 10 my_struct
extern my_struct (*my_doubles[5])[10];
}

@code-block[:lang "common-lisp"]{
(define-variable (my-int "my_int") :int)
(define-variable (my-float "my_float") (:float *))
(define-variable (my-chars "my_chars") (:char 5))
(define-variable (my-func-ptr "my_func_ptr") ((:function :int :char :double) *))

;; Array of 5 pointers to arrays of 10 my_struct
(define-variable (my-doubles "my_doubles") ((:struct my_struct) 10 * 5))
}

@subtitle{Defining functions}

@code-block[:lang "C"]{
int mult2(int a){
  return a * 2;
}

int mult3(int a){
  return a * 3;
}

int op(int (*ptr)(int), int a){
  return ptr(a);
}
}

@code-block[:lang "common-lisp"]{
(define-function (mult2 "mult2") :int (:int))
(define-function (mult3 "mult3") :int (:int))
(define-function (op "op") :int (((:function :int :int) *) :int))

(define-callback mult4 (a)
  (* a 4))

(mult2 5) ;; --> 10
(mult3 7) ;; --> 21
(mult4 8) ;; --> 32

(op (addr mult2) 8) --> 16
(op (addr mult3) 4) --> 12
(op (addr mult4) 5) --> 20
}
