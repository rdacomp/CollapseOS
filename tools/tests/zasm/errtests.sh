#!/bin/sh

# no "set -e" because we test errors

ZASM=../../emul/zasm/zasm

chkerr() {
    echo "Check that '$1' results in error $2"
    ${ZASM} <<< $1 > /dev/null
    local res=$?
    if [[ $res == $2 ]]; then
        echo "Good!"
    else
        echo "$res != $2"
        exit 1
    fi
}

chkerr "foo" 1
chkerr "ld a, foo" 2
chkerr "ld a, hl" 2
chkerr "ld a," 3
chkerr "ld a, 'A" 3
