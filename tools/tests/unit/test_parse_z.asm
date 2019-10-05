.equ	RAMSTART	0x4000
; declare DIREC_LASTVAL manually so that we don't have to include directive.asm
.equ	DIREC_LASTVAL	RAMSTART

jp	test

#include "core.asm"
#include "parse.asm"
#include "lib/util.asm"
#include "zasm/util.asm"
#include "lib/parse.asm"
#include "zasm/parse.asm"

; mocks. aren't used in tests
zasmGetPC:
zasmIsFirstPass:
symSelect:
symFindVal:
	jp	fail

testNum:	.db 1

s99:		.db "99", 0
s0x99:		.db "0x99", 0
s0x100:		.db "0x100", 0
s0b0101:	.db "0b0101", 0
s0b01010101:	.db "0b01010101", 0
sFoo:		.db "Foo", 0

test:
	ld	hl, 0xffff
	ld	sp, hl

	ld	hl, s99
	call	parseLiteral
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	or	a
	jp	nz, fail
	ld	a, l
	cp	99
	jp	nz, fail
	call	nexttest

	ld	hl, s0x100
	call	parseLiteral
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	cp	1
	jp	nz, fail
	ld	a, l
	or	a
	jp	nz, fail
	call	nexttest

	ld	hl, sFoo
	call	parseLiteral
	jp	z, fail
	call	nexttest

	ld	hl, s0b0101
	call	parseLiteral
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	or	a
	jp	nz, fail
	ld	a, l
	cp	0b0101
	jp	nz, fail
	call	nexttest

	ld	hl, s0b01010101
	call	parseLiteral
	jp	nz, fail
	push	ix \ pop hl
	ld	a, h
	or	a
	jp	nz, fail
	ld	a, l
	cp	0b01010101
	jp	nz, fail
	call	nexttest

.equ	FOO		0x42
.equ	BAR		@+1
	ld	a, BAR
	cp	0x43
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


