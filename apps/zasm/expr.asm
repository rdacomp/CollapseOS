; Parse expression in string at (HL) and returns the result in IX.
; We expect (HL) to be disposable: we mutate it to avoid having to make a copy.
; Sets Z on success, unset on error.
parseExpr:
	push	hl
	ld	a, '+'
	call	JUMP_FINDCHAR
	jr	nz, .noExpr
	; Alright, we have a + and we're pointing at it. Let's advance HL and
	; recurse. But first, let's change this + into a null char. It will be
	; handy later.
	xor	a
	ld	(hl), a		; + changed to \0

	inc	hl
	call	parseExpr
	; Whether parseExpr was successful or not, we pop hl right now
	pop	hl
	ret	nz		; return immediately if error
	; Now we have parsed everything to the right and we have its result in
	; IX. the pop hl brought us back to the beginning of the string. Our
	; + was changed to a 0. Let's save IX somewhere and parse this.
	push	de
	ld	d, ixh
	ld	e, ixl
	call	parseNumberOrSymbol
	jr	nz, .end		; error
	; Good! let's do the math!
	add	ix, de
.end:
	pop	de
	ret
.noExpr:
	pop	hl
	jp	parseNumberOrSymbol
