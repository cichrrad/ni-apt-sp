/* __APT_COV__ prologue begin */
#include <stdio.h>
#include <stdlib.h>
struct __apt_file { const char *path; unsigned long *hits; int nlines; const unsigned char *mask; };
void __apt_register(struct __apt_file*);
static unsigned long __apt_hits_math_operations_c_44375f23[6] = {0};
static const unsigned char __apt_mask_math_operations_c_44375f23[6] = { 0,0,0,1,0,1 };
static struct __apt_file __apt_me_math_operations_c_44375f23 = { "/home/rdk/Projects/ni-apt/apt-2025-cichra/code-coverage/tests/test_source_files/test3/in/math_operations.c", __apt_hits_math_operations_c_44375f23, 5, __apt_mask_math_operations_c_44375f23 };
void __apt_register_math_operations_c_44375f23(void) { __apt_register(&__apt_me_math_operations_c_44375f23); }
/* __APT_COV__ prologue end */
#include "math_operations.h"

int add(int a, int b) { __apt_hits_math_operations_c_44375f23[3]++; /*__APT_COV__*/ return a + b; }

int subtract(int a, int b) { __apt_hits_math_operations_c_44375f23[5]++; /*__APT_COV__*/ return a - b; }
