; Parse the decimal char at A and extract it's 0-9 numerical value. Put the
; result in A.
;
; On success, the carry flag is reset. On error, it is set.
parseDecimal:
	; First, let's see if we have an easy 0-9 case
	cp	'0'
	ret	c	; if < '0', we have a problem
	sub	a, '0'		; our value now is valid if it's < 10
	cp	10		; on success, C is set, which is the opposite
				; of what we want
	ccf			; invert C flag
	ret

; Parses the string at (HL) and returns the 16-bit value in IX.
; As soon as the number doesn't fit 16-bit any more, parsing stops and the
; number is invalid. If the number is valid, Z is set, otherwise, unset.
parseNumber:
	push	hl
	push	de
	push	bc

	ld	ix, 0
.loop:
	ld	a, (hl)
	cp	0
	jr	z, .end	; success!
	call	parseDecimal
	jr	c, .error

	; Now, let's add A to IX. First, multiply by 10.
	ld	d, ixh	; we need a copy of the initial copy for later
	ld	e, ixl
	add	ix, ix	; x2
	add	ix, ix	; x4
	add	ix, ix	; x8
	add	ix, de	; x9
	add	ix, de	; x10
	add	a, ixl
	jr	nc, .nocarry
	inc	ixh
.nocarry:
	ld	ixl, a

	; We didn't bother checking for the C flag at each step because we
	; check for overflow afterwards. If ixh < d, we overflowed
	ld	a, ixh
	cp	d
	jr	c, .error	; carry is set? overflow

	inc	hl
	jr	.loop

.error:
	call	JUMP_UNSETZ
.end:
	pop	bc
	pop	de
	pop	hl
	ret
