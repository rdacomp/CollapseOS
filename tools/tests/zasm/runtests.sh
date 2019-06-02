#!/bin/sh

set -e

TMPFILE=$(mktemp)
SCAS=scas
KERNEL=../../../kernel
APPS=../../../apps
ZASM=../../zasm.sh
ASMFILE=${APPS}/zasm/instr.asm

cmpas() {
    FN=$1
    shift 1
    EXPECTED=$($SCAS -I ${KERNEL} -I ${APPS} -o - "${FN}" | xxd)
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

for fn in test*.asm; do
    echo "Comparing ${fn}"
    cmpas $fn "${KERNEL}" "${APPS}"
done

./geninstrs.py $ASMFILE | \
while read line; do
    echo $line | tee "${TMPFILE}"
    cmpas ${TMPFILE}
done

./errtests.sh
