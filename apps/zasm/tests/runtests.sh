#!/bin/sh

set -e

TMPFILE=$(mktemp)
SCAS=scas
ZASM=../emul/zasm
ASMFILE=../instr.asm

cmpas() {
    EXPECTED=$($SCAS -o - "$1" | xxd)
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

./geninstrs.py $ASMFILE | \
while read line; do
    echo $line | tee "${TMPFILE}"
    cmpas ${TMPFILE}
done

for fn in *.asm; do
    echo "Comparing ${fn}"
    cmpas $fn
done
