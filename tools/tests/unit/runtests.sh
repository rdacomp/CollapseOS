#!/bin/sh

set -e

BASE=../../..
TOOLS=../..
ZASM="${TOOLS}/zasm.sh"
RUNBIN="${TOOLS}/emul/runbin/runbin"
KERNEL="${BASE}/kernel"
APPS="${BASE}/apps"

for fn in *.asm; do
    echo "Running test ${fn}"
    if ! ${ZASM} "${KERNEL}" "${APPS}" < ${fn} | ${RUNBIN}; then
        echo "failed with code ${PIPESTATUS[1]}"
        exit 1
    fi
done

echo "All tests passed!"
