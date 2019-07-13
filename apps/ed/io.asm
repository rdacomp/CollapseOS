; io - handle ed's I/O

; *** Consts ***
;
; Max length of a line
.equ	IO_MAXLEN	0x7f

; *** Variables ***
; Buffer for lines read from I/O.
.equ	IO_LINE		IO_RAMSTART
.equ	IO_RAMEND	IO_LINE+IO_MAXLEN+1	; +1 for null
; *** Code ***

; Given an offset HL, read the line in IO_LINE, without LF and null terminates
; it. Make HL point to IO_LINE.
ioGetLine:
	push	af
	push	de
	push	bc
	ld	de, 0		; limit ourselves to 16-bit for now
	xor	a		; absolute seek
	call	blkSeek
	ld	hl, IO_LINE
	ld	b, IO_MAXLEN
.loop:
	call	blkGetC
	jr	nz, .loopend
	or	a		; null? hum, weird. same as LF
	jr	z, .loopend
	cp	0x0a
	jr	z, .loopend
	ld	(hl), a
	inc	hl
	djnz	.loop
.loopend:
	; null-terminate the string
	xor	a
	ld	(hl), a
	ld	hl, IO_LINE
	pop	bc
	pop	de
	pop	af
	ret
