; *** Consts ***
.equ	IO_MAX_LINELEN	0xff
; *** Variables ***
.equ	IO_IN_GETC	IO_RAMSTART
.equ	IO_IN_PUTC	IO_IN_GETC+2
.equ	IO_IN_SEEK	IO_IN_PUTC+2
.equ	IO_IN_TELL	IO_IN_SEEK+2
.equ	IO_OUT_GETC	IO_IN_TELL+2
.equ	IO_OUT_PUTC	IO_OUT_GETC+2
.equ	IO_OUT_SEEK	IO_OUT_PUTC+2
.equ	IO_OUT_TELL	IO_OUT_SEEK+2
.equ	IO_LINEBUF	IO_OUT_TELL+2
.equ	IO_RAMEND	IO_LINEBUF+IO_MAX_LINELEN+1

; *** Code ***

ioGetC:
	ld	ix, (IO_IN_GETC)
	jp	(ix)

ioPutC:
	ld	ix, (IO_OUT_PUTC)
	jp	(ix)

ioRewind:
	ld	hl, 0
	ld	ix, (IO_IN_SEEK)
	jp	(ix)

; Sets Z is A is CR, LF, or null.
isLineEnd:
	or	a	; same as cp 0
	ret	z
	cp	0x0d
	ret	z
	cp	0x0a
	ret

; Read a single line from ioGetCPtr and place it in IO_LINEBUF.
; Returns number of chars read in A. 0 means we're at the end of our input
; stream, which happens when GetC unsets Z. Make HL point to IO_LINEBUF.
; We ignore empty lines and pass through them like butter.
; A null char is written at the end of the line.
ioReadLine:
	push	bc
	; consume ioGetC as long as it yields a line end char.
.loop1:
	call	ioGetC
	jr	nz, .eof	; GetC unsets Z? We don't have a line to read,
				; we have EOF.
	call	isLineEnd
	jr	z, .loop1
	; A contains the first char of our line.
	ld	c, 1
	ld	(IO_LINEBUF), a
	ld	hl, IO_LINEBUF+1
.loop2:
	call	ioGetC
	call	isLineEnd
	jr	z, .success	; We have end of line
	ld	(hl), a
	inc	hl
	inc	c
	jr	.loop2

.success:
	; write null char at HL before we return
	xor	a
	ld	(hl), a
	ld	a, c
	ld	hl, IO_LINEBUF
	jr	.end
.eof:
	xor	a
.end:
	pop	bc
	ret

