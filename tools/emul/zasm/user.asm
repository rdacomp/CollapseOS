; *** JUMP TABLE ***
strncmp		.equ    0x03
addDE		.equ    0x06
addHL		.equ    0x09
upcase		.equ    0x0c
unsetZ		.equ    0x0f
intoDE		.equ    0x12
intoHL		.equ    0x15
findchar	.equ    0x18
parseHexPair	.equ  0x1b
blkSel		.equ    0x1e
fsFindFN	.equ    0x21
fsOpen		.equ    0x24
fsGetC		.equ    0x27
fsSeek		.equ    0x2a
fsTell		.equ    0x2d

.equ	FS_HANDLE_SIZE	8
.equ	STDERR_PORT	0x04
.equ	USER_CODE	0x4800
.equ	RAMSTART	0x5800
.org	USER_CODE

	call	zasmMain
	;call	dumpSymTable
	ret

#include "main.asm"

; *** Debug ***
debugPrint:
	push	af
	push	hl
.loop:
	ld	a, (hl)
	or	a
	jr	z, .end
	out	(STDERR_PORT), a
	inc	hl
	jr	.loop
.end:
	ld	a, 0x0a
	out	(STDERR_PORT), a
	pop	hl
	pop	af
	ret

dumpSymTable:
	ld	hl, SYM_NAMES
	ld	de, SYM_VALUES
.loop:
	call	debugPrint
	ld	a, (de)
	out	(12), a
	inc	de
	ld	a, (de)
	out	(12), a
	inc	de
	xor	a
	call	findchar
	inc	hl
	ld	a, (hl)
	or	a
	ret	z
	jr	.loop

