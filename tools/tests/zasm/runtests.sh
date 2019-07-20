#!/bin/sh

set -e

TMPFILE=$(mktemp)
KERNEL=../../../kernel
APPS=../../../apps
ZASM=../../zasm.sh
ASMFILE=${APPS}/zasm/instr.asm

cmpas() {
    FN=$1
    shift 1
    EXPECTED=$(xxd ${FN}.expected)
    ACTUAL=$(cat ${FN} | $ZASM "$@" | xxd)
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

for fn in *.asm; do
    echo "Comparing ${fn}"
    cmpas $fn "${KERNEL}" "${APPS}"
done

./errtests.sh
