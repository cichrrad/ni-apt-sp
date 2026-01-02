/* __APT_COV__ prologue begin */
#include <stdio.h>
#include <stdlib.h>
struct __apt_file { const char *path; unsigned long *hits; int nlines; const unsigned char *mask; };
void __apt_register(struct __apt_file*);
static unsigned long __apt_hits_test1_c_3bcb8323[21] = {0};
static const unsigned char __apt_mask_test1_c_3bcb8323[21] = { 0,0,0,0,0,1,0,0,1,1,0,1,0,1,0,0,0,0,1,1,0 };
static struct __apt_file __apt_me_test1_c_3bcb8323 = { "/home/rdk/Projects/ni-apt-sp/apt-2025-cichra/code-coverage/tests/test_source_files/test1/in/test1.c", __apt_hits_test1_c_3bcb8323, 20, __apt_mask_test1_c_3bcb8323 };
void __apt_register_test1_c_3bcb8323(void) { __apt_register(&__apt_me_test1_c_3bcb8323); }
/* __APT_COV__ prologue end */
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

int my_global = 45;

int test() { __apt_hits_test1_c_3bcb8323[5]++; /*__APT_COV__*/ return 0; }
int doubler(int x)
{
    __apt_hits_test1_c_3bcb8323[8]++; /*__APT_COV__*/ int y = x + 1;
    for (int i = 0; (__apt_hits_test1_c_3bcb8323[9]++, (i < 10)); i++)
    {
        __apt_hits_test1_c_3bcb8323[11]++; /*__APT_COV__*/ printf("%d\n", i);
    }
    __apt_hits_test1_c_3bcb8323[13]++; /*__APT_COV__*/ return x * 2;
}

int main(int argc, char **argv)
{/* __APT_COV__ init */ atexit(__apt_write_lcov);
__apt_register_test1_c_3bcb8323();

    __apt_hits_test1_c_3bcb8323[18]++; /*__APT_COV__*/ printf("Hello %d", doubler(6));
    __apt_hits_test1_c_3bcb8323[19]++; /*__APT_COV__*/ return 0;
}
