#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h> 

// Bug 1: Stack Buffer Overflow (Location 1)
// Trigger: 'a'-'j'
// Signature: asan:stack:test_target.c:11
void cause_stack_overflow_1(const char *input) {
    char buffer[8];
    strcpy(buffer, input); // Overflow 1!
    printf("Oops, stack overflow 1 failed: %s\n", buffer);
}

// Bug 2: Stack Buffer Overflow (Location 2)
// Trigger: 'k'-'t'
// Signature: asan:stack:test_target.c:18
void cause_stack_overflow_2(const char *input) {
    char buffer[4];
    strcpy(buffer, input); // Overflow 2!
    printf("Oops, stack overflow 2 failed: %s\n", buffer);
}

// Bug 3: Heap Buffer Overflow (Location 1)
// Trigger: 'H'
// Signature: asan:heap:test_target.c:25
void cause_heap_overflow_1(const char *input) {
    char *buffer = (char *)malloc(8);
    if (buffer == NULL) return;
    strcpy(buffer, input); // Overflow 3!
    printf("Oops, heap overflow 1 failed: %s\n", buffer);
    free(buffer);
}

// Bug 4: Heap Buffer Overflow (Location 2)
// Trigger: 'S'
// Signature: asan:heap:test_target.c:34
void cause_heap_overflow_2(const char *input) {
    char *buffer = (char *)malloc(4);
    if (buffer == NULL) return;
    strcpy(buffer, input); // Overflow 4!
    printf("Oops, heap overflow 2 failed: %s\n", buffer);
    free(buffer);
}

// Bug 5: Timeout / Hang
// Trigger: 'T'
// Signature: timeout:<limit>
void cause_hang(void) {
    while (1) {
        sleep(1);
    }
}

// Bug 6: Non-zero Exit Code
// Trigger: 'E'
// Signature: rc:42
int cause_exit(void) {
    return 42;
}

int main(int argc, char *argv[]) {
    char input[256]; // Buffer to hold stdin input

    // Read one line from stdin
    if (fgets(input, sizeof(input), stdin) == NULL) {
        return 0; // EOF or error
    }

    // Remove trailing newline character, if present
    input[strcspn(input, "\n")] = 0;

    // Check for empty input
    if (strlen(input) == 0) {
        return 0; // Empty input, no crash
    }

    char trigger = input[0];

    // Lowercase 'a'-'t' -> Stack Overflows
    if (trigger >= 'a' && trigger <= 'j') {
        cause_stack_overflow_1(input);
        return 0;
    }
    if (trigger >= 'k' && trigger <= 't') {
        cause_stack_overflow_2(input);
        return 0;
    }

    // Capitals 'A'-'Z' -> Various Bugs
    if (trigger >= 'A' && trigger <= 'Z') {
        switch (trigger) {
            case 'H': // Heap 1
                cause_heap_overflow_1(input);
                break;
            case 'S': // Heap 2
                cause_heap_overflow_2(input);
                break;
            case 'T': // Timeout
                cause_hang();
                break;
            case 'E': // Exit
                return cause_exit();
            default:
                // Other capitals are safe
                return 0;
        }
    }

    return 0;
}