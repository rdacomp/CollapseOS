; *** Requirements ***
; JUMP_UPCASE

; *** Consts ***
TOK_INSTR	.equ	0x01
TOK_DIRECTIVE	.equ	0x02
TOK_EMPTY	.equ	0xfe	; not a bad token, just an empty line
TOK_BAD		.equ	0xff

; *** Code ***
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
.end:
	ld	c, a
	pop	hl
	ret
.emptyline:
	ld	b, TOK_EMPTY
	; no HL to pop, we jumped before the push
	ret
