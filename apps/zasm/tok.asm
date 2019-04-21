; tok
;
; Tokenizes an ASM source file into 1, 2 or 3-sized structures.
;
; *** Requirements ***
; JUMP_UPCASE

; *** Code ***
; Parse line in (HL) and place each element in tokInstr, tokArg1, tokArg2. Those
; values are null-terminated and empty if not present.
; Sets Z on success, unsets it on error. Blank line is not an error.
; (as of now, we don't have any error condition. We always succeed)
tokenize:
	push	de
	xor	a
	ld	(tokInstr), a
	ld	(tokArg1), a
	ld	(tokArg2), a
	ld	de, tokInstr
	ld	a, 4
	call	readWord
	call	toWord
	jr	nz, .end
	ld	de, tokArg1
	ld	a, 8
	call	readWord
	call	toWord
	jr	nz, .end
	ld	de, tokArg2
	call	readWord
.end:
	cp	a		; ensure Z
	pop	de
	ret

; Sets Z is A is ';', CR, LF, or null.
isLineEnd:
	cp	';'
	ret	z
	cp	0
	ret	z
	cp	0x0d
	ret	z
	cp	0x0a
	ret

; Sets Z is A is ' ' or ','
isSep:
	cp	' '
	ret	z
	cp	','
	ret

; Sets Z is A is ' ', ',', ';', CR, LF, or null.
isSepOrLineEnd:
	call	isSep
	ret	z
	call	isLineEnd
	ret

; read word in (HL) and put it in (DE), null terminated, for a maximum of A
; characters. As a result, A is the read length. HL is advanced to the next
; separator char.
readWord:
	push	bc
	ld	b, a
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
	ld	a, 4
	sub	a, b
	jr	.end
.error:
	xor	a
	ld	(de), a
.end:
	pop	bc
	ret

; (HL) being a string, advance it to the next non-sep character.
; Set Z if we could do it before the line ended, reset Z if we couldn't.
toWord:
.loop:
	ld	a, (hl)
	call	isLineEnd
	jr	z, .error
	call	isSep
	jr	nz, .success
	inc	hl
	jr	.loop
.error:
	; we need the Z flag to be unset and it is set now. Let's CP with
	; something it can't be equal to, something not a line end.
	cp	'a'	; Z flag unset
	ret
.success:
	; We need the Z flag to be set and it is unset. Let's compare it with
	; itself to return a set Z
	cp	a
	ret

; *** Variables ***

tokInstr:
	.fill	5
tokArg1:
	.fill	9
tokArg2:
	.fill	9

