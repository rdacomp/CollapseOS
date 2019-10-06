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

.equ	MMAP_START	0xd000
.inc "mmap.asm"

.equ	BLOCKDEV_RAMSTART	ACIA_RAMEND
.equ	BLOCKDEV_COUNT		1
.inc "blockdev.asm"
; List of devices
.dw	mmapGetC, mmapPutC

.equ	STDIO_RAMSTART	BLOCKDEV_RAMEND
.inc "stdio.asm"

.equ	AT28W_RAMSTART	STDIO_RAMEND
.inc "at28w/main.asm"

.equ	SHELL_RAMSTART	AT28W_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT 5
.inc "shell.asm"
; Extra cmds
.dw	a28wCmd
.dw	blkBselCmd, blkSeekCmd, blkLoadCmd, blkSaveCmd

.inc "blockdev_cmds.asm"

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

	xor	a
	ld	de, BLOCKDEV_SEL
	call	blkSel

	ei
	jp	shellLoop

a28wCmd:
	.db	"a28w", 0b011, 0b001, 0
	ld	a, (hl)
	ld	(AT28W_MAXBYTES), a
	inc	hl
	ld	a, (hl)
	ld	(AT28W_MAXBYTES+1), a
	jp	at28wInner


