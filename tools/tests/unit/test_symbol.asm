.equ	RAMSTART	0x4000
jp	test

#include "core.asm"
#include "zasm/util.asm"
.equ	SYM_RAMSTART	RAMSTART
#include "zasm/symbol.asm"

testNum:	.db 1

sFOO:		.db "FOO", 0
sFOOBAR:	.db "FOOBAR", 0

test:
	ld	hl, 0xffff
	ld	sp, hl

	; Check that we compare whole strings (a prefix will not match a longer
	; string).
	call	symInit
	ld	hl, sFOOBAR
	ld	de, 42
	call	symRegister
	jp	nz, fail
	ld	hl, sFOO
	ld	de, 43
	call	symRegister
	jp	nz, fail

	ld	hl, sFOO
	call	symFind		; don't match FOOBAR
	jp	nz, fail
	call	symGetVal
	ld	a, d
	or	a
	jp	nz, fail
	ld	a, e
	cp	43
	jp	nz, fail
	call	nexttest

	; success
	xor	a
	halt

nexttest:
	ld	a, (testNum)
	inc	a
	ld	(testNum), a
	ret

fail:
	ld	a, (testNum)
	halt




