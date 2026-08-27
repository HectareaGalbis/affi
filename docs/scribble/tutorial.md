<a id="TITLE:AFFI-DOCS:TUTORIAL"></a>
# Tutorial

* [Introduction](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TAG27)
* [Data types](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TAG28)
  * [Primitive types](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TAG29)
  * [Record types](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TAG30)
  * [Function types](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TAG31)
  * [Specifiers](/docs/scribble/tutorial.md#TITLE:AFFI-DOCS:TAG32)



<a id="TITLE:AFFI-DOCS:TAG27"></a>
## Introduction

AFFI is a simple foreign interface\. It gives you the minimal functionality to access C symbols\. This means no complex conversions are made\. AFFI uses the implementation FFI directly through a simplified interface\.


<a id="TITLE:AFFI-DOCS:TAG28"></a>
## Data types

Data types in AFFI has the following syntax\:

`````
type | (type specifier*)
`````

where ```specifier``` can be a positive integer or the symbol \*\.

Specifiers serves to indicate pointers and arrays to the given type\. For example\, given an AFFI type ```T```\, a pointer to ```T``` is specified as ```(T *)```\. And an array of 5 elements of T is written as ```(T 5)```\. More on specifiers later\.


<a id="TITLE:AFFI-DOCS:TAG29"></a>
### Primitive types

Primitive types are denoted with keywords\. These types have a direct conversion to a Lisp number\.

<table>
<tr>
<td>**AFFI**</td><td>**C**</td><td>Lisp</td></tr><tr>
<td>```:void```</td><td>```void```</td><td>; No value</td></tr><tr>
<td>```:char```<br>```:signed-char``` ```:unsigned-char```<br>```:short``` ```:short-int```<br>```:signed-short``` ```:signed-short-int```<br>```:unsigned-short``` ```:unsigned-short-int```<br>```:int```<br>```:signed``` ```:signed-int```<br>```:unsigned``` ```:unsigned-int```<br>```:long``` ```:long-int```<br>```:signed-long``` ```:signed-long-int```<br>```:unsigned-long``` ```:unsigned-long-int```<br>```:long-long``` ```:long-long-int```<br>```:signed-long-long``` ```:signed-long-long-int```<br>```:unsigned-long-long``` ```:unsigned-long-long-int```</td><td>```char```<br>```signed char``` ```unsigned char```<br>```short``` ```short int```<br>```signed short``` ```signed short int```<br>```unsigned short``` ```unsigned short int```<br>```int```<br>```signed``` ```signed int```<br>```unsigned``` ```unsigned int```<br>```long``` ```long int```<br>```signed long``` ```signed long int```<br>```unsigned long``` ```unsigned long int```<br>```long long``` ```long long int```<br>```signed long long``` ```signed long long int```<br>```unsigned long long``` ```unsigned long long int```</td><td>```INTEGER```</td></tr><tr>
<td>```:float```<br>```:double```</td><td>```float```<br>```double```</td><td>```REAL```</td></tr><tr>
<td>```:size-t``` ```:ssize-t```<br>```:ptrdiff-t```<br>```:int8-t``` ```:uint8-t```<br>```:int16-t``` ```:uint16-t```<br>```:int32-t``` ```:uint32-t```<br>```:int64-t``` ```:uint64-t```</td><td>```size_t``` ```ssize_t```<br>```ptrdiff_t```<br>```int8_t``` ```uint8_t```<br>```int16_t``` ```uint16_t```<br>```int32_t``` ```uint32_t```<br>```int64_t``` ```uint64_t```</td><td>```INTEGER```</td></tr></table>


<a id="TITLE:AFFI-DOCS:TAG30"></a>
### Record types

Record types are structs and unions\. These record types have a name\, so in order to denote a struct we use its name\.

<table>
<tr>
<td>**AFFI**</td><td>**C**</td><td>**Lisp**</td></tr><tr>
<td>```(:struct <NAME>)```</td><td>```struct <name>```</td><td>; Object</td></tr><tr>
<td>```(:union <NAME>)```</td><td>```struct <name>```</td><td>; Object</td></tr></table>

More on structs and union later\.


<a id="TITLE:AFFI-DOCS:TAG31"></a>
### Function types

Functions have a result type and types for each argument\. C functions does not have an equivalent Lisp object since C functions are not first class citizens\. We cannot declare a variable of type function\. Instead\, we define Lisp functions that call a C function\.

<table>
<tr>
<td>**AFFI**</td><td>**C**</td></tr><tr>
<td>```(:function :void)```</td><td>```void()```</td></tr><tr>
<td>```(:function :int :int)```</td><td>```int(int)```</td></tr><tr>
<td>```(:function (:char *) (:float 5))```</td><td>```char*(float[5])```</td></tr><tr>
<td>```(:function :int ((:function :char :float) *) :int)```</td><td>```int(char(*)(float),int)```</td></tr></table>


<a id="TITLE:AFFI-DOCS:TAG32"></a>
### Specifiers

We have seen already some specifiers\. These are used to denote pointers and arrays\. We can use an arbitrary number of specifiers on any type and in any order\. For example\:

`````common-lisp
(:int * 5 6 * *)
`````

This is a pointer to a pointer of an array of 6 elements of arrays of 5 elements of pointers to integers\.

Similarly to C\, specifiers should be read backwards\.

<table>
<tr>
<td>**AFFI**</td><td>**C**</td><td>**Lisp**</td></tr><tr>
<td>```(:int *)```<br>```(:int 5 *)```<br>```(:int * 5 *)```</td><td>```int*```<br>```int(*)[5]```<br>```int *(*)[5]```</td><td>; Pointer object</td></tr><tr>
<td>```(:int * 5)```<br>```(:int 5 * 5)```</td><td>```int*[5]```<br>```int (*[5])[5]```</td><td>; Array object</td></tr></table>

If the last specifier is the symbol ```*```\, then the type is a pointer\. Otherwise\, if the last specifier is a positive integer\, the type is an array\.

