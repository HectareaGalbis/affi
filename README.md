

<a id="TITLE:AFFI-DOCS:TAG1"></a>
# Another Foreign Function Interface

Welcome to AFFI \:D

* [Introduction](/README.md#TITLE:AFFI-DOCS:TAG2)
* [Documentation](/README.md#TITLE:AFFI-DOCS:TAG3)
* [Quick start](/README.md#TITLE:AFFI-DOCS:QUICK-START)
  * [Loading a shared library](/README.md#TITLE:AFFI-DOCS:TAG4)
  * [Variables](/README.md#TITLE:AFFI-DOCS:TAG5)
  * [Functions](/README.md#TITLE:AFFI-DOCS:TAG6)
  * [Arrays](/README.md#TITLE:AFFI-DOCS:TAG7)
  * [Strings](/README.md#TITLE:AFFI-DOCS:TAG8)
  * [Structures](/README.md#TITLE:AFFI-DOCS:TAG9)
  * [Callbacks](/README.md#TITLE:AFFI-DOCS:TAG10)
* [Reference](/README.md#TITLE:AFFI-DOCS:REFERENCE)


<a id="TITLE:AFFI-DOCS:TAG2"></a>
## Introduction

AFFI exports a simple interface to access C variables and functions\.

Supported implementations\: **SBCL**

<a id="TITLE:AFFI-DOCS:TAG3"></a>
## Documentation

* [Quick start](/README.md#TITLE:AFFI-DOCS:QUICK-START)
* [Tutorial](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TUTORIAL)
* [Reference](/README.md#TITLE:AFFI-DOCS:REFERENCE)


<a id="TITLE:AFFI-DOCS:QUICK-START"></a>
## Quick start

<a id="TITLE:AFFI-DOCS:TAG4"></a>
### Loading a shared library

`````common-lisp
(load-shared-object "libtest-ffi.so")
`````
`````common-lisp
;; Returns
#P"libtest-ffi.so"
`````

<a id="TITLE:AFFI-DOCS:TAG5"></a>
### Variables

`````C
float pi = 3.14159274101257324219f;
`````

`````common-lisp
(define-variable (pi-num "pi") :float)
pi-num
`````
`````common-lisp
;; Returns
3.1415927
`````

<a id="TITLE:AFFI-DOCS:TAG6"></a>
### Functions

`````C
int get_five(void)
{
  return 5;
}
`````

`````common-lisp
(define-function (get-five "get_five") :int ())
(get-five)
`````
`````common-lisp
;; Returns
5
`````

<a id="TITLE:AFFI-DOCS:TAG7"></a>
### Arrays

`````C
int fibo[10] = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34};
`````

`````common-lisp
(define-variable (fibo "fibo") (:int 10))
(loop for i from 0 below 10
      do (print (deref fibo i)))
`````
`````text
;; Output

0 
1 
1 
2 
3 
5 
8 
13 
21 
34 
`````


<a id="TITLE:AFFI-DOCS:TAG8"></a>
### Strings

AFFI does not define any special type for strings\.

`````C
void text_uppercase(char* dst)
{
  size_t i = 0;
  for (; text[i] != '\0'; i++)
    dst[i] = toupper(text[i]);
  dst[i] = '\0';
}
`````

`````common-lisp
(define-function (text-uppercase "text_uppercase") :void ((dst (:char *))))
(stack-allocate ((text (:char 6)))
  (setf (deref text 0) (char-code #\H)
        (deref text 1) (char-code #\e)
        (deref text 2) (char-code #\l)
        (deref text 3) (char-code #\l)
        (deref text 4) (char-code #\o)
        (deref text 5) 0)
  (text-uppercase (addr (deref text 0)))
  (loop for i from 0 below 5
        do (princ (code-char (deref text i)))))
`````
`````text
;; Output
HELLO
`````


<a id="TITLE:AFFI-DOCS:TAG9"></a>
### Structures

`````C
typedef struct {
  size_t n;
  int* ns;
} ffi_test_t;

ffi_test_t get_value(size_t n)
{
  return (ffi_test_t){ n, NULL };
}
`````

`````common-lisp
(define-struct ffi-test-t
  (n :size-t)
  (ns (:int *)))

(define-function (get-value "get_value") (:struct ffi-test-t) ((size :size-t)))

(stack-allocate ((test (:struct ffi-test-t) (get-value 10)))
  (print (slot test 'n))
  (setf (slot test 'n) 5)
  (print (slot test 'n)))
`````
`````text
;; Output

10 
5 
`````


<a id="TITLE:AFFI-DOCS:TAG10"></a>
### Callbacks

`````C
int op(int (*op_ptr)(int x), int x)
{
  return op_ptr(x);
}
`````

`````common-lisp
(define-function (op "op") :int ((op-ptr ((:function :int :int) *)) (x :int)))

(define-callback mult3 :int ((x :int))
  (* x 3))

(op (addr mult3) 7)
`````
`````common-lisp
;; Returns
21
`````

<a id="TITLE:AFFI-DOCS:REFERENCE"></a>
## Reference

<a id="FUNCTION:AFFI:ADDR"></a>
<a id="FUNCTION:AFFI-DOCS:TAG20"></a>
#### Macro: affi\:addr \(expr\)

`````text

This macro must be used in the following scenarios to retrieve the addres of a foreign value.
  * A foreign variable: A variable defined with DEFINE-VARIABLE, DEFINE-FUNCTION or DEFINE-CALLBACK.
  * An accessor: A DEREF or SLOT expression.

`````

<a id="FUNCTION:AFFI:ALLOCATE"></a>
<a id="FUNCTION:AFFI-DOCS:TAG19"></a>
#### Macro: affi\:allocate \(type \&optional \(size 1\)\)

`````text

Allocates memory on the heap.
The bytes allocated are calculated from TYPE and the SIZE elements wanted.
Returns a pointer to TYPE.

`````

<a id="FUNCTION:AFFI:CALL-FUNCTION"></a>
<a id="FUNCTION:AFFI-DOCS:TAG25"></a>
#### Macro: affi\:call\-function \(name \(res\-type \&rest arg\-types\) \&rest args\)

`````text

Calls a function named NAME.
Returns a foreign value of type RES-TYPE.
ARG-TYPES denotes the function's argument types.
ARGS are the objects passed to the function.

`````

<a id="FUNCTION:AFFI:CAST"></a>
<a id="FUNCTION:AFFI-DOCS:TAG12"></a>
#### Macro: affi\:cast \(value type\)

`````text

Converts the type of VALUE into another.
VALUE must be of type array or pointer.
TYPE must be an array or pointer type.

`````

<a id="FUNCTION:AFFI:DEFINE-CALLBACK"></a>
<a id="FUNCTION:AFFI-DOCS:TAG17"></a>
#### Macro: affi\:define\-callback \(name res\-type \(\&rest args\) \&body body\)

`````text

Defines a function that can be called from C.

`````

<a id="FUNCTION:AFFI:DEFINE-FUNCTION"></a>
<a id="FUNCTION:AFFI-DOCS:TAG16"></a>
#### Macro: affi\:define\-function \(\(name foreign\-name\) res\-type \(\&rest args\)\)

`````text

Defines a foreign function called NAME.
FOREIGN-NAME is a string denoting the symbol from the shared library.
NAME is a symbol denoting the name of the new defined function.
The function will return a value of type RES-TYPE.
ARG-TYPES denotes the types of the function's arguments.

`````

<a id="FUNCTION:AFFI:DEFINE-STRUCT"></a>
<a id="FUNCTION:AFFI-DOCS:TAG15"></a>
#### Macro: affi\:define\-struct \(name \&body slots\)

`````text

Defines a foreign structure.
Each slot must be a list with a symbol denoting the member name
and the type of that member.

`````

<a id="FUNCTION:AFFI:DEFINE-UNION"></a>
<a id="FUNCTION:AFFI-DOCS:TAG23"></a>
#### Macro: affi\:define\-union \(name \&body slots\)

`````text

Same as DEFINE-STRUCT, but defines an union instead of a structure.

`````

<a id="FUNCTION:AFFI:DEFINE-VARIABLE"></a>
<a id="FUNCTION:AFFI-DOCS:TAG24"></a>
#### Macro: affi\:define\-variable \(\(name foreign\-name\) type\)

`````text

Defines a foreign variable.
FOREIGN-NAME is a string denoting the symbol we want to retrieve from the shared library.
NAME is a symbol denoting the lisp name to be used to retrieve the foreign value.
TYPE is the type of the foreign value.

`````

<a id="FUNCTION:AFFI:DEREF"></a>
<a id="FUNCTION:AFFI-DOCS:TAG11"></a>
#### Function: affi\:deref \(obj \&rest indices\)

`````text

Returns the value pointed by OBJ.
OBJ must be a pointer or an array.
INDICES can be used to deref an element of a given index
from the pointer or the array.

`````

<a id="FUNCTION:AFFI:FREE"></a>
<a id="FUNCTION:AFFI-DOCS:TAG14"></a>
#### Function: affi\:free \(ptr\)

`````text

Deallocates the memory pointed by PTR.

`````

<a id="FUNCTION:AFFI:LOAD-SHARED-OBJECT"></a>
<a id="FUNCTION:AFFI-DOCS:TAG13"></a>
#### Function: affi\:load\-shared\-object \(pathname \&key dont\-save\)

`````text

Loads a shared library.

`````

<a id="FUNCTION:AFFI:NULL-POINTER"></a>
<a id="FUNCTION:AFFI-DOCS:TAG18"></a>
#### Function: affi\:null\-pointer \(value\)

`````text

Checks whether VALUE is the null pointer.

`````

<a id="FUNCTION:AFFI:SIZEOF"></a>
<a id="FUNCTION:AFFI-DOCS:TAG21"></a>
#### Macro: affi\:sizeof \(type\)

`````text

Returns the size of TYPE in BYTES.

`````

<a id="FUNCTION:AFFI:SLOT"></a>
<a id="FUNCTION:AFFI-DOCS:TAG26"></a>
#### Function: affi\:slot \(obj slot\-name\)

`````text

Returns the slot SLOT-NAME of a record OBJ.

`````

<a id="FUNCTION:AFFI:STACK-ALLOCATE"></a>
<a id="FUNCTION:AFFI-DOCS:TAG22"></a>
#### Macro: affi\:stack\-allocate \(\(\&rest definitions\) \&body body\)

`````text

Allocates memory on the stack.
This memory has dynamic extent during the body of the macro.
Each definition must be a list of a variable holding the allocated value
and the type of the value.

`````