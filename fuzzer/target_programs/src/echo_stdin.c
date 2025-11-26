#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// paste stdin to stdout
int main() {

    char buf[4096];
    size_t n;
    
    while ((n = fread(buf, 1, sizeof(buf), stdin)) > 0) {
        fwrite(buf, 1, n, stdout);
    }
    
    return 0;
}