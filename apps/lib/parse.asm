; *** Requirements ***
; unsetZ
;
; *** Code ***

; Parse the decimal char at A and extract it's 0-9 numerical value. Put the
; result in A.
;
; On success, the carry flag is reset. On error, it is set.
parseDecimalDigit:
	; First, let's see if we have an easy 0-9 case
	cp	'0'
	ret	c	; if < '0', we have a problem
	sub	'0'		; our value now is valid if it's < 10
	cp	10		; on success, C is set, which is the opposite
				; of what we want
	ccf			; invert C flag
	ret

; Parse string at (HL) as a decimal value and return value in IX under the
; same conditions as parseLiteral.
; Sets Z on success, unset on error.
parseDecimal:
	push	hl
	push	de

	ld	ix, 0
.loop:
	ld	a, (hl)
	or	a
	jr	z, .end	; success!
	call	parseDecimalDigit
	jr	c, .error

	; Now, let's add A to IX. First, multiply by 10.
	push	ix \ pop de
	add	ix, ix	; x2
	jr	c, .error
	add	ix, ix	; x4
	jr	c, .error
	add	ix, ix	; x8
	jr	c, .error
	add	ix, de	; x9
	jr	c, .error
	add	ix, de	; x10
	jr	c, .error
	ld	d, 0
	ld	e, a
	add	ix, de
	jr	c, .error

	inc	hl
	jr	.loop

	cp	a	; ensure Z
	jr	.end
.error:
	call	unsetZ
.end:
	pop	de
	pop	hl
	ret


