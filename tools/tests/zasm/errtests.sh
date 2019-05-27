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
chkerr ".db foo" 2
chkerr ".dw foo" 2
chkerr ".equ foo bar" 2
chkerr ".org foo" 2
chkerr ".fill foo" 2
chkerr "ld a," 3
chkerr "ld a, 'A" 3
chkerr ".db 0x42," 3
chkerr ".dw 0x4242," 3
chkerr ".equ" 3
chkerr ".equ foo" 3
chkerr ".org" 3
chkerr ".fill" 3
chkerr "ld a, 0x100" 4
chkerr ".db 0x100" 4
