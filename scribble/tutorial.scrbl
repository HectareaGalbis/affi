(in-package #:affi-docs)

@title[:tag tutorial :toc nil]{Tutorial}

@table-of-contents[]


@subtitle{Introduction}

AFFI is a simple foreign interface. It gives you the minimal functionality to access C symbols. This means no complex conversions are made. AFFI uses the implementation FFI directly through a simplified interface.


@subtitle{Data types}

Data types in AFFI has the following syntax:

@code-block{
type | (type specifier*)
}

where @code{specifier} can be a positive integer or the symbol *.

Specifiers serves to indicate pointers and arrays to the given type. For example, given an AFFI type @code{T}, a pointer to @code{T} is specified as @code{(T *)}. And an array of 5 elements of T is written as @code{(T 5)}. More on specifiers later.


@subsubtitle{Primitive types}

Primitive types are denoted with keywords. These types have a direct conversion to a Lisp number.

@table[
@row[ @cell{@bold{AFFI}}   @cell{@bold{C}}   @cell{Lisp} ]

@row[ @cell{@code{:void}}         @cell{@code{void}}       @cell{; No value}]

@row[ @cell{@code{:char}
@code{:signed-char} @code{:unsigned-char}
@code{:short} @code{:short-int}
@code{:signed-short} @code{:signed-short-int}
@code{:unsigned-short} @code{:unsigned-short-int}
@code{:int}
@code{:signed} @code{:signed-int}
@code{:unsigned} @code{:unsigned-int}
@code{:long} @code{:long-int}
@code{:signed-long} @code{:signed-long-int}
@code{:unsigned-long} @code{:unsigned-long-int}
@code{:long-long} @code{:long-long-int}
@code{:signed-long-long} @code{:signed-long-long-int}
@code{:unsigned-long-long} @code{:unsigned-long-long-int}}
      @cell{@code{char}
@code{signed char} @code{unsigned char}
@code{short} @code{short int}
@code{signed short} @code{signed short int}
@code{unsigned short} @code{unsigned short int}
@code{int}
@code{signed} @code{signed int}
@code{unsigned} @code{unsigned int}
@code{long} @code{long int}
@code{signed long} @code{signed long int}
@code{unsigned long} @code{unsigned long int}
@code{long long} @code{long long int}
@code{signed long long} @code{signed long long int}
@code{unsigned long long} @code{unsigned long long int}}
      @cell{@code{INTEGER}}]

@row[ @cell{@code{:float}
@code{:double}}
      @cell{@code{float}
@code{double}}
      @cell{@code{REAL}}]

@row[ @cell{@code{:size-t} @code{:ssize-t}
@code{:ptrdiff-t}
@code{:int8-t} @code{:uint8-t}
@code{:int16-t} @code{:uint16-t}
@code{:int32-t} @code{:uint32-t}
@code{:int64-t} @code{:uint64-t}}
      @cell{@code{size_t} @code{ssize_t}
@code{ptrdiff_t}
@code{int8_t} @code{uint8_t}
@code{int16_t} @code{uint16_t}
@code{int32_t} @code{uint32_t}
@code{int64_t} @code{uint64_t}}
      @cell{@code{INTEGER}}]
]


@subsubtitle{Record types}

Record types are structs and unions. These record types have a name, so in order to denote a struct we use its name.

@table[
@row[@cell{@bold{AFFI}}    @cell{@bold{C}}   @cell{@bold{Lisp}}]

@row[@cell{@code{(:struct <NAME>)}}  @cell{@code{struct <name>}}  @cell{; Object}  ]
@row[@cell{@code{(:union <NAME>)}}  @cell{@code{struct <name>}}  @cell{; Object}  ]
]

More on structs and union later.


@subsubtitle{Function types}

Functions have a result type and types for each argument. C functions does not have an equivalent Lisp object since C functions are not first class citizens. We cannot declare a variable of type function. Instead, we define Lisp functions that call a C function.

@table[
@row[@cell{@bold{AFFI}}   @cell{@bold{C}}]

@row[@cell{@code{(:function :void)}}  @cell{@code{void()}}]
@row[@cell{@code{(:function :int :int)}}  @cell{@code{int(int)}}]
@row[@cell{@code{(:function (:char *) (:float 5))}}  @cell{@code{char*(float[5])}}]
@row[@cell{@code{(:function :int ((:function :char :float) *) :int)}}  @cell{@code{int(char(*)(float),int)}}]
]


@subsubtitle{Specifiers}

We have seen already some specifiers. These are used to denote pointers and arrays. We can use an arbitrary number of specifiers on any type and in any order. For example:

@code-block[:lang "common-lisp"]{
(:int * 5 6 * *)
}

This is a pointer to a pointer of an array of 6 elements of arrays of 5 elements of pointers to integers.

Similarly to C, specifiers should be read backwards.

@table[
@row[@cell{@bold{AFFI}}  @cell{@bold{C}}  @cell{@bold{Lisp}}]

@row[
     @cell{@code{(:int *)}
@code{(:int 5 *)}
@code{(:int * 5 *)}}
     @cell{@code{int*}
@code{int(*)[5]}
@code{int *(*)[5]}}
     @cell{; Pointer object}]

@row[
    @cell{@code{(:int * 5)}
@code{(:int 5 * 5)}}
    @cell{@code{int*[5]}
@code{int (*[5])[5]}}
    @cell{; Array object}
]
]

If the last specifier is the symbol @code{*}, then the type is a pointer. Otherwise, if the last specifier is a positive integer, the type is an array.


