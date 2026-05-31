

<a id="TITLE:TFFI-DOCS:TAG32"></a>
# Trivial FFI

Welcome to Trivial FFI \:D

* [Introduction](/README.md#TITLE:TFFI-DOCS:TAG33)
* [Getting started](/README.md#TITLE:TFFI-DOCS:TAG34)
  * [Loading a shared library](/README.md#TITLE:TFFI-DOCS:TAG35)
* [Defining structs](/README.md#TITLE:TFFI-DOCS:TAG36)
* [Accessing to global variables](/README.md#TITLE:TFFI-DOCS:TAG37)
* [Defining functions](/README.md#TITLE:TFFI-DOCS:TAG38)


<a id="TITLE:TFFI-DOCS:TAG33"></a>
## Introduction

Trivial FFI tries to export a simple and unified interface to access C variables and functions\.

<a id="TITLE:TFFI-DOCS:TAG34"></a>
## Getting started

<a id="TITLE:TFFI-DOCS:TAG35"></a>
### Loading a shared library

[tffi\:load\-shared\-object](/docs/scribble/reference.md#FUNCTION:TRIVIAL-FFI:LOAD-SHARED-OBJECT)

`````
(load-shared-object "libmyobject.so")
`````

<a id="TITLE:TFFI-DOCS:TAG36"></a>
## Defining structs

`````C
struct my_struct {
  int k;
  char p;
};
`````

`````common-lisp
(define-struct my-struct
  (k :int)
  (p :char))
`````

<a id="TITLE:TFFI-DOCS:TAG37"></a>
## Accessing to global variables

[tffi\:define\-variable](/docs/scribble/reference.md#FUNCTION:TRIVIAL-FFI:DEFINE-VARIABLE)

`````C
extern int my_int;
extern float* my_float;
extern char[5] my_chars;
extern int (*my_func_ptr)(char, double);

// Array of 5 pointers to arrays of 10 my_struct
extern my_struct (*my_doubles[5])[10];
`````

`````common-lisp
(define-variable (my-int "my_int") :int)
(define-variable (my-float "my_float") (:float *))
(define-variable (my-chars "my_chars") (:char 5))
(define-variable (my-func-ptr "my_func_ptr") ((:function :int :char :double) *))

;; Array of 5 pointers to arrays of 10 my_struct
(define-variable (my-doubles "my_doubles") ((:struct my_struct) 10 * 5))
`````

<a id="TITLE:TFFI-DOCS:TAG38"></a>
## Defining functions

`````C
int mult2(int a){
  return a * 2;
}

int mult3(int a){
  return a * 3;
}

int op(int (*ptr)(int), int a){
  return ptr(a);
}
`````

`````common-lisp
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
`````