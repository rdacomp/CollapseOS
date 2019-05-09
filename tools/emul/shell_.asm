; named shell_.asm to avoid infinite include loop.
RAMSTART	.equ	0x4000
RAMEND		.equ	0x5000
STDIO_PORT	.equ	0x00

jr	init

init:
	di
	; setup stack
	ld	hl, RAMEND
	ld	sp, hl
	call	shellInit
	jp	shellLoop

#include "core.asm"
.define STDIO_GETC	call emulGetC
.define STDIO_PUTC	call emulPutC
STDIO_RAMSTART	.equ	RAMEND
#include "stdio.asm"

BLOCKDEV_RAMSTART	.equ	STDIO_RAMEND
BLOCKDEV_COUNT		.equ	1
#include "blockdev.asm"
; List of devices
.dw	emulGetC, emulPutC, 0, 0

#include "blockdev_cmds.asm"

SHELL_RAMSTART	.equ	BLOCKDEV_RAMEND
.define SHELL_IO_GETC	call blkGetCW
.define SHELL_IO_PUTC	call blkPutC
SHELL_EXTRA_CMD_COUNT .equ 2
#include "shell.asm"
.dw	blkBselCmd, blkSeekCmd

emulGetC:
	; Blocks until a char is returned
	in	a, (STDIO_PORT)
	cp	a		; ensure Z
	ret

emulPutC:
	out	(STDIO_PORT), a
	ret

