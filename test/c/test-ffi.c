
#include "test-ffi.h"
#include <stdio.h>
#include <ctype.h>

// 1. Global variable
char a = 'a';
int ten = 10;
float pi = 3.14159274101257324219f;
double e = 2.71828182845904523536028747135266250;

// 2. Simple function
int get_five(void)
{
  return 5;
}

double sum(int arg1, float arg2, double arg3)
{
  return (double)arg1 + (double)arg2 + (double)arg3;
}

// 3. Global variable address
int check_vars(char* a_ptr, int* ten_ptr, float* pi_ptr, double* e_ptr)
{
  return a_ptr == &a && ten_ptr == &ten && pi_ptr == &pi && e_ptr == &e;
}

// 4. Arrays
int fibo[10] = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34};

void add_array(int arr1[10], int arr2[10], int arr3[10])
{
  for (size_t i = 0; i < 10; i++) {
    arr3[i] = arr1[i] + arr2[i];
  }
}

int check_fibo_7(int* fibo7)
{
  return fibo7 == fibo+7;
}

// 5. Strings
char* text = "this is awesome!";

void text_uppercase(char* dst)
{
  size_t i = 0;
  for (; dst[i] != '\0'; i++)
    dst[i] = toupper(dst[i]);
  dst[i] = '\0';
}

// 6. Structs
ffi_test_t get_value(size_t n)
{
  return (ffi_test_t){ n, NULL };
}

void fill_values(ffi_test_t* test)
{
  test->ns = malloc(sizeof(int) * test->n);
  for (size_t i = 0; i < test->n; i++)
    test->ns[i] = i+1;
}

void sum_values(ffi_test_t* test, int* value)
{
  *value = 0;
  for (size_t i = 0; i < test->n; i++)
    *value += test->ns[i];
}

void free_values(ffi_test_t test)
{
  free(test.ns);
}

// 7. Callbacks
int mult2(int x)
{
  return x*2;
}

int check_mult2(int (*mult2_ptr)(int x))
{
  return mult2_ptr == &mult2;
}

int (*func_ptr)(int x) = mult2;

int op(int (*op_ptr)(int x), int x)
{
  return op_ptr(x);
}
