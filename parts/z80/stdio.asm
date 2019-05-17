; stdio
;
; Allows other modules to print to "standard out", that is, the console through
; which the user is connected in a decoupled manner.
;
; *** REQUIREMENTS ***
; blkdev. select the block device you want to use as stdio just before you call
; stdioInit.

; *** VARIABLES ***
; Used to store formatted hex values just before printing it.
STDIO_HEX_FMT	.equ	STDIO_RAMSTART
STDIO_GETC	.equ	STDIO_HEX_FMT+2
STDIO_PUTC	.equ	STDIO_GETC+2
STDIO_RAMEND	.equ	STDIO_PUTC+2

; Select the blockdev to use as stdio before calling this.
stdioInit:
	push	hl
	ld	hl, (BLOCKDEV_GETC)
	ld	(STDIO_GETC), hl
	ld	hl, (BLOCKDEV_PUTC)
	ld	(STDIO_PUTC), hl
	pop	hl
	ret

stdioGetC:
	ld	ix, (STDIO_GETC)
	jp	(ix)

stdioPutC:
	ld	ix, (STDIO_PUTC)
	jp	(ix)

; print null-terminated string pointed to by HL
printstr:
	push	af
	push	hl

.loop:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	jr	z, .end		; if yes, we're finished
	call	stdioPutC
	inc	hl
	jr	.loop

.end:
	pop	hl
	pop	af
	ret

; print A characters from string that HL points to
printnstr:
	push	bc
	push	hl

	ld	b, a
.loop:
	ld	a, (hl)		; load character to send
	call	stdioPutC
	inc	hl
	djnz	.loop

.end:
	pop	hl
	pop	bc
	ret

printcrlf:
	ld	a, ASCII_CR
	call	stdioPutC
	ld	a, ASCII_LF
	call	stdioPutC
	ret

; Print the hex char in A
printHex:
	push	af
	push	hl
	ld	hl, STDIO_HEX_FMT
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	pop	hl
	pop	af
	ret

; Print the hex pair in HL
printHexPair:
	push	af
	ld	a, h
	call	printHex
	ld	a, l
	call	printHex
	pop	af
	ret
