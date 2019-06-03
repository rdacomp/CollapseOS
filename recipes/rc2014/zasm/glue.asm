; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module
; The RAM module is selected on A15, so it has the range 0x8000-0xffff
.equ	RAMSTART	0x8000
; kernel RAM usage is under 0x300 bytes. We give ourselves at least 0x300 bytes
; for the stack.
.equ	RAMEND		0x8600
.equ	PGM_CODEADDR	RAMEND
.equ	ACIA_CTL	0x80	; Control and status. RS off.
.equ	ACIA_IO		0x81	; Transmit. RS on.

	jp	init	; 3 bytes

; *** Jump Table ***
	jp	strncmp
	jp	addDE
	jp	addHL
	jp	upcase
	jp	unsetZ
	jp	intoDE
	jp	intoHL
	jp	writeHLinDE
	jp	findchar
	jp	parseHex
	jp	parseHexPair
	jp	blkSel
	jp	fsFindFN
	jp	fsOpen
	jp	fsGetC
	jp	fsSeek
	jp	fsTell		; approaching 0x38...

; interrupt hook
.fill	0x38-$
jp	aciaInt

; *** Jump Table (cont.) ***
	jp	cpHLDE
	jp	parseArgs
	jp	printstr

#include "err.h"
#include "core.asm"
#include "parse.asm"
.equ	ACIA_RAMSTART	RAMSTART
#include "acia.asm"
.equ	BLOCKDEV_RAMSTART	ACIA_RAMEND
.equ	BLOCKDEV_COUNT		3
#include "blockdev.asm"
; List of devices
.dw	sdcGetC, sdcPutC, sdcSeek, sdcTell
.dw	mmapGetC, mmapPutC, mmapSeek, mmapTell
.dw	blk2GetC, blk2PutC, blk2Seek, blk2Tell

#include "blockdev_cmds.asm"

.equ	MMAP_RAMSTART	BLOCKDEV_RAMEND
.equ	MMAP_START	0xe000
#include "mmap.asm"

.equ	STDIO_RAMSTART	MMAP_RAMEND
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

.equ	PGM_RAMSTART	SHELL_RAMEND
#include "pgm.asm"

.equ	SDC_RAMSTART	PGM_RAMEND
.equ	SDC_PORT_CSHIGH	6
.equ	SDC_PORT_CSLOW	5
.equ	SDC_PORT_SPI	4
#include "sdc.asm"

.out	SDC_RAMEND

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
	call	mmapInit
	call	shellInit
	ld	hl, pgmShellHook
	ld	(SHELL_CMDHOOK), hl

	xor	a
	ld	de, BLOCKDEV_GETC
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
