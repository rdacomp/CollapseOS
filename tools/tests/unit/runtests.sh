#!/usr/bin/env bash

set -e

BASE=../../..
TOOLS=../..
ZASM="${TOOLS}/zasm.sh"
RUNBIN="${TOOLS}/emul/runbin/runbin"
KERNEL="${BASE}/kernel"
APPS="${BASE}/apps"

chk() {
    echo "Running test $1"
    if ! ${ZASM} "${KERNEL}" "${APPS}" < $1 | ${RUNBIN}; then
        echo "failed with code ${PIPESTATUS[1]}"
        exit 1
    fi
}

if [[ ! -z $1 ]]; then
    chk $1
    exit 0
fi

for fn in *.asm; do
    chk "${fn}"
done

echo "All tests passed!"
