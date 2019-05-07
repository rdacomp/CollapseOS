; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
RAMSTART	.equ	0x8000
RAMEND		.equ	0xffff
ACIA_CTL	.equ	0x80	; Control and status. RS off.
ACIA_IO		.equ	0x81	; Transmit. RS on.

jr	init

; *** JUMP TABLE ***
; Why not use this unused space between 0x02 and 0x28 for a jump table?
	jp	printstr
	jp	printHex
	jp	sdcWakeUp
	jp	sdcSendRecv
	jp	sdcWaitResp
	jp	sdcCmd
	jp	sdcCmdR1
	jp	sdcCmdR7

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

	; TODO - block device creation

	ei
	jp	shellLoop

#include "core.asm"
ACIA_RAMSTART	.equ	RAMSTART
#include "acia.asm"
.define STDIO_GETC	call aciaGetC
.define STDIO_PUTC	call aciaPutC
STDIO_RAMSTART	.equ	ACIA_RAMEND
#include "stdio.asm"
SHELL_RAMSTART	.equ	STDIO_RAMEND
.define SHELL_IO_GETC	call aciaGetC
.define SHELL_IO_PUTC	call aciaPutC
SHELL_EXTRA_CMD_COUNT .equ 0
#include "shell.asm"

.equ SDC_PORT_CSHIGH 6
.equ SDC_PORT_CSLOW 5
.equ SDC_PORT_SPI 4
#include "sdc.asm"
