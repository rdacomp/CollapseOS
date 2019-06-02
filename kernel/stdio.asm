; stdio
;
; Allows other modules to print to "standard out", and get data from "stamdard
; in", that is, the console through which the user is connected in a decoupled
; manner.
;
; *** VARIABLES ***
; Used to store formatted hex values just before printing it.
.equ	STDIO_HEX_FMT	STDIO_RAMSTART
.equ	STDIO_GETC	STDIO_HEX_FMT+2
.equ	STDIO_PUTC	STDIO_GETC+2
.equ	STDIO_RAMEND	STDIO_PUTC+2

; Sets GetC to the routine where HL points to and PutC to DE.
stdioInit:
	ld	(STDIO_GETC), hl
	ld	(STDIO_PUTC), de
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
