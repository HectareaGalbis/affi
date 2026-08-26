
(in-package :affi-docs)

@output-file["/README.md"]

@title[:toc nil]{Another Foreign Function Interface}

Welcome to AFFI :D

@table-of-contents[]

@subtitle{Introduction}

AFFI exports a simple interface to access C variables and functions.

Supported implementations: @bold{SBCL}

@subtitle{Documentation}

@itemize[
@item[@tref[quick-start]{Quick start}]
@item{@tref[tutorial]{Tutorial}}
@item{@tref[reference]{Reference}}
]

@subtitle[:tag quick-start]{Quick start}

@subsubtitle{Loading a shared library}

@example{
(load-shared-object "libtest-ffi.so")
}

@subsubtitle{Variables}

@code-block[:lang "C"]{
float pi = 3.14159274101257324219f;
}

@example{
(define-variable (pi-num "pi") :float)
(print pi-num)
}

@subsubtitle{Functions}

@code-block[:lang "C"]{
int get_five(void)
{
  return 5;
}
}

@example{
(define-function (get-five "get_five") :int ())
(get-five)
}

@subsubtitle{Arrays}

@code-block[:lang "C"]{
int fibo[10] = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34};
}

@example[:results :output]{
(define-variable (fibo "fibo") (:int 10))
(loop for i from 0 below 10
      do (print (deref fibo i)))
}

@subsubtitle{Strings}

AFFI does not define any special type for strings.

@code-block[:lang "C"]{
void text_uppercase(char* dst)
{
  size_t i = 0;
  for (; text[i] != '\0'; i++)
    dst[i] = toupper(text[i]);
  dst[i] = '\0';
}
}

@example[:results :output]{
(define-function (text-uppercase "text_uppercase") :void ((dst (:char *))))
(stack-allocate ((text (:char 6)))
  (setf (deref text 0) (char-code #\H)
        (deref text 1) (char-code #\e)
        (deref text 2) (char-code #\l)
        (deref text 3) (char-code #\l)
        (deref text 4) (char-code #\o)
        (deref text 5) 0)
  (text-uppercase (addr (deref text 0)))
  (loop for i from 0 below 6
        do (princ (code-char (deref text i)))))
}

@subsubtitle{Structures}

@code-block[:lang "C"]{
typedef struct {
  size_t n;
  int* ns;
} ffi_test_t;

ffi_test_t get_value(size_t n)
{
  return (ffi_test_t){ n, NULL };
}
}

@example[:results :output]{
(define-struct ffi-test-t
  (n :size-t)
  (ns (:int *)))

(define-function (get-value "get_value") (:struct ffi-test-t) ((size :size-t)))

(stack-allocate ((test (:struct ffi-test-t) (get-value 10)))
  (print (slot test 'n))
  (setf (slot test 'n) 5)
  (print (slot test 'n)))
}

@subsubtitle{Callbacks}

@code-block[:lang "C"]{
int op(int (*op_ptr)(int x), int x)
{
  return op_ptr(x);
}
}

@example{
(define-function (op "op") :int ((op-ptr ((:function :int :int) *)) (x :int)))

(define-callback mult3 :int ((x :int))
  (* x 3))

(op (addr mult3) 7)
}

@subtitle[:tag reference]{Reference}

@function-glossary[#:affi]
