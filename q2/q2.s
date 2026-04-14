    .data
fmt_num:    .asciz "%d"        # format string for printing one integer
fmt_space:  .asciz " "         # separator between numbers
fmt_newline:.asciz "\n"        # trailing newline

    .text
    .globl main

# ==========================================================================
# Q2: Next Greater Element — O(n) stack-based solution
# ==========================================================================
#
# PROBLEM: Given an array of integers (from argv), for each element find
#          the INDEX of the first element to its right that is strictly
#          greater. Output -1 if no such element exists.
#
# ALGORITHM (monotone stack, right-to-left):
#   1. Iterate from the LAST element to the FIRST.
#   2. Maintain a stack of indices whose values are in increasing order
#      from top to bottom.
#   3. For each element arr[i]:
#      a) Pop all stack entries whose arr value is <= arr[i]
#         (they can never be the answer for anything to the left).
#      b) If the stack is non-empty, the top is the next greater index.
#      c) Push i onto the stack.
#
# WHY O(n): Every index is pushed once and popped at most once → O(n).
#
# REGISTER MAP (callee-saved registers across function calls):
#   s0 = n     (number of elements)
#   s1 = argv  (pointer to argument strings)
#   s2 = arr   (pointer to parsed int array, heap-allocated)
#   s3 = result (pointer to result array, heap-allocated)
#   s4 = stack  (pointer to stack array, heap-allocated)
# ==========================================================================

main:
    # PROLOGUE: save all callee-saved registers we'll use
    addi    sp, sp, -48
    sd      ra, 40(sp)
    sd      s0, 32(sp)
    sd      s1, 24(sp)
    sd      s2, 16(sp)
    sd      s3, 8(sp)
    sd      s4, 0(sp)

    # argc is in a0, argv is in a1
    addiw   s0, a0, -1      # s0 = n = argc - 1 (skip program name)
    mv      s1, a1           # s1 = argv pointer

    blez    s0, .main_done   # no arguments → nothing to do

    # ---------- HEAP ALLOCATION ----------
    # We need three arrays, each of size n*4 bytes (int = 4 bytes):
    #   arr[n]    — the parsed input integers
    #   result[n] — the output (next greater element indices)
    #   stack[n]  — our monotone stack (stores indices)

    slliw   t0, s0, 2       # t0 = n * 4
    sext.w  a0, t0
    call    malloc
    mv      s2, a0           # s2 = arr

    slliw   t0, s0, 2
    sext.w  a0, t0
    call    malloc
    mv      s3, a0           # s3 = result

    slliw   t0, s0, 2
    sext.w  a0, t0
    call    malloc
    mv      s4, a0           # s4 = stack

    # ---------- STEP 1: PARSE argv[1..n] INTO arr[] ----------
    # argv[0] is the program name, so the actual numbers are argv[1..n].
    li      t0, 0            # t0 = loop index i
.parse_loop:
    bge     t0, s0, .parse_done

    # Calculate address of argv[i+1] (each pointer is 8 bytes)
    addi    t1, t0, 1
    slli    t1, t1, 3        # byte offset = (i+1) * 8
    add     t1, s1, t1
    ld      a0, 0(t1)        # a0 = argv[i+1] — a C string like "85"

    # atoi will clobber temp registers, so save our loop counter
    addi    sp, sp, -8
    sd      t0, 0(sp)
    call    atoi              # convert string → int, result in a0
    ld      t0, 0(sp)
    addi    sp, sp, 8

    # Store the parsed integer into arr[i]
    slli    t1, t0, 2        # byte offset = i * 4
    add     t1, s2, t1
    sw      a0, 0(t1)        # arr[i] = atoi(argv[i+1])

    addi    t0, t0, 1
    j       .parse_loop
.parse_done:

    # ---------- STEP 2: INITIALIZE result[] TO ALL -1 ----------
    li      t0, 0
    li      t1, -1
.init_result:
    bge     t0, s0, .init_done
    slli    t2, t0, 2
    add     t2, s3, t2
    sw      t1, 0(t2)        # result[i] = -1 (default: no next greater)
    addi    t0, t0, 1
    j       .init_result
.init_done:

    # ---------- STEP 3: MONOTONE STACK — RIGHT TO LEFT ----------
    # t3 = stack top index (-1 means empty)
    # The stack stores INDICES into arr[].
    li      t3, -1           # stack is initially empty

    addiw   t0, s0, -1       # t0 = i, starting from n-1 going down to 0
.nge_loop:
    bltz    t0, .nge_done    # if i < 0, we're done

    # Load arr[i] into t4
    slli    t1, t0, 2
    add     t1, s2, t1
    lw      t4, 0(t1)        # t4 = arr[i]

    # POP elements from the stack while arr[stack.top()] <= arr[i]
    # These popped elements are useless: they are not "greater" than arr[i],
    # so they can never be the next-greater for any element to the left of i.
.nge_while:
    bltz    t3, .nge_while_done      # stack empty → stop popping

    # Peek at the top of the stack
    slli    t5, t3, 2
    add     t5, s4, t5
    lw      t6, 0(t5)                # t6 = stack.top() (an index j)

    # Compare arr[j] with arr[i]
    slli    t5, t6, 2
    add     t5, s2, t5
    lw      t5, 0(t5)                # t5 = arr[stack.top()]

    bgt     t5, t4, .nge_while_done  # arr[j] > arr[i] → j is a valid answer

    addi    t3, t3, -1               # POP (discard this index)
    j       .nge_while
.nge_while_done:

    # If the stack is non-empty, the top is the next greater element's index
    bltz    t3, .nge_skip_assign     # stack empty → result[i] stays -1

    slli    t5, t3, 2
    add     t5, s4, t5
    lw      t6, 0(t5)                # t6 = stack.top() = answer for i

    slli    t5, t0, 2
    add     t5, s3, t5
    sw      t6, 0(t5)                # result[i] = stack.top()
.nge_skip_assign:

    # PUSH i onto the stack
    addi    t3, t3, 1
    slli    t5, t3, 2
    add     t5, s4, t5
    sw      t0, 0(t5)                # stack[++top] = i

    addiw   t0, t0, -1              # i--
    j       .nge_loop
.nge_done:

    # ---------- STEP 4: PRINT RESULTS ----------
    # Output: space-separated integers, one per input element
    li      t0, 0            # i = 0
.print_loop:
    bge     t0, s0, .print_done

    # Print a space separator (except before the first element)
    beqz    t0, .skip_space
    addi    sp, sp, -8
    sd      t0, 0(sp)
    la      a0, fmt_space
    call    printf
    ld      t0, 0(sp)
    addi    sp, sp, 8
.skip_space:

    # Print result[i]
    slli    t1, t0, 2
    add     t1, s3, t1
    lw      a1, 0(t1)        # a1 = result[i]

    addi    sp, sp, -8
    sd      t0, 0(sp)
    la      a0, fmt_num
    call    printf
    ld      t0, 0(sp)
    addi    sp, sp, 8

    addi    t0, t0, 1
    j       .print_loop
.print_done:

    # Trailing newline
    la      a0, fmt_newline
    call    printf

.main_done:
    # EPILOGUE: return 0
    li      a0, 0
    ld      ra, 40(sp)
    ld      s0, 32(sp)
    ld      s1, 24(sp)
    ld      s2, 16(sp)
    ld      s3, 8(sp)
    ld      s4, 0(sp)
    addi    sp, sp, 48
    ret
