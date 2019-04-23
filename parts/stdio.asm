; stdio
;
; Allows other modules to print to "standard out", that is, the console through
; which the user is connected in a decoupled manner.
;
; *** REQUIREMENTS ***
; STDIO_GETC: a macro that follows GetC API
; STDIO_PUTC: a macro that follows GetC API

; *** VARIABLES ***
; Used to store formatted hex values just before printing it.
STDIO_HEX_FMT	.equ	STDIO_RAMSTART
STDIO_RAMEND	.equ	STDIO_HEX_FMT+2

; print null-terminated string pointed to by HL
printstr:
	push	af
	push	hl

.loop:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	jr	z, .end		; if yes, we're finished
	STDIO_PUTC
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
	STDIO_PUTC
	inc	hl
	djnz	.loop

.end:
	pop	hl
	pop	bc
	ret

printcrlf:
	ld	a, ASCII_CR
	STDIO_PUTC
	ld	a, ASCII_LF
	STDIO_PUTC
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

