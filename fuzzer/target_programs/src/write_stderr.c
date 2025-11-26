#include <stdio.h>
#include <unistd.h>

int main() {
    fprintf(stderr, "this is an error message");
    return 1;
}