jp	test

#include "core.asm"
#include "parse.asm"
#include "zasm/util.asm"

testNum:	.db 1
sFoo:		.db "foo", 0

test:
	ld	hl, 0xffff
	ld	sp, hl

	ld	de, 12
	ld	bc, 4
	call	multDEBC
	ld	a, l
	cp	48
	jp	nz, fail
	call	nexttest

	ld	hl, sFoo
	call	strlen
	cp	3
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



