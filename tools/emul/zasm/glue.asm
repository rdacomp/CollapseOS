; Glue code for the emulated environment
.equ RAMSTART		0x4000
.equ STDIO_PORT		0x00
.equ STDIN_SEEK		0x01
.equ FS_DATA_PORT	0x02
.equ FS_SEEK_PORT	0x03
.equ STDERR_PORT	0x04

jp     init    ; 3 bytes
; *** JUMP TABLE ***
jp     strncmp
jp     addDE
jp     addHL
jp     upcase
jp     unsetZ
jp     intoDE
jp     intoHL
jp     writeHLinDE
jp     findchar
jp     parseHex
jp     parseHexPair
jp     blkSel
jp     fsFindFN
jp     fsOpen
jp     fsGetC
jp     fsSeek
jp     fsTell

#include "core.asm"
#include "parse.asm"
.equ	BLOCKDEV_RAMSTART	RAMSTART
.equ	BLOCKDEV_COUNT		3
#include "blockdev.asm"
; List of devices
.dw	emulGetC, 0, emulSeek, emulTell
.dw	0, emulPutC, 0, 0
.dw	fsdevGetC, fsdevPutC, fsdevSeek, fsdevTell

.equ	FS_RAMSTART	BLOCKDEV_RAMEND
.equ	FS_HANDLE_COUNT	0
#include "fs.asm"
#include "user.h"

init:
	di
	ld	hl, 0xffff
	ld	sp, hl
	ld	a, 2	; select fsdev
	ld	de, BLOCKDEV_GETC
	call	blkSel
	call	fsOn
	ld	h, 0	; input blkdev
	ld	l, 1	; output blkdev
	call	USER_CODE
	; signal the emulator we're done
	halt

; *** I/O ***
emulGetC:
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
	ret

emulSeek:
	; the STDIN_SEEK port works by poking it twice. First poke is for high
	; byte, second poke is for low one.
	ld	a, h
	out	(STDIN_SEEK), a
	ld	a, l
	out	(STDIN_SEEK), a
	ret

emulTell:
	; same principle as STDIN_SEEK
	in	a, (STDIN_SEEK)
	ld	h, a
	in	a, (STDIN_SEEK)
	ld	l, a
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
	ld	a, h
	out	(FS_SEEK_PORT), a
	ld	a, l
	out	(FS_SEEK_PORT), a
	pop	af
	ret

fsdevTell:
	push	af
	in	a, (FS_SEEK_PORT)
	ld	h, a
	in	a, (FS_SEEK_PORT)
	ld	l, a
	pop	af
	ret

