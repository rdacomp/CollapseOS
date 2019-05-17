.equ	RAMSTART	0x4000
jp	test

#include "core.asm"
#include "util_z.asm"
.equ	SYM_RAMSTART	RAMSTART
#include "symbol.asm"

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
	call	symFind
	jp	nz, fail
	cp	1		; don't match FOOBAR
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




