#!/bin/sh

set -e

TMPFILE=$(mktemp)
SCAS=scas
ZASM=../emul/zasm
ASMFILE=../zasm.asm

./geninstrs.py $ASMFILE | \
while read line; do
    echo $line | tee "${TMPFILE}"
    EXPECTED=$($SCAS -o - "${TMPFILE}" | xxd)
    ACTUAL=$(echo $line | $ZASM | xxd)
    if [ "$ACTUAL" == "$EXPECTED" ]; then
        echo ok
    else
        echo actual
        echo $ACTUAL
        echo expected
        echo $EXPECTED
        exit 1
    fi
done
