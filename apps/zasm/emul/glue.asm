#include "user.inc"
; Glue code for the emulated environment
ZASM_INPUT	.equ	0xa000
ZASM_OUTPUT	.equ	0xd000

jr	init	; 2 bytes
; *** JUMP TABLE ***
jp	strncmp
jp	addDE
jp	upcase
jp	unsetZ
jp	intoDE

init:
	di
	ld	hl, RAMEND
	ld	sp, hl
	ld	hl, ZASM_INPUT
	ld	de, ZASM_OUTPUT
	call	USER_CODE
	; signal the emulator we're done
	; BC contains the number of written bytes
	ld	a, c
	ld	c, b
	out	(c), a
	halt

#include "core.asm"
