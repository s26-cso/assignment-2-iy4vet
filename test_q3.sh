#!/bin/bash
# ==========================================================================
# Q3 helper: Test both Q3a and Q3b payloads
#
# Usage: ./test_q3.sh
#
# Requires the target binaries to be executable and qemu binfmt registered
# (run: sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes)
# ==========================================================================

set -e
BASE=$(cd "$(dirname "$0")" && pwd)
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}=== Q3a: Password Reverse Engineering ===${NC}"
cd "$BASE/q3/a"
chmod +x target_iy4vet 2>/dev/null || true
echo "Payload content: $(cat payload.txt)"
echo -n "Running: ./target_iy4vet < payload.txt → "
OUT=$(./target_iy4vet < payload.txt 2>&1 || true)
echo "$OUT"
if echo "$OUT" | grep -q "You have passed!"; then
    echo -e "${GREEN}SUCCESS${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo ""
echo -e "${BOLD}=== Q3b: Buffer Overflow Exploit ===${NC}"
cd "$BASE/q3/b"
chmod +x target_iy4vet 2>/dev/null || true
echo "Payload size: $(wc -c < payload) bytes"
echo "Payload hex (last 16 bytes):"
xxd payload | tail -1
echo -n "Running: ./target_iy4vet < payload → "
OUT=$(./target_iy4vet < payload 2>&1 || true)
echo "$OUT"
if echo "$OUT" | grep -q "You have passed!"; then
    echo -e "${GREEN}SUCCESS (output contains 'You have passed!')${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi
