jp	test

#include "core.asm"

testNum:	.db 1

test:
	ld	hl, 0xffff
	ld	sp, hl

	; *** subHL ***
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

	; *** cpHLDE ***
	ld	hl, 0x42
	ld	de, 0x42
	call	cpHLDE
	jp	nz, fail
	jp	c, fail
	call	nexttest

	ld	de, 0x4242
	call	cpHLDE
	jp	z, fail
	jp	nc, fail
	call	nexttest

	ld	hl, 0x4243
	call	cpHLDE
	jp	z, fail
	jp	c, fail
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
