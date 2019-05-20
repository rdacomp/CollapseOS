#!/bin/sh

set -e
set -o pipefail

ZASM=../../emul/zasm/zasm
RUNBIN=../../emul/runbin/runbin

for fn in *.asm; do
    echo "Running test ${fn}"
    if ! ${ZASM} < ${fn} | ${RUNBIN}; then
        echo "failed with code ${PIPESTATUS[1]}"
        exit 1
    fi
done

echo "All tests passed!"
