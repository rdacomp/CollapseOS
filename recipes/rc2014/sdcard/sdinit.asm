#include "jumptable.inc"
.org	0x9000

	call	JUMP_SDCWAKEUP

	ld	a, 0b01000000	; CMD0
	ld	hl, 0
	ld	de, 0
	ld	c, 0x95
	call	JUMP_SDCCMDR1
	call	JUMP_PRINTHEX
	ld	a, 0b01001000	; CMD8
	ld	hl, 0
	ld	de, 0x01aa
	ld	c, 0x87
	call	JUMP_SDCCMDR7
	call	JUMP_PRINTHEX
	ret
