#!/bin/sh

set -e

TMPFILE=$(mktemp)
SCAS=scas
ZASM=../../../tools/emul/zasm
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

echo "Comparing core.asm"
cmpas ../../../parts/z80/core.asm

for fn in *.asm; do
    echo "Comparing ${fn}"
    cmpas $fn
done

./geninstrs.py $ASMFILE | \
while read line; do
    echo $line | tee "${TMPFILE}"
    cmpas ${TMPFILE}
done

