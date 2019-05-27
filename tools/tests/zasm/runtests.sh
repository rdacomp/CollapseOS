#!/bin/sh

set -e

TMPFILE=$(mktemp)
SCAS=scas
KERNEL=../../../kernel
APPS=../../../apps
ZASM=../../emul/zasm/zasm
ASMFILE=${APPS}/zasm/instr.asm

cmpas() {
    EXPECTED=$($SCAS -I ${KERNEL} -I ${APPS} -o - "$1" | xxd)
    ACTUAL=$(cat $1 | $ZASM | xxd)
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

for fn in test*.asm; do
    echo "Comparing ${fn}"
    cmpas $fn
done

./geninstrs.py $ASMFILE | \
while read line; do
    echo $line | tee "${TMPFILE}"
    cmpas ${TMPFILE}
done

./errtests.sh
