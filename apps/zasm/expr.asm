; Parse expression in string at (HL) and returns the result in IX.
; We expect (HL) to be disposable: we mutate it to avoid having to make a copy.
; Sets Z on success, unset on error.
parseExpr:
	push	de
	push	hl
	call	_parseExpr
	pop	hl
	pop	de
	ret

_parseExpr:
	ld	a, '+'
	call	_findAndSplit
	jp	z, _applyPlus
	ld	a, '-'
	call	_findAndSplit
	jp	z, _applyMinus
	ld	a, '*'
	call	_findAndSplit
	jp	z, _applyMult
	jp	parseNumberOrSymbol

; Given a string in (HL) and a separator char in A, return a splitted string,
; that is, the same (HL) string but with the found A char replaced by a null
; char. DE points to the second part of the split.
; Sets Z if found, unset if not found.
_findAndSplit:
	push	hl
	call	.skipCharLiteral
	call	findchar
	jr	nz, .end	; nothing found
	; Alright, we have our char and we're pointing at it. Let's replace it
	; with a null char.
	xor	a
	ld	(hl), a		; + changed to \0
	inc	hl
	ex	de, hl		; DE now points to the second part of the split
	cp	a		; ensure Z
.end:
	pop	hl		; HL is back to the start
	ret

.skipCharLiteral:
	; special case: if our first char is ', skip the first 3 characters
	; so that we don't mistake a literal for an iterator
	push	af
	ld	a, (hl)
	cp	0x27		; '
	jr	nz, .skipCharLiteralEnd	; not a '
	xor	a	; check for null char during skipping
	; skip 3
	inc	hl
	cp	(hl)
	jr	z, .skipCharLiteralEnd
	inc	hl
	cp	(hl)
	jr	z, .skipCharLiteralEnd
	inc	hl
.skipCharLiteralEnd:
	pop	af
	ret
.find:

; parse expression on the left (HL) and the right (DE) and put the results in
; DE (left) and IX (right)
_resolveLeftAndRight:
	call	parseExpr
	ret	nz		; return immediately if error
	; Now we have parsed everything to the left and we have its result in
	; IX. What we need to do now is the same thing on (DE) and then apply
	; the + operator. Let's save IX somewhere and parse this.
	ex	de, hl	; right expr now in HL
	push	ix
	pop	de	; numeric left expr result in DE
	jp	parseExpr

; Parse expr in (HL) and expr in (DE) and apply + operator to both sides.
; Put result in IX.
_applyPlus:
	call	_resolveLeftAndRight
	ret	nz
	; Good! let's do the math! IX has our right part, DE has our left one.
	add	ix, de
	cp	a		; ensure Z
	ret

; Same as _applyPlus but with -
_applyMinus:
	call	_resolveLeftAndRight
	ret	nz
	push	ix
	pop	hl
	ex	de, hl
	scf \ ccf
	sbc	hl, de
	push	hl
	pop	ix
	cp	a		; ensure Z
	ret

_applyMult:
	call	_resolveLeftAndRight
	ret	nz
	push	ix \ pop bc
	call	multDEBC
	push	hl \ pop ix
	cp	a		; ensure Z
	ret
