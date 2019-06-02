#!/bin/bash

# wrapper around ./emul/zasm/zasm that prepares includes CFS prior to call
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ZASMBIN="${DIR}/emul/zasm/zasm"
CFSPACK="${DIR}/cfspack/cfspack"
INCCFS=$(mktemp)

for p in "$@"; do
    "${CFSPACK}" "${p}" "*.+(asm|h)" >> "${INCCFS}"    
done

"${ZASMBIN}" "${INCCFS}"
RES=$?
rm "${INCCFS}"
exit $RES
