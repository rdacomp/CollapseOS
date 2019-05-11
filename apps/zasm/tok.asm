; *** Consts ***
TOK_INSTR	.equ	0x01
TOK_DIRECTIVE	.equ	0x02
TOK_LABEL	.equ	0x03
TOK_EMPTY	.equ	0xfe	; not a bad token, just an empty line
TOK_BAD		.equ	0xff

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

; Checks whether string at (HL) is a label, that is, whether it ends with a ":"
; Sets Z if yes, unset if no.
;
; If it's a label, we change the trailing ':' char with a null char. It's a bit
; dirty, but it's the easiest way to proceed.
isLabel:
	push	hl
	ld	a, ':'
	call	JUMP_FINDCHAR
	ld	a, (hl)
	cp	':'
	jr	nz, .nomatch
	; We also have to check that it's our last char.
	inc	hl
	ld	a, (hl)
	or	a		; cp 0
	jr	nz, .nomatch	; not a null char following the :. no match.
	; We have a match!
	; Remove trailing ':'
	xor	a		; Z is set
	ld	(hl), a
	jr	.end
.nomatch:
	call	JUMP_UNSETZ
.end:
	pop	hl
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

; Parse line in (HL) and read the next token in BC. The token is written on
; two bytes (B and C). B is a token type (TOK_* constants) and C is an ID
; specific to that token type.
; Advance HL to after the read word.
; If no token matches, TOK_BAD is written to B
tokenize:
	call	toWord
	jr	nz, .emptyline
	call	readWord
	push	hl		; Save advanced HL for later
	ld	hl, scratchpad
	call	isLabel
	jr	z, .label
	call	getInstID
	jr	z, .instr
	call	getDirectiveID
	jr	z, .direc
	; no match
	ld	b, TOK_BAD
	jr	.end
.instr:
	ld	b, TOK_INSTR
	jr	.end
.direc:
	ld	b, TOK_DIRECTIVE
	jr	.end
.label:
	ld	b, TOK_LABEL
.end:
	ld	c, a
	pop	hl
	ret
.emptyline:
	ld	b, TOK_EMPTY
	; no HL to pop, we jumped before the push
	ret
