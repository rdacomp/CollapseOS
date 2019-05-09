; *** Consts ***
.equ	IO_MAX_LINELEN	0xff
; *** Variables ***
ioGetCPtr:
	.fill 2
ioPutCPtr:
	.fill 2
ioLineBuf:
	.fill IO_MAX_LINELEN+1

; *** Code ***

ioGetC:
	ld	ix, (ioGetCPtr)
	jp	(ix)

ioPutC:
	ld	ix, (ioPutCPtr)
	jp	(ix)

; Sets Z is A is CR, LF, or null.
isLineEnd:
	or	a	; same as cp 0
	ret	z
	cp	0x0d
	ret	z
	cp	0x0a
	ret

; Read a single line from ioGetCPtr and place it in ioLineBuf.
; Returns number of chars read in A. 0 means we're at the end of our input
; stream, which happens when GetC unsets Z. Make HL point to ioLineBuf.
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
	ld	(ioLineBuf), a
	ld	hl, ioLineBuf+1
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
	ld	hl, ioLineBuf
	jr	.end
.eof:
	xor	a
.end:
	pop	bc
	ret

