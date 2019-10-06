; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
.equ	RAMSTART	0x8000
.equ	RAMEND		0xffff
.equ	ACIA_CTL	0x80	; Control and status. RS off.
.equ	ACIA_IO		0x81	; Transmit. RS on.

jp	init

; interrupt hook
.fill	0x38-$
jp	aciaInt

.inc "err.h"
.inc "core.asm"
.inc "parse.asm"
.equ	ACIA_RAMSTART	RAMSTART
.inc "acia.asm"

.equ	STDIO_RAMSTART	ACIA_RAMEND
.inc "stdio.asm"

.equ	SHELL_RAMSTART	STDIO_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT 0
.inc "shell.asm"

init:
	di
	; setup stack
	ld	hl, RAMEND
	ld	sp, hl
	im 1

	call	aciaInit
	ld	hl, aciaGetC
	ld	de, aciaPutC
	call	stdioInit
	call	shellInit
	ei
	jp	shellLoop

