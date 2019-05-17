jp	test

#include "core.asm"
#include "parse.asm"
#include "util_z.asm"
#include "parse_z.asm"

; mocks. aren't used in tests
zasmIsFirstPass:
symSelect:
symFind:
symGetVal:
	jp	fail

testNum:	.db 1

s99:		.db "99", 0
s0x99:		.db "0x99", 0
s0b0101:	.db "0b0101", 0
s0b01010101:	.db "0b01010101", 0
sFoo:		.db "Foo", 0

test:
	ld	hl, 0xffff
	ld	sp, hl

	ld	hl, s99
	call	parseLiteral
	jp	nz, fail
	ld	a, ixh
	or	a
	jp	nz, fail
	ld	a, ixl
	cp	99
	jp	nz, fail
	call	nexttest

	ld	hl, sFoo
	call	parseLiteral
	jp	z, fail
	call	nexttest

	ld	hl, s0b0101
	call	parseLiteral
	jp	nz, fail
	ld	a, ixh
	or	a
	jp	nz, fail
	ld	a, ixl
	cp	0b0101
	jp	nz, fail
	call	nexttest

	ld	hl, s0b01010101
	call	parseLiteral
	jp	nz, fail
	ld	a, ixh
	or	a
	jp	nz, fail
	ld	a, ixl
	cp	0b01010101
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


