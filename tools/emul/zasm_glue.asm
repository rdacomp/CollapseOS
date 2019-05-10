; Glue code for the emulated environment
.equ USER_CODE		0x4000
.equ RAMEND		0xffff
.equ STDIO_PORT		0x00

jr	init	; 2 bytes
; *** JUMP TABLE ***
jp	strncmp
jp	addDE
jp	addHL
jp	upcase
jp	unsetZ
jp	intoDE
jp	findchar

init:
	di
	ld	hl, RAMEND
	ld	sp, hl
	ld	hl, emulGetC
	ld	de, emulPutC
	call	USER_CODE
	; signal the emulator we're done
	halt

emulGetC:
	in	a, (STDIO_PORT)
	or	a		; cp 0
	jr	z, .eof
	cp	a		; ensure z
	ret
.eof:
	call	unsetZ
	ret

emulPutC:
	out	(STDIO_PORT), a
	ret

#include "core.asm"
