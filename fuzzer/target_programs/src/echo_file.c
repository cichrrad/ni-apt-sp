#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Opens the file at path argv[1], reads it, and prints its contents.
int main(int argc, char **argv) {

    if (argc < 2) {
        return 1; // No file provided
    }
    
    // "rb" = read in binary mode.
    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        return 1; // File not found
    }
    
    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0) {
        fwrite(buf, 1, n, stdout);
    }
    
    fclose(f);
    return 0;
}