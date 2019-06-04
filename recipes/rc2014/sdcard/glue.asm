; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
.equ	RAMSTART	0x8000
.equ	RAMEND		0xffff
.equ	PGM_CODEADDR	0x9000
.equ	ACIA_CTL	0x80	; Control and status. RS off.
.equ	ACIA_IO		0x81	; Transmit. RS on.

jp	init	; 3 bytes

; *** Jump Table ***
jp	printstr
jp	sdcWaitResp
jp	sdcCmd
jp	sdcCmdR1
jp	sdcCmdR7
jp	sdcSendRecv

; interrupt hook
.fill	0x38-$
jp	aciaInt

#include "err.h"
#include "core.asm"
#include "parse.asm"
.equ	ACIA_RAMSTART	RAMSTART
#include "acia.asm"
.equ	BLOCKDEV_RAMSTART	ACIA_RAMEND
.equ	BLOCKDEV_COUNT		2
#include "blockdev.asm"
; List of devices
.dw	sdcGetC, sdcPutC, sdcSeek, sdcTell
.dw	blk2GetC, blk2PutC, blk2Seek, blk2Tell

#include "blockdev_cmds.asm"

.equ	STDIO_RAMSTART	BLOCKDEV_RAMEND
#include "stdio.asm"

.equ	FS_RAMSTART	STDIO_RAMEND
.equ	FS_HANDLE_COUNT	1
#include "fs.asm"
#include "fs_cmds.asm"

.equ	SHELL_RAMSTART		FS_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT	11
#include "shell.asm"
.dw	sdcInitializeCmd, sdcFlushCmd
.dw	blkBselCmd, blkSeekCmd, blkLoadCmd, blkSaveCmd
.dw	fsOnCmd, flsCmd, fnewCmd, fdelCmd, fopnCmd

#include "pgm.asm"

.equ	SDC_RAMSTART	SHELL_RAMEND
.equ	SDC_PORT_CSHIGH	6
.equ	SDC_PORT_CSLOW	5
.equ	SDC_PORT_SPI	4
#include "sdc.asm"

init:
	di
	; setup stack
	ld	hl, RAMEND
	ld	sp, hl
	im	1
	call	aciaInit
	ld	hl, aciaGetC
	ld	de, aciaPutC
	call	stdioInit
	call	shellInit
	ld	hl, pgmShellHook
	ld	(SHELL_CMDHOOK), hl

	xor	a
	ld	de, BLOCKDEV_SEL
	call	blkSel

	ei
	jp	shellLoop

; *** blkdev 2: file handle 0 ***

blk2GetC:
	ld	ix, FS_HANDLES
	jp	fsGetC

blk2PutC:
	ld	ix, FS_HANDLES
	jp	fsPutC

blk2Seek:
	ld	ix, FS_HANDLES
	jp	fsSeek

blk2Tell:
	ld	ix, FS_HANDLES
	jp	fsTell
