/* __APT_COV__ prologue begin */
#include <stdio.h>
#include <stdlib.h>
struct __apt_file { const char *path; unsigned long *hits; int nlines; const unsigned char *mask; };
void __apt_register(struct __apt_file*);
static unsigned long __apt_hits_main_c_01157e4a[13] = {0};
static const unsigned char __apt_mask_main_c_01157e4a[13] = { 0,0,0,0,0,1,1,0,1,1,0,1,0 };
static struct __apt_file __apt_me_main_c_01157e4a = { "/home/rdk/Projects/ni-apt/apt-2025-cichra/code-coverage/tests/test_source_files/test3/in/main.c", __apt_hits_main_c_01157e4a, 12, __apt_mask_main_c_01157e4a };
void __apt_register_main_c_01157e4a(void) { __apt_register(&__apt_me_main_c_01157e4a); }
/* __APT_COV__ prologue end */
/* __APT_COV__ fwd decls */
extern void __apt_register_main_c_01157e4a(void);
extern void __apt_register_math_operations_c_44375f23(void);
/* __APT_COV__ runtime begin */
#ifndef __APT_RUNTIME_ONCE
#define __APT_RUNTIME_ONCE
#include <stdio.h>
#include <stdlib.h>
static struct __apt_file* __apt_files[512];
static int __apt_nfiles = 0;
void __apt_register(struct __apt_file* f) {
  if (__apt_nfiles < (int)(sizeof(__apt_files)/sizeof(__apt_files[0]))) __apt_files[__apt_nfiles++] = f;
}
static void __apt_write_lcov(void) {
  FILE *fp = fopen("coverage.lcov", "w");
  if (!fp) return;
  fprintf(fp, "TN:test\n");
  for (int i = 0; i < __apt_nfiles; i++) {
    struct __apt_file *f = __apt_files[i];
    fprintf(fp, "SF:%s\n", f->path);
    int LF = 0, LH = 0;
    for (int line = 1; line <= f->nlines; line++) {
      if (!f->mask[line]) continue;
      LF++;
      unsigned long c = f->hits[line];
      if (c) { fprintf(fp, "DA:%d,%lu\n", line, c); LH++; }
    }
    fprintf(fp, "LH:%d\nLF:%d\nend_of_record\n", LH, LF);
  }
  fclose(fp);
}
#endif
/* __APT_COV__ runtime end */
#include <stdio.h>
#include "math_operations.h"

int main() {
    __apt_hits_main_c_01157e4a[5]++; /*__APT_COV__*/ int result = add(5, 3);/* __APT_COV__ init */ atexit(__apt_write_lcov);
__apt_register_main_c_01157e4a();
__apt_register_math_operations_c_44375f23();

    __apt_hits_main_c_01157e4a[6]++; /*__APT_COV__*/ printf("Result of addition: %d\n", result);
    
    __apt_hits_main_c_01157e4a[8]++; /*__APT_COV__*/ int difference = subtract(10, 4);
    __apt_hits_main_c_01157e4a[9]++; /*__APT_COV__*/ printf("Result of subtraction: %d\n", difference);
    
    __apt_hits_main_c_01157e4a[11]++; /*__APT_COV__*/ return 0;
}
