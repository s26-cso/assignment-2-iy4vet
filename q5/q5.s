    .data
filename:   .asciz "input.txt"
msg_yes:    .asciz "Yes\n"
msg_no:     .asciz "No\n"

    .text
    .globl main

# ==========================================================================
# Q5: Palindrome Check — O(n) time, O(1) space
# ==========================================================================
#
# PROBLEM: Read a file "input.txt" (can be arbitrarily large — too big to
#          load entirely into memory). Check if its contents form a
#          palindrome. Print "Yes" or "No".
#
# APPROACH (two-pointer with lseek):
#   Since we can't load the whole file, we use the FILE POSITION as our
#   pointer. We keep two logical pointers: "left" (starts at byte 0) and
#   "right" (starts at the last byte).
#
#   Each iteration:
#     1. lseek to "left",  read 1 byte.
#     2. lseek to "right", read 1 byte.
#     3. If they differ → not a palindrome.
#     4. Move left++, right--, repeat until they meet or cross.
#
#   This uses only 2 bytes of buffer (on the stack) → O(1) space.
#   We visit each byte at most once from each end → O(n) time.
#
# KEY SYSCALLS / C LIBRARY FUNCTIONS USED:
#   open(path, flags)      — open the file, returns file descriptor (fd)
#   lseek(fd, offset, whence) — move the file cursor
#     whence=0 (SEEK_SET): absolute position
#     whence=2 (SEEK_END): relative to end of file
#   read(fd, buf, count)   — read bytes from the current cursor position
#   close(fd)              — close the file
#
# REGISTER MAP (callee-saved, persist across function calls):
#   s0 = file descriptor (fd)
#   s1 = left pointer  (byte offset from start)
#   s2 = right pointer (byte offset from start)
#   s3 = file length (n)
# ==========================================================================

main:
    # PROLOGUE: allocate 48 bytes on stack
    #   40(sp) = ra, 32(sp) = s0, 24(sp) = s1, 16(sp) = s2, 8(sp) = s3
    #   0(sp) and 4(sp) = 1-byte read buffers for left and right characters
    addi    sp, sp, -48
    sd      ra, 40(sp)
    sd      s0, 32(sp)
    sd      s1, 24(sp)
    sd      s2, 16(sp)
    sd      s3, 8(sp)

    # --- STEP 1: Open the file ---
    la      a0, filename     # a0 = "input.txt"
    li      a1, 0            # a1 = O_RDONLY (read-only)
    call    open
    mv      s0, a0           # s0 = fd (file descriptor)

    # --- STEP 2: Get the file size using lseek ---
    # lseek(fd, 0, SEEK_END) moves cursor to end and returns the offset,
    # which is the file size in bytes.
    mv      a0, s0
    li      a1, 0            # offset = 0
    li      a2, 2            # SEEK_END = 2
    call    lseek
    mv      s3, a0           # s3 = n = file length

    # --- STEP 3: Initialize two pointers ---
    li      s1, 0            # left  = 0  (first character)
    addi    s2, s3, -1       # right = n-1 (last character)

    # --- STEP 4: Compare characters from both ends ---
.check_loop:
    # If left >= right, all pairs matched → palindrome
    bge     s1, s2, .is_palindrome

    # Read the LEFT character: seek to position 'left', read 1 byte
    mv      a0, s0           # fd
    mv      a1, s1           # offset = left
    li      a2, 0            # SEEK_SET = 0 (absolute position)
    call    lseek

    mv      a0, s0           # fd
    addi    a1, sp, 0        # buffer at sp+0 (1 byte)
    li      a2, 1            # read 1 byte
    call    read

    # Read the RIGHT character: seek to position 'right', read 1 byte
    mv      a0, s0           # fd
    mv      a1, s2           # offset = right
    li      a2, 0            # SEEK_SET = 0
    call    lseek

    mv      a0, s0           # fd
    addi    a1, sp, 4        # buffer at sp+4 (1 byte, separate from left)
    li      a2, 1            # read 1 byte
    call    read

    # Compare the two characters (loaded as unsigned bytes)
    lbu     t0, 0(sp)        # t0 = character at position 'left'
    lbu     t1, 4(sp)        # t1 = character at position 'right'
    bne     t0, t1, .not_palindrome  # mismatch → not a palindrome

    # Move both pointers inward
    addi    s1, s1, 1        # left++
    addi    s2, s2, -1       # right--
    j       .check_loop

.is_palindrome:
    la      a0, msg_yes
    call    printf
    j       .done

.not_palindrome:
    la      a0, msg_no
    call    printf

.done:
    # --- STEP 5: Clean up ---
    mv      a0, s0           # close(fd)
    call    close

    # EPILOGUE: return 0
    li      a0, 0
    ld      ra, 40(sp)
    ld      s0, 32(sp)
    ld      s1, 24(sp)
    ld      s2, 16(sp)
    ld      s3, 8(sp)
    addi    sp, sp, 48
    ret
