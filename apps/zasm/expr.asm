; Parse expression in string at (HL) and returns the result in IX.
; We expect (HL) to be disposable: we mutate it to avoid having to make a copy.
; Sets Z on success, unset on error.
parseExpr:
	push	bc
	push	de
	push	hl
	ld	a, '+'
	call	JUMP_FINDCHAR
	jr	z, .hasExpr
	pop	hl
	push	hl
	ld	a, '-'
	call	JUMP_FINDCHAR
	jr	nz, .noExpr
	ld	c, '-'
	jr	.hasExpr
.hasPlus:
	ld	c, '+'
	jr	.hasExpr
.hasExpr:
	; Alright, we have a +/ and we're pointing at it. Let's advance HL and
	; recurse. But first, let's change this + into a null char. It will be
	; handy later.
	xor	a
	ld	(hl), a		; + changed to \0

	inc	hl
	pop	de		; we pop out the HL we pushed earlier into DE
				; That's our original beginning of string.
	call	_applyExprToHL
	pop	de
	pop	bc
	ret

.noExpr:
	pop	hl
	pop	de
	pop	bc
	jp	parseNumberOrSymbol

; Parse number or symbol in (DE) and expression in (HL) and apply operator
; specified in C to them.
_applyExprToHL:
	call	parseExpr
	ret	nz		; return immediately if error
	; Now we have parsed everything to the right and we have its result in
	; IX. What we need to do now is parseNumberOrSymbol on (DE) and apply
	; operator. Let's save IX somewhere and parse this.
	ex	hl, de
	push	ix
	pop	de
	call	parseNumberOrSymbol
	ret	nz		; error
	; Good! let's do the math! IX has our left part, DE has our right one.
	ld	a, c		; restore operator
	cp	'-'
	jr	z, .sub
	; addition
	add	ix, de
	jr	.end
.sub:
	push	ix
	pop	hl
	sbc	hl, de
	push	hl
	pop	ix
.end:
	cp	a		; ensure Z
	ret
