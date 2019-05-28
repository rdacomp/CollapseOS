jp	test

#include "core.asm"

testNum:	.db 1

test:
	ld	hl, 0xffff
	ld	sp, hl

	ld	hl, 0x123
	ld	a, 0x25
	call	subHL
	ld	a, h
	cp	0
	jp	nz, fail
	ld	a, l
	cp	0xfe
	jp	nz, fail
	call	nexttest

	ld	hl, 0x125
	ld	a, 0x23
	call	subHL
	ld	a, h
	cp	1
	jp	nz, fail
	ld	a, l
	cp	0x02
	jp	nz, fail
	call	nexttest

	ld	hl, 0x125
	ld	a, 0x25
	call	subHL
	ld	a, h
	cp	1
	jp	nz, fail
	ld	a, l
	cp	0
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
