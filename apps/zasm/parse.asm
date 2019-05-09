; *** Consts ***
.equ	SCRATCHPAD_SIZE	0x20
; *** Variables ***
scratchpad:
	.fill	SCRATCHPAD_SIZE

; *** Code ***

; Sets Z is A is ';' or null.
isLineEndOrComment:
	cp	';'
	ret	z
	or	a	; cp 0
	ret

; Sets Z is A is ' ' '\t' or ','
isSep:
	cp	' '
	ret	z
	cp	0x09
	ret	z
	cp	','
	ret

; Sets Z is A is ' ', ',', ';', CR, LF, or null.
isSepOrLineEnd:
	call	isSep
	ret	z
	call	isLineEndOrComment
	ret

; read word in (HL) and put it in (scratchpad), null terminated, for a maximum
; of SCRATCHPAD_SIZE-1 characters. As a result, A is the read length. HL is
; advanced to the next separator char.
readWord:
	push	bc
	push	de
	ld	de, scratchpad
	ld	b, SCRATCHPAD_SIZE-1
.loop:
	ld	a, (hl)
	call	isSepOrLineEnd
	jr	z, .success
	call	JUMP_UPCASE
	ld	(de), a
	inc	hl
	inc	de
	djnz	.loop
.success:
	xor	a
	ld	(de), a
	ld	a, SCRATCHPAD_SIZE-1
	sub	a, b
.end:
	pop	de
	pop	bc
	ret

; (HL) being a string, advance it to the next non-sep character.
; Set Z if we could do it before the line ended, reset Z if we couldn't.
toWord:
.loop:
	ld	a, (hl)
	call	isLineEndOrComment
	jr	z, .error
	call	isSep
	jr	nz, .success
	inc	hl
	jr	.loop
.error:
	call	JUMP_UNSETZ
	ret
.success:
	xor	a	; ensure Z
	ret
