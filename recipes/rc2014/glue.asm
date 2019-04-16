; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
RAMSTART	.equ	0x8000
RAMEND		.equ	0xffff
ACIA_CTL	.equ	0x80	; Control and status. RS off.
ACIA_IO		.equ	0x81	; Transmit. RS on.

jr	init

; interrupt hook
.fill	0x38-$
jp	aciaInt

init:
	di
	; setup stack
	ld	hl, RAMEND
	ld	sp, hl
	im 1
	call	aciaInit
	call	shellInit
	ei
	jp	shellLoop

#include "core.asm"
ACIA_RAMSTART	.equ	RAMSTART
#include "acia.asm"
SHELL_RAMSTART	.equ	ACIA_RAMEND
.define SHELL_GETC	call aciaGetC
.define SHELL_PUTC	call aciaPutC
.define SHELL_IO_GETC	call aciaGetC
SHELL_EXTRA_CMD_COUNT .equ 0
#include "shell.asm"
