#!/usr/bin/env bash

# readlink -f doesn't work with macOS's implementation
# so, if we can't get readlink -f to work, try python with a realpath implementation
ABS_PATH=$(readlink -f "$0" || python -c "import sys, os; print(os.path.realpath('$0'))")

# wrapper around ./emul/zasm/zasm that prepares includes CFS prior to call
DIR=$(dirname "${ABS_PATH}")
ZASMBIN="${DIR}/emul/zasm/zasm"
CFSPACK="${DIR}/cfspack/cfspack"
INCCFS=$(mktemp)

for p in "$@"; do
    "${CFSPACK}" "${p}" "*.h" >> "${INCCFS}"    
    "${CFSPACK}" "${p}" "*.asm" >> "${INCCFS}"    
done

"${ZASMBIN}" "${INCCFS}"
RES=$?
rm "${INCCFS}"
exit $RES
