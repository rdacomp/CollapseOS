; named shell_.asm to avoid infinite include loop.
.equ	RAMSTART	0x4000
; kernel ram is well under 0x100 bytes. We're giving us 0x200 bytes so that we
; never worry about the stack.
.equ	KERNEL_RAMEND	0x4200
.equ	USERCODE	KERNEL_RAMEND
.equ	STDIO_PORT	0x00
.equ	FS_DATA_PORT	0x01
.equ	FS_SEEKL_PORT	0x02
.equ	FS_SEEKH_PORT	0x03
.equ	FS_SEEKE_PORT	0x04

	jp	init

; *** JUMP TABLE ***
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
	jp	fsTell
	jp	cpHLDE
	jp	parseArgs
	jp	printstr

#include "core.asm"
#include "err.h"
#include "parse.asm"

.equ	BLOCKDEV_RAMSTART	RAMSTART
.equ	BLOCKDEV_COUNT		4
#include "blockdev.asm"
; List of devices
.dw	fsdevGetC, fsdevPutC, fsdevSeek, fsdevTell
.dw	stdoutGetC, stdoutPutC, stdoutSeek, stdoutTell
.dw	stdinGetC, stdinPutC, stdinSeek, stdinTell
.dw	mmapGetC, mmapPutC, mmapSeek, mmapTell

#include "blockdev_cmds.asm"

.equ	MMAP_RAMSTART	BLOCKDEV_RAMEND
.equ	MMAP_START	0xe000
#include "mmap.asm"

.equ	STDIO_RAMSTART	MMAP_RAMEND
#include "stdio.asm"

.equ	FS_RAMSTART	STDIO_RAMEND
.equ	FS_HANDLE_COUNT	2
#include "fs.asm"
#include "fs_cmds.asm"

.equ	SHELL_RAMSTART		FS_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT	9
#include "shell.asm"
.dw	blkBselCmd, blkSeekCmd, blkLoadCmd, blkSaveCmd
.dw	fsOnCmd, flsCmd, fnewCmd, fdelCmd, fopnCmd

.equ	PGM_RAMSTART		SHELL_RAMEND
.equ	PGM_CODEADDR		USERCODE
#include "pgm.asm"

.out	PGM_RAMEND

init:
	di
	; setup stack
	ld	hl, KERNEL_RAMEND
	ld	sp, hl
	ld	hl, emulGetC
	ld	de, emulPutC
	call	stdioInit
	call	mmapInit
	call	fsInit
	ld	a, 0	; select fsdev
	ld	de, BLOCKDEV_GETC
	call	blkSel
	call	fsOn
	call	shellInit
	ld	hl, pgmShellHook
	ld	(SHELL_CMDHOOK), hl
	jp	shellLoop

emulGetC:
	; Blocks until a char is returned
	in	a, (STDIO_PORT)
	cp	a		; ensure Z
	ret

emulPutC:
	out	(STDIO_PORT), a
	ret

fsdevGetC:
	in	a, (FS_DATA_PORT)
	cp	a		; ensure Z
	ret

fsdevPutC:
	out	(FS_DATA_PORT), a
	ret

fsdevSeek:
	push	af
	ld	a, l
	out	(FS_SEEKL_PORT), a
	ld	a, h
	out	(FS_SEEKH_PORT), a
	ld	a, e
	out	(FS_SEEKE_PORT), a
	pop	af
	ret

fsdevTell:
	push	af
	in	a, (FS_SEEKL_PORT)
	ld	l, a
	in	a, (FS_SEEKH_PORT)
	ld	h, a
	in	a, (FS_SEEKE_PORT)
	ld	e, a
	pop	af
	ret

.equ	STDOUT_HANDLE	FS_HANDLES

stdoutGetC:
	ld	ix, STDOUT_HANDLE
	jp	fsGetC

stdoutPutC:
	ld	ix, STDOUT_HANDLE
	jp	fsPutC

stdoutSeek:
	ld	ix, STDOUT_HANDLE
	jp	fsSeek

stdoutTell:
	ld	ix, STDOUT_HANDLE
	jp	fsTell

.equ	STDIN_HANDLE	FS_HANDLES+FS_HANDLE_SIZE

stdinGetC:
	ld	ix, STDIN_HANDLE
	jp	fsGetC

stdinPutC:
	ld	ix, STDIN_HANDLE
	jp	fsPutC

stdinSeek:
	ld	ix, STDIN_HANDLE
	jp	fsSeek

stdinTell:
	ld	ix, STDIN_HANDLE
	jp	fsTell

