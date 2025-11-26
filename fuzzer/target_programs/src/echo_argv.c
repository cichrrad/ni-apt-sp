#include <stdio.h>
#include <unistd.h>

// Prints its first command-line argument.
int main(int argc, char **argv) {

    if (argc > 1) {
        printf("%s", argv[1]);
    }
    return 0;
}