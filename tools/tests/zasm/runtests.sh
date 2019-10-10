#!/usr/bin/env bash

set -e

KERNEL=../../../kernel
APPS=../../../apps
ZASM=../../zasm.sh
ASMFILE=${APPS}/zasm/instr.asm

cmpas() {
    FN=$1
    EXPECTED=$(xxd ${FN}.expected)
    ACTUAL=$(cat ${FN} | $ZASM "${KERNEL}" "${APPS}" | xxd)
    if [ "$ACTUAL" == "$EXPECTED" ]; then
        echo ok
    else
        echo actual
        echo $ACTUAL
        echo expected
        echo $EXPECTED
        exit 1
    fi
}

if [[ ! -z $1 ]]; then
    cmpas $1
    exit 0
fi

for fn in *.asm; do
    echo "Comparing ${fn}"
    cmpas $fn
done

./errtests.sh
