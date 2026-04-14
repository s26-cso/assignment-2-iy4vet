    .text

# ==========================================================================
# Q1: Binary Search Tree (BST) implementation in RISC-V assembly
# ==========================================================================
#
# MEMORY LAYOUT of struct Node (24 bytes, 8-byte aligned):
#
#   Byte offset:  [0..3]   [4..7]     [8..15]         [16..23]
#                  val     (padding)   left ptr        right ptr
#                  (int)              (Node*)          (Node*)
#
# Why 4 bytes of padding? Because pointers are 8 bytes on rv64.
# They need to be 8-byte aligned, so we pad after the 4-byte int.
#
# REGISTER CONVENTIONS (RISC-V calling convention):
#   - a0-a7: function arguments and return values
#   - s0-s11: callee-saved (we must save/restore if we use them)
#   - t0-t6: caller-saved temporaries (can be clobbered by calls)
#   - ra: return address (must be saved before making any call)
#   - sp: stack pointer
# ==========================================================================


# --------------------------------------------------------------------------
# struct Node* make_node(int val)
#
# Allocates a new BST node on the heap using malloc.
# Sets val to the given value, left and right to NULL.
#
# Args:    a0 = val (the integer value to store)
# Returns: a0 = pointer to the newly created node
# --------------------------------------------------------------------------
    .globl make_node
make_node:
    # PROLOGUE: save ra (we call malloc) and s0 (we need val after malloc)
    addi    sp, sp, -16
    sd      ra, 8(sp)
    sd      s0, 0(sp)

    mv      s0, a0          # save val in s0 (callee-saved, survives malloc)

    li      a0, 24          # malloc(24) — 24 bytes = sizeof(struct Node)
    call    malloc           # a0 now holds pointer to allocated memory

    # Initialize the three fields of the node
    sw      s0, 0(a0)       # node->val   = val         (offset 0, 4-byte store)
    sd      zero, 8(a0)     # node->left  = NULL        (offset 8, 8-byte store)
    sd      zero, 16(a0)    # node->right = NULL        (offset 16, 8-byte store)
    # a0 already points to the node — that's our return value

    # EPILOGUE: restore saved registers and return
    ld      ra, 8(sp)
    ld      s0, 0(sp)
    addi    sp, sp, 16
    ret


# --------------------------------------------------------------------------
# struct Node* insert(struct Node* root, int val)
#
# RECURSIVE BST insert. Standard algorithm:
#   - If root is NULL, create a new node and return it.
#   - If val < root->val, recurse into the left subtree.
#   - If val > root->val, recurse into the right subtree.
#   - (No duplicates will be inserted, per assignment clarification.)
# Always returns the root of the (sub)tree after insertion.
#
# Args:    a0 = root, a1 = val
# Returns: a0 = root (possibly a new node if root was NULL)
# --------------------------------------------------------------------------
    .globl insert
insert:
    # PROLOGUE: save ra (recursive calls), s0 (root), s1 (val)
    addi    sp, sp, -32
    sd      ra, 24(sp)
    sd      s0, 16(sp)
    sd      s1, 8(sp)
    sd      s2, 0(sp)

    mv      s0, a0          # s0 = root (preserved across recursive call)
    mv      s1, a1          # s1 = val  (preserved across recursive call)

    # BASE CASE: if root is NULL, create a new leaf node
    bnez    a0, .insert_not_null
    mv      a0, s1          # pass val as argument
    call    make_node        # make_node(val) → new leaf in a0
    j       .insert_done     # return the new node

.insert_not_null:
    lw      t0, 0(s0)       # t0 = root->val

    # DECIDE: go left or right?
    bge     s1, t0, .insert_go_right

    # val < root->val → insert into LEFT subtree
    ld      a0, 8(s0)       # a0 = root->left  (could be NULL)
    mv      a1, s1           # a1 = val
    call    insert           # recursively insert; returns updated left subtree
    sd      a0, 8(s0)       # root->left = updated subtree
    mv      a0, s0           # return original root
    j       .insert_done

.insert_go_right:
    # val > root->val → insert into RIGHT subtree
    ld      a0, 16(s0)      # a0 = root->right (could be NULL)
    mv      a1, s1           # a1 = val
    call    insert           # recursively insert; returns updated right subtree
    sd      a0, 16(s0)      # root->right = updated subtree
    mv      a0, s0           # return original root

.insert_done:
    # EPILOGUE
    ld      ra, 24(sp)
    ld      s0, 16(sp)
    ld      s1, 8(sp)
    ld      s2, 0(sp)
    addi    sp, sp, 32
    ret


# --------------------------------------------------------------------------
# struct Node* get(struct Node* root, int val)
#
# ITERATIVE BST search. Walk the tree:
#   - If current node's val matches, return its pointer.
#   - If target val is smaller, go left. Otherwise, go right.
#   - If we reach NULL, the value is not in the tree.
#
# This is iterative (no recursion), so we don't need to save ra.
#
# Args:    a0 = root, a1 = val to search for
# Returns: a0 = pointer to matching node, or NULL (0) if not found
# --------------------------------------------------------------------------
    .globl get
get:
.get_loop:
    beqz    a0, .get_not_found  # reached a NULL child → not in tree
    lw      t0, 0(a0)           # t0 = current->val
    beq     a1, t0, .get_found  # found! a0 already points to this node
    blt     a1, t0, .get_left   # target < current->val → search left
    ld      a0, 16(a0)          # target > current->val → go right
    j       .get_loop
.get_left:
    ld      a0, 8(a0)           # go to left child
    j       .get_loop
.get_found:
    ret                         # a0 = pointer to the found node
.get_not_found:
    li      a0, 0               # return NULL
    ret


# --------------------------------------------------------------------------
# int getAtMost(int val, struct Node* root)
#
# Finds the GREATEST value in the BST that is <= val.
# Returns -1 if every node's value is greater than val.
#
# ALGORITHM (iterative, no recursion needed):
#   - Start with best = -1.
#   - At each node:
#       • If node->val <= val: this is a valid candidate.
#         Update best = node->val, then go RIGHT (to find larger candidates).
#       • If node->val >  val: this node is too big.
#         Go LEFT (to find smaller values).
#   - When we hit NULL, return best.
#
# This is O(log n) — we descend the tree once, just like a search.
# We use only temp registers (no function calls), so no stack frame needed.
#
# Args:    a0 = val (target upper bound), a1 = root
# Returns: a0 = greatest value <= val, or -1
# --------------------------------------------------------------------------
    .globl getAtMost
getAtMost:
    mv      t1, a0          # t1 = val (the upper bound we're searching for)
    mv      t2, a1          # t2 = current node pointer
    li      a0, -1          # a0 = best answer so far (-1 = "nothing found yet")

.getAtMost_loop:
    beqz    t2, .getAtMost_done     # if current == NULL, we're done → return best
    lw      t0, 0(t2)               # t0 = current->val

    bgt     t0, t1, .getAtMost_go_left  # current->val > val → too big, go left

    # current->val <= val → valid candidate!
    mv      a0, t0                  # update best = current->val
    ld      t2, 16(t2)              # go RIGHT to look for an even larger valid val
    j       .getAtMost_loop

.getAtMost_go_left:
    ld      t2, 8(t2)               # go LEFT (current val is too big)
    j       .getAtMost_loop

.getAtMost_done:
    ret
