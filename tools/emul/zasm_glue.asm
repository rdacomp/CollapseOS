; Glue code for the emulated environment
.equ USER_CODE		0x4000
.equ RAMEND		0xffff
.equ ZASM_INPUT		0xa000
.equ ZASM_OUTPUT	0xd000
.equ STDIO_PORT		0x00

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
	; yes, this means that input can't have null bytes
.inloop:
	in	a, (STDIO_PORT)
	ld	(hl), a		; before cond jr so we write a final \0
	or	a
	jr	z, .inloopend
	inc	hl
	jr	.inloop
.inloopend:
	ld	hl, ZASM_INPUT
	ld	de, ZASM_OUTPUT
	call	USER_CODE
	; BC contains the number of written bytes
	xor	a
	cp	b
	jr	nz, .spit
	cp	c
	jr	z, .end		; no output
.spit:
	ld	hl, ZASM_OUTPUT
.outloop:
	ld	a, (hl)
	out	(STDIO_PORT), a
	cpi			; a trick to inc HL and dec BC at the same time.
				; P/V indicates whether BC reached 0
	jp	pe, .outloop	; BC is not zero, loop
.end:
	; signal the emulator we're done
	halt

#include "core.asm"
