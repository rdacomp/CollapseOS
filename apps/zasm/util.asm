; run RLA the number of times specified in B
rlaX:
	; first, see if B == 0 to see if we need to bail out
	inc	b
	dec	b
	ret	z	; Z flag means we had B = 0
.loop:	rla
	djnz	.loop
	ret

callHL:
	jp	(hl)
	ret

; If string at (HL) starts with ( and ends with ), "enter" into the parens
; (advance HL and put a null char at the end of the string) and set Z.
; Otherwise, do nothing and reset Z.
enterParens:
	ld	a, (hl)
	cp	'('
	ret	nz		; nothing to do
	push	hl
	ld	a, 0	; look for null char
	; advance until we get null
.loop:
	cpi
	jp	z, .found
	jr	.loop
.found:
	dec	hl	; cpi over-advances. go back to null-char
	dec	hl	; looking at the last char before null
	ld	a, (hl)
	cp	')'
	jr	nz, .doNotEnter
	; We have parens. While we're here, let's put a null
	xor	a
	ld	(hl), a
	pop	hl	; back at the beginning. Let's advance.
	inc	hl
	cp	a	; ensure Z
	ret		; we're good!
.doNotEnter:
	pop	hl
	call	JUMP_UNSETZ
	ret

; Find string (HL) in string list (DE) of size B. Each string is C bytes wide.
; Returns the index of the found string. Sets Z if found, unsets Z if not found.
findStringInList:
	push	de
	push	bc
.loop:
	ld	a, c
	call	JUMP_STRNCMP
	ld	a, c
	call	JUMP_ADDDE
	jr	z, .match
	djnz	.loop
	; no match, Z is unset
	pop	bc
	pop	de
	ret
.match:
	; Now, we want the index of our string, which is equal to our initial B
	; minus our current B. To get this, we have to play with our registers
	; and stack a bit.
	ld	d, b
	pop	bc
	ld	a, b
	sub	d
	pop	de
	cp	a		; ensure Z
	ret
