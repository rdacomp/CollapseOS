; 8K of onboard RAM
.equ	RAMSTART	0xc000
; Memory register at the end of RAM. Must not overwrite
.equ	RAMEND		0xfdd0

	jp	init

.fill 0x66-$
	retn

#include "err.h"
#include "core.asm"
#include "parse.asm"

.equ	PAD_RAMSTART	RAMSTART
#include "sms/pad.asm"

.equ	VDP_RAMSTART	PAD_RAMEND
#include "sms/vdp.asm"

.equ	STDIO_RAMSTART	VDP_RAMEND
#include "stdio.asm"

.equ	SHELL_RAMSTART	STDIO_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT 0
#include "shell.asm"

init:
	di
	im	1

	ld	sp, RAMEND

	call	padInit
	call	vdpInit

	ld	hl, myGetC
	ld	de, vdpPutC
	call	stdioInit
	call	shellInit
	jp	shellLoop

myGetC:
	; What we do here is simple. We go though all bits of port A controller
	; increasing B each time. As soon as we get a hit, we display that
	; letter. Pressed buttons go low.
	call	padStatusA
	push	bc
	jr	z, .nothing	; unchanged since last poll
	ld	b, 'A'
	bit	5, a		; Port A Button C pressed
	jr	z, .something
	inc	b		; b
	bit	4, a		; Port A Button B pressed
	jr	z, .something
	inc	b		; c
	bit	3, a		; Port A Right pressed
	jr	z, .something
	inc	b		; d
	bit	2, a		; Port A Left pressed
	jr	z, .something
	inc	b		; e
	bit	1, a		; Port A Down pressed
	jr	z, .something
	inc	b		; f
	bit	0, a		; Port A Up pressed
	jr	z, .something
	inc	b		; g
	bit	6, a		; Port A Button A pressed
	jr	z, .something
	inc	b		; h
	bit	7, a		; Port A Start pressed
	jr	z, .something
	; nothing
.nothing:
	pop	bc
	xor	a
	jp	unsetZ
.something:
	ld	a, b
	pop	bc
	cp	a		; ensure Z
	ret

.fill 0x7ff0-$
.db "TMR SEGA", 0x00, 0x00, 0xfb, 0x68, 0x00, 0x00, 0x00, 0x4c
