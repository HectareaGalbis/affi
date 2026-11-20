
#ifndef TEST_FFI_H
#define TEST_FFI_H

#include <stdlib.h>

// Export/import
#if defined(_WIN32) || defined(__CYGWIN__)
    #ifdef TEST_FFI_EXPORTS
        #define TEST_FFI_API __declspec(dllexport)
    #else
        #define TEST_FFI_API __declspec(dllimport)
    #endif
#else
    #define TEST_FFI_API
#endif

// API

// 1. Global variables
//
// Description: Print the value of the following variables.
// Result: You must print: a, 10, 3.14159274101257324219, 2.71828182845904523536028747135266250
extern TEST_FFI_API char a;
extern TEST_FFI_API int ten;
extern TEST_FFI_API float pi;
extern TEST_FFI_API double e;

// 2. Simple functions
//
// Description: Call the functions.
// Result: You must print: 5, the sum of arguments casted to double
TEST_FFI_API int get_five(void);
TEST_FFI_API double sum(int arg1, float arg2, double arg3);

// 3. Global variables address
//
// Description: Call the function
// Result: You must print 1
TEST_FFI_API int check_vars(char* a_ptr, int* ten_ptr, float* pi_ptr, double* e_ptr);

// 4. Arrays
//
// Description: Call the function being the first argument the array fibo
//              and the second argument being another array 
// Result: The sum of the first two arguments are stored int the third argument
extern TEST_FFI_API int fibo[10];
TEST_FFI_API void add_array(int arr1[10], int arr2[10], int arr3[10]);
TEST_FFI_API int check_fibo_7(int* fibo7);

// 5. Strings
//
// Description: Call the function using the declared string and a heap allocated string
//              with enough space (counting with the null character). Calculate the space
//              from the length of the declared string.
// Result: The declared string but in uppercase: THIS IS AWESOME!
extern TEST_FFI_API char* text;
TEST_FFI_API void text_uppercase(char* dst);

// 6. Structs
//
// Description: Set the member n and call the three functions in order.
//              First, an increasing array of integers is created
//              Second, the sum of the numbers is stored
//              And lastly the array of numbers is freed 
// Result: The sum of the first natural numbers up to n
typedef struct {
  size_t n;
  int* ns;
} ffi_test_t;

TEST_FFI_API ffi_test_t get_value(size_t n);
TEST_FFI_API void fill_values(ffi_test_t* test);
TEST_FFI_API void sum_values(ffi_test_t* test, int* value);
TEST_FFI_API void free_values(ffi_test_t test); // struct by value

// 7. Callbacks
TEST_FFI_API int mult2(int x);
TEST_FFI_API int check_mult2(int (*mult2_ptr)(int x));
extern TEST_FFI_API int (*func_ptr)(int x);
TEST_FFI_API int op(int (*op_ptr)(int x), int x);

#endif // TEST_FFI_H
