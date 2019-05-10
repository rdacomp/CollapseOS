; Glue code for the emulated environment
.equ RAMSTART		0x4000
.equ USER_CODE		0x4800
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
jp	parseHexPair
jp	blkSel

init:
	di
	; We put the stack at the end of the kernel memory
	ld	hl, USER_CODE-1
	ld	sp, hl
	ld	h, 0	; input blkdev
	ld	l, 1	; output blkdev
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
.equ	BLOCKDEV_RAMSTART	RAMSTART
.equ	BLOCKDEV_COUNT		2
#include "blockdev.asm"
; List of devices
.dw	emulGetC, 0, 0, 0
.dw	0, emulPutC, 0, 0
