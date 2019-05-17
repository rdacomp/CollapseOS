; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
RAMSTART	.equ	0x8000
RAMEND		.equ	0xffff
ACIA_CTL	.equ	0x80	; Control and status. RS off.
ACIA_IO		.equ	0x81	; Transmit. RS on.

jp	init

; interrupt hook
.fill	0x38-$
jp	aciaInt

#include "core.asm"
ACIA_RAMSTART	.equ	RAMSTART
#include "acia.asm"

BLOCKDEV_RAMSTART	.equ	ACIA_RAMEND
BLOCKDEV_COUNT		.equ	1
#include "blockdev.asm"
; List of devices
.dw	aciaGetC, aciaPutC, 0, 0

STDIO_RAMSTART	.equ	BLOCKDEV_RAMEND
#include "stdio.asm"

SHELL_RAMSTART	.equ	STDIO_RAMEND
.define SHELL_IO_GETC	call aciaGetC
.define SHELL_IO_PUTC	call aciaPutC
SHELL_EXTRA_CMD_COUNT .equ 0
#include "shell.asm"

init:
	di
	; setup stack
	ld	hl, RAMEND
	ld	sp, hl
	im 1

	call	aciaInit
	xor	a
	ld	de, BLOCKDEV_GETC
	call	blkSel
	call	stdioInit
	call	shellInit
	ei
	jp	shellLoop

