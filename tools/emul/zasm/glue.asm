; Glue code for the emulated environment
.equ RAMSTART		0x4000
.equ USER_CODE		0x4800
.equ STDIO_PORT		0x00
.equ STDIN_SEEK		0x01
.equ FS_DATA_PORT	0x02
.equ FS_SEEK_PORT	0x03
.equ STDERR_PORT	0x04

jp     init    ; 3 bytes
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
jp	blkSet
jp	fsFindFN
jp	fsOpen
jp	fsGetC
jp	cpHLDE
jp	parseArgs
jp	_blkGetC
jp	_blkPutC
jp	_blkSeek
jp	_blkTell

#include "core.asm"
#include "err.h"
#include "parse.asm"
.equ	BLOCKDEV_RAMSTART	RAMSTART
.equ	BLOCKDEV_COUNT		3
#include "blockdev.asm"
; List of devices
.dw	emulGetC, unsetZ
.dw	unsetZ, emulPutC
.dw	fsdevGetC, fsdevPutC

.equ	FS_RAMSTART	BLOCKDEV_RAMEND
.equ	FS_HANDLE_COUNT	0
#include "fs.asm"

init:
	di
	ld	hl, 0xffff
	ld	sp, hl
	ld	a, 2	; select fsdev
	ld	de, BLOCKDEV_SEL
	call	blkSel
	call	fsOn
	ld	hl, .zasmArgs
	call	USER_CODE
	; signal the emulator we're done
	halt

.zasmArgs:
	.db	"0 1", 0

; *** I/O ***
emulGetC:
	; the STDIN_SEEK port works by poking it twice. First poke is for high
	; byte, second poke is for low one.
	ld	a, h
	out	(STDIN_SEEK), a
	ld	a, l
	out	(STDIN_SEEK), a
	in	a, (STDIO_PORT)
	or	a		; cp 0
	jr	z, .eof
	cp	a		; ensure z
	ret
.eof:
	call	unsetZ
	ret

emulPutC:
	out	(STDIO_PORT), a
	cp	a		; ensure Z
	ret

fsdevGetC:
	ld	a, e
	out	(FS_SEEK_PORT), a
	ld	a, h
	out	(FS_SEEK_PORT), a
	ld	a, l
	out	(FS_SEEK_PORT), a
	in	a, (FS_SEEK_PORT)
	or	a
	ret	nz
	in	a, (FS_DATA_PORT)
	cp	a		; ensure Z
	ret

fsdevPutC:
	push	af
	ld	a, e
	out	(FS_SEEK_PORT), a
	ld	a, h
	out	(FS_SEEK_PORT), a
	ld	a, l
	out	(FS_SEEK_PORT), a
	in	a, (FS_SEEK_PORT)
	or	a
	jr	nz, .error
	pop	af
	out	(FS_DATA_PORT), a
	cp	a		; ensure Z
	ret
.error:
	pop	af
	jp	unsetZ		; returns

