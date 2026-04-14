/*
 * Q4: Dynamic Calculator using Runtime-Loaded Shared Libraries
 *
 * HOW IT WORKS:
 *   1. Read lines of the form "<op> <num1> <num2>" from stdin in a loop.
 *   2. For each operation, load the shared library "./lib<op>.so" at RUNTIME
 *      using dlopen (dynamic linker open).
 *   3. Look up the function named "<op>" inside the library using dlsym.
 *   4. Call that function with (num1, num2) and print the result.
 *   5. Before loading the next library, CLOSE the previous one with dlclose.
 *
 * WHY dlopen/dlsym?
 *   The libraries are NOT available at compile time. They're provided only
 *   when the app runs. So we can't just #include or link against them.
 *   dlopen loads a .so file into memory at runtime, and dlsym finds a
 *   specific symbol (function) inside it by name — like a dictionary lookup.
 *
 * MEMORY CONSTRAINT (2GB limit):
 *   Each library can be up to 1.5GB. If we kept two open at once, we'd
 *   exceed 2GB. So we MUST dlclose the old library before dlopen-ing a new
 *   one. This ensures only one library is loaded at any time.
 *
 * COMPILATION: gcc q4.c -ldl -o q4
 *   The -ldl flag links against libdl (the dynamic loading library).
 */

#include <stdio.h>
#include <dlfcn.h>

int main() {
    char op[6];            /* operation name: max 5 chars + null terminator */
    int num1, num2;
    void *handle = NULL;   /* handle to the currently loaded shared library */

    /* Read input lines until EOF or malformed input */
    while (scanf("%s %d %d", op, &num1, &num2) == 3) {

        /* Construct the library filename, e.g. "add" → "./libadd.so" */
        char libpath[20];
        snprintf(libpath, sizeof(libpath), "./lib%s.so", op);

        /* Close the previously loaded library (critical for 2GB constraint) */
        if (handle) {
            dlclose(handle);
            handle = NULL;
        }

        /* Load the shared library into this process's address space.
         * RTLD_LAZY means: don't resolve all symbols now, only when used. */
        handle = dlopen(libpath, RTLD_LAZY);
        if (!handle) {
            continue;   /* library not found — skip this line */
        }

        /* Find the function named <op> inside the library.
         * dlsym returns a void* to the function; we cast it to (int,int)->int. */
        int (*func)(int, int) = (int (*)(int, int))dlsym(handle, op);
        if (!func) {
            dlclose(handle);
            handle = NULL;
            continue;   /* function not found in library */
        }

        /* Call the function and print the result */
        printf("%d\n", func(num1, num2));
    }

    /* Clean up: close the last loaded library before exiting */
    if (handle) {
        dlclose(handle);
    }

    return 0;
}
