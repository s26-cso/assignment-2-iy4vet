#!/bin/bash
# ==========================================================================
# Master build & test script for Assignment 2
# Usage: ./run_all.sh
#
# Compiles and tests all questions. Uses qemu-riscv64-static for execution.
# For Q1, a temporary main.c test driver is generated.
# ==========================================================================

set -e
CC=riscv64-linux-gnu-gcc
QEMU=qemu-riscv64-static
BASE=$(cd "$(dirname "$0")" && pwd)

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { echo -e "  ${RED}FAIL${NC}: $1 (got '$2', expected '$3')"; FAILURES=$((FAILURES+1)); }
FAILURES=0

check() {
    local desc="$1" got="$2" expected="$3"
    if [ "$got" = "$expected" ]; then pass "$desc"; else fail "$desc" "$got" "$expected"; fi
}

# ===================== Q1 =====================
echo -e "\n${BOLD}=== Q1: Binary Search Tree ===${NC}"
cd "$BASE/q1"

cat > /tmp/_test_q1.c << 'EOFC'
#include <stdio.h>
struct Node { int val; struct Node* left; struct Node* right; };
extern struct Node* make_node(int val);
extern struct Node* insert(struct Node* root, int val);
extern struct Node* get(struct Node* root, int val);
extern int getAtMost(int val, struct Node* root);
int main() {
    struct Node* r = 0;
    r = insert(r, 10); r = insert(r, 5); r = insert(r, 15);
    r = insert(r, 3);  r = insert(r, 7); r = insert(r, 12); r = insert(r, 20);
    // get
    printf("%d\n", get(r,7) ? get(r,7)->val : -999);
    printf("%d\n", get(r,99) ? 1 : 0);
    // getAtMost
    printf("%d\n", getAtMost(6,r));
    printf("%d\n", getAtMost(2,r));
    printf("%d\n", getAtMost(20,r));
    printf("%d\n", getAtMost(5,0));
    return 0;
}
EOFC
$CC -static /tmp/_test_q1.c q1.s -o /tmp/_q1_test
OUT=$($QEMU /tmp/_q1_test)
check "get(7)=7"           "$(echo "$OUT" | sed -n 1p)" "7"
check "get(99)=NULL"       "$(echo "$OUT" | sed -n 2p)" "0"
check "getAtMost(6)=5"     "$(echo "$OUT" | sed -n 3p)" "5"
check "getAtMost(2)=-1"    "$(echo "$OUT" | sed -n 4p)" "-1"
check "getAtMost(20)=20"   "$(echo "$OUT" | sed -n 5p)" "20"
check "getAtMost(5,NULL)=-1" "$(echo "$OUT" | sed -n 6p)" "-1"
rm -f /tmp/_test_q1.c /tmp/_q1_test

# ===================== Q2 =====================
echo -e "\n${BOLD}=== Q2: Next Greater Element ===${NC}"
cd "$BASE/q2"
$CC -static q2.s -o /tmp/_q2
check "example 1" "$($QEMU /tmp/_q2 85 96 70 80 102)"    "1 4 3 4 -1"
check "example 2" "$($QEMU /tmp/_q2 91 10 99 93 109 90 78)" "2 2 4 4 -1 -1 -1"
check "single"    "$($QEMU /tmp/_q2 5)"                   "-1"
check "ascending" "$($QEMU /tmp/_q2 1 2 3 4 5)"           "1 2 3 4 -1"
check "all same"  "$($QEMU /tmp/_q2 5 5 5 5)"             "-1 -1 -1 -1"
check "descending" "$($QEMU /tmp/_q2 5 4 3 2 1)"          "-1 -1 -1 -1 -1"
rm -f /tmp/_q2

# ===================== Q3a =====================
echo -e "\n${BOLD}=== Q3a: Password Extraction ===${NC}"
cd "$BASE/q3/a"
OUT=$(./target_iy4vet < payload.txt 2>&1 || true)
if echo "$OUT" | grep -q "You have passed!"; then
    pass "payload.txt produces 'You have passed!'"
else
    fail "payload.txt" "$OUT" "You have passed!"
fi

# ===================== Q3b =====================
echo -e "\n${BOLD}=== Q3b: Buffer Overflow ===${NC}"
cd "$BASE/q3/b"
OUT=$(./target_iy4vet < payload 2>&1 || true)
if echo "$OUT" | grep -q "You have passed!"; then
    pass "payload produces output containing 'You have passed!'"
else
    fail "payload" "$OUT" "(should contain 'You have passed!')"
fi

# ===================== Q4 =====================
echo -e "\n${BOLD}=== Q4: Dynamic Calculator ===${NC}"
cd /tmp && mkdir -p _q4test && cd _q4test
# Build test shared libraries (native x86 for local testing)
printf 'int add(int a,int b){return a+b;}\n' > add.c
printf 'int mul(int a,int b){return a*b;}\n' > mul.c
printf 'int sub(int a,int b){return a-b;}\n' > sub.c
gcc -shared -fPIC -o libadd.so add.c
gcc -shared -fPIC -o libmul.so mul.c
gcc -shared -fPIC -o libsub.so sub.c
gcc "$BASE/q4/q4.c" -ldl -o q4
OUT=$(printf "add 12 9\nmul 3 4\nsub 10 3\n" | ./q4)
check "add 12 9 = 21"  "$(echo "$OUT" | sed -n 1p)" "21"
check "mul 3 4 = 12"   "$(echo "$OUT" | sed -n 2p)" "12"
check "sub 10 3 = 7"   "$(echo "$OUT" | sed -n 3p)" "7"
rm -rf /tmp/_q4test

# ===================== Q5 =====================
echo -e "\n${BOLD}=== Q5: Palindrome Check ===${NC}"
cd "$BASE/q5"
$CC -static q5.s -o /tmp/_q5
run_q5() { printf "%s" "$2" > input.txt; check "$1" "$($QEMU /tmp/_q5 | tr -d '\n')" "$3"; }
run_q5 "even palindrome 'abccba'" "abccba" "Yes"
run_q5 "odd palindrome 'abcba'"   "abcba"  "Yes"
run_q5 "not palindrome 'abc'"     "abc"     "No"
run_q5 "single char 'a'"          "a"       "Yes"
run_q5 "empty file"               ""        "Yes"
run_q5 "two same 'aa'"            "aa"      "Yes"
run_q5 "two diff 'ab'"            "ab"      "No"
rm -f /tmp/_q5 input.txt

# ===================== Summary =====================
echo ""
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All tests passed!${NC}"
else
    echo -e "${RED}${BOLD}$FAILURES test(s) failed.${NC}"
fi
exit $FAILURES
