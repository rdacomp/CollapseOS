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

; Compare HL with DE and sets Z and C in the same way as a regular cp X where
; HL is A and DE is X.
cpHLDE:
	ld	a, h
	cp	d
	ret	nz	; if not equal, flags are correct
	ld	a, l
	cp	e
	ret		; flags are correct

; HL - DE -> HL
subDEFromHL:
	push	af
	ld	a, l
	sub	e
	ld	l, a
	ld	a, h
	sbc	d
	ld	h, a
	pop	af
	ret

; Returns length of string at (HL) in A.
strlen:
	push	bc
	push	hl
	ld	bc, 0
	ld	a, 0	; look for null char
.loop:
	cpi
	jp	z, .found
	jr	.loop
.found:
	; How many char do we have? the (NEG BC)-1, which started at 0 and
	; decreased at each CPI call. In this routine, we stay in the 8-bit
	; realm, so C only.
	ld	a, c
	neg
	dec	a
	pop	hl
	pop	bc
	ret

; Compares strings pointed to by HL and DE up to A count of characters in a
; case-insensitive manner.
; If equal, Z is set. If not equal, Z is reset.
strncmpI:
	push	bc
	push	hl
	push	de

	ld	b, a
.loop:
	ld	a, (de)
	call	upcase
	ld	c, a
	ld	a, (hl)
	call	upcase
	cp	c
	jr	nz, .end	; not equal? break early. NZ is carried out
				; to the called
	or	a		; cp 0. If our chars are null, stop the cmp
	jr	z, .end		; The positive result will be carried to the
	                        ; caller
	inc	hl
	inc	de
	djnz	.loop
	; Success
	; We went through all chars with success. Ensure Z
	cp	a
.end:
	pop	de
	pop	hl
	pop	bc
	; Because we don't call anything else than CP that modify the Z flag,
	; our Z value will be that of the last cp (reset if we broke the loop
	; early, set otherwise)
	ret

; Compares strings pointed to by HL and DE until one of them hits its null char.
; If equal, Z is set. If not equal, Z is reset.
strcmp:
	push	hl
	push	de

.loop:
	ld	a, (de)
	cp	(hl)
	jr	nz, .end	; not equal? break early. NZ is carried out
				; to the called
	cp	0		; If our chars are null, stop the cmp
	jr	z, .end		; The positive result will be carried to the
	                        ; caller
	inc	hl
	inc	de
	jr	.loop

.end:
	pop	de
	pop	hl
	; Because we don't call anything else than CP that modify the Z flag,
	; our Z value will be that of the last cp (reset if we broke the loop
	; early, set otherwise)
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
	call	unsetZ
	ret

; Scans (HL) and sets Z according to whether the string is double quoted, that
; is, starts with a " and ends with a ". If it is double quoted, "enter" them,
; that is, advance HL by one and transform the ending quote into a null char.
; If the string isn't double-enquoted, HL isn't changed.
enterDoubleQuotes:
	ld	a, (hl)
	cp	'"'
	ret	nz
	push	hl
	inc	hl
	ld	a, (hl)
	or	a		; already end of string?
	jr	z, .nomatch
	xor	a
	call	findchar	; go to end of string
	dec	hl
	ld	a, (hl)
	cp	'"'
	jr	nz, .nomatch
	; We have a match, replace ending quote with null char
	xor	a
	ld	(hl), a
	; Good, let's go back
	pop	hl
	; ... but one char further
	inc	hl
	cp	a	; ensure Z
	ret
.nomatch:
	call	unsetZ
	pop	hl
	ret

; Find string (HL) in string list (DE) of size B, in a case-insensitive manner.
; Each string is C bytes wide.
; Returns the index of the found string. Sets Z if found, unsets Z if not found.
findStringInList:
	push	de
	push	bc
.loop:
	ld	a, c
	call	strncmpI
	ld	a, c
	call	addDE
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
