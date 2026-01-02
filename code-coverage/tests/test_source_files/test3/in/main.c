#include <stdio.h>
#include "math_operations.h"

int main() {
    int result = add(5, 3);
    printf("Result of addition: %d\n", result);
    
    int difference = subtract(10, 4);
    printf("Result of subtraction: %d\n", difference);
    
    return 0;
}
