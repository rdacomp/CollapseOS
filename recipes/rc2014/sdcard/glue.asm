; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
.equ	RAMSTART	0x8000
.equ	RAMEND		0xffff
.equ	ACIA_CTL	0x80	; Control and status. RS off.
.equ	ACIA_IO		0x81	; Transmit. RS on.

jp	init

; *** JUMP TABLE ***
; Why not use this unused space between 0x03 and 0x38 for a jump table?
	jp	printstr
	jp	printHex
	jp	sdcInitialize
	jp	sdcSendRecv
	jp	sdcWaitResp
	jp	sdcCmd
	jp	sdcCmdR1
	jp	sdcCmdR7
	jp	sdcReadBlk
	jp	sdcSetBlkSize

; interrupt hook
.fill	0x38-$
jp	aciaInt

#include "core.asm"
#include "parse.asm"
.equ	ACIA_RAMSTART	RAMSTART
#include "acia.asm"
.equ	BLOCKDEV_RAMSTART	ACIA_RAMEND
.equ	BLOCKDEV_COUNT		2
#include "blockdev.asm"
; List of devices
.dw	aciaGetC, aciaPutC, 0, 0
.dw	sdcGetC, 0, 0, 0

#include "blockdev_cmds.asm"

.equ	STDIO_RAMSTART	BLOCKDEV_RAMEND
#include "stdio.asm"

.equ	SHELL_RAMSTART		STDIO_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT	3
#include "shell.asm"
.dw	sdcInitializeCmd, blkBselCmd, blkSeekCmd

.equ SDC_RAMSTART SHELL_RAMEND
.equ SDC_PORT_CSHIGH 6
.equ SDC_PORT_CSLOW 5
.equ SDC_PORT_SPI 4
#include "sdc.asm"

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

