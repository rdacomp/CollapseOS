; tok
;
; Tokenizes an ASM source file into 1, 2 or 3-sized structures.
;
; *** Requirements ***
; JUMP_UPCASE

; *** Code ***
; Parse line in (HL) and place each element in tokInstr, tokArg1, tokArg2. Those
; values are null-terminated and empty if not present. All letters are
; uppercased.
; Sets Z on success, unsets it on error. Blank line is not an error.
; (as of now, we don't have any error condition. We always succeed)
tokenize:
	push	de
	xor	a
	ld	(tokInstr), a
	ld	(tokArg1), a
	ld	(tokArg2), a
	ld	de, tokInstr
	call	toWord
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
	xor	a		; ensure Z
	pop	de
	ret

; Sets Z is A is ';', CR, LF, or null.
isLineEndOrComment:
	cp	';'
	ret	z
	; Continues onto isLineEnd...

; Sets Z is A is CR, LF, or null.
isLineEnd:
	or	a	; same as cp 0
	ret	z
	cp	0x0d
	ret	z
	cp	0x0a
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

; Advance HL to the beginning of the next line, that is, right after the next
; 0x10 or 0x13 or both. If we reach null, we stop and error out.
; Sets Z on success, unsets it on error.
gotoNextLine:
	dec	hl	; a bit weird, but makes the looping easier
.loop:
	inc	hl
	ld	a, (hl)
	call	isLineEnd
	jr	nz, .loop
	; (HL) is 0x10, 0x13 or 0
	or	a	; is 0?
	jr	z, .error
	; we might have 0x13 followed by 0x10, let's account for this.
	; Yes, 0x10 followed by 0x10 will make us skip two lines, but this is of
	; no real consequence in our context.
	inc	hl
	ld	a, (hl)
	call	isLineEnd
	jr	nz, .success
	or	a	; is 0?
	jr	z, .error
	; There was another line sep. Skip this char
	inc	hl
	; Continue on to .success
.success:
	xor	a	; ensure Z
	ret
.error:
	call	JUMP_UNSETZ
	ret

; Repeatedly calls gotoNextLine until the line in (HL) points to a line that
; isn't blank or 100% comment. Sets Z if we reach a line, Unset Z if we reach
; EOF
gotoNextNotBlankLine:
	call	toWord
	ret	z	; Z set? we have a not-blank line
	; Z not set? (HL) is at the end of the line or at the beginning of
	; comments.
	call	gotoNextLine
	ret	nz
	jr	gotoNextNotBlankLine

; *** Variables ***

tokInstr:
	.fill	5
tokArg1:
	.fill	9
tokArg2:
	.fill	9

