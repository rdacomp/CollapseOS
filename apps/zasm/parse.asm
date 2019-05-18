; Parse the decimal char at A and extract it's 0-9 numerical value. Put the
; result in A.
;
; On success, the carry flag is reset. On error, it is set.
parseDecimalDigit:
	; First, let's see if we have an easy 0-9 case
	cp	'0'
	ret	c	; if < '0', we have a problem
	sub	a, '0'		; our value now is valid if it's < 10
	cp	10		; on success, C is set, which is the opposite
				; of what we want
	ccf			; invert C flag
	ret

; Parse string at (HL) as a decimal value and return value in IX under the
; same conditions as parseLiteral.
parseDecimal:
	push	hl
	push	de
	push	bc

	ld	ix, 0
.loop:
	ld	a, (hl)
	cp	0
	jr	z, .end	; success!
	call	parseDecimalDigit
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
	call	unsetZ
.end:
	pop	bc
	pop	de
	pop	hl
	ret


; Parse string at (HL) as a hexadecimal value and return value in IX under the
; same conditions as parseLiteral.
parseHexadecimal:
	call	hasHexPrefix
	ret	nz
	push	hl
	xor	a
	ld	ixh, a
	inc	hl	; get rid of "0x"
	inc	hl
	call	strlen
	cp	3
	jr	c, .single
	cp	5
	jr	c, .double
	; too long, error
	jr	.error
.double:
	call	parseHexPair	; moves HL to last char of pair
	jr	c, .error
	inc	hl			; now HL is on first char of next pair
	ld	ixh, a
.single:
	call	parseHexPair
	jr	c, .error
	ld	ixl, a
	cp	a			; ensure Z
	jr	.end
.error:
	call	unsetZ
.end:
	pop	hl
	ret

; Sets Z if (HL) has a '0x' prefix.
hasHexPrefix:
	ld	a, (hl)
	cp	'0'
	ret	nz
	push	hl
	inc	hl
	ld	a, (hl)
	cp	'x'
	pop	hl
	ret

; Parse string at (HL) as a binary value (0b010101) and return value in IXL.
; Clears IXH.
; Sets Z on success.
parseBinaryLiteral:
	call	hasBinPrefix
	ret	nz
	push	bc
	push	hl
	xor	a
	ld	ixh, a
	inc	hl	; get rid of "0x"
	inc	hl
	call	strlen
	or	a
	jr	z, .error	; empty, error
	cp	9
	jr	nc, .error	; >= 9, too long
	; We have a string of 8 or less chars. What we'll do is that for each
	; char, we rotate left and set the LSB according to whether we have '0'
	; or '1'. Error out on anything else. C is our stored result.
	ld	b, a		; we loop for "strlen" times
	ld	c, 0		; our stored result
.loop:
	rlc	c
	ld	a, (hl)
	inc	hl
	cp	'0'
	jr	z, .nobit	; no bit to set
	cp	'1'
	jr	nz, .error	; not 0 or 1
	; We have a bit to set
	inc	c
.nobit:
	djnz	.loop
	ld	ixl, c
	cp	a		; ensure Z
	jr	.end
.error:
	call	unsetZ
.end:
	pop	hl
	pop	bc
	ret

; Sets Z if (HL) has a '0b' prefix.
hasBinPrefix:
	ld	a, (hl)
	cp	'0'
	ret	nz
	push	hl
	inc	hl
	ld	a, (hl)
	cp	'b'
	pop	hl
	ret

; Parse string at (HL) and, if it is a char literal, sets Z and return
; corresponding value in IXL. Clears IXH.
;
; A valid char literal starts with ', ends with ' and has one character in the
; middle. No escape sequence are accepted, but ''' will return the apostrophe
; character.
parseCharLiteral:
	ld	a, 0x27		; apostrophe (') char
	cp	(hl)
	ret	nz

	push	hl
	inc	hl
	inc	hl
	cp	(hl)
	jr	nz, .end	; not ending with an apostrophe
	inc	hl
	ld	a, (hl)
	or	a		; cp 0
	jr	nz, .end	; string has to end there
	; Valid char, good
	ld	ixh, a		; A is zero, take advantage of that
	dec	hl
	dec	hl
	ld	a, (hl)
	ld	ixl, a
	cp	a		; ensure Z
.end:
	pop	hl
	ret

; Parses the string at (HL) and returns the 16-bit value in IX. The string
; can be a decimal literal (1234), a hexadecimal literal (0x1234) or a char
; literal ('X').
;
; As soon as the number doesn't fit 16-bit any more, parsing stops and the
; number is invalid. If the number is valid, Z is set, otherwise, unset.
parseLiteral:
	call	parseCharLiteral
	ret	z
	call	parseHexadecimal
	ret	z
	call	parseBinaryLiteral
	ret	z
	jp	parseDecimal

; Parse string in (HL) and return its numerical value whether its a number
; literal or a symbol. Returns value in IX.
; Sets Z if number or symbol is valid, unset otherwise.
parseNumberOrSymbol:
	call	parseLiteral
	ret	z
	call	zasmIsFirstPass
	ret	z		; first pass? we don't care about the value,
				; return success.
	; Not a number. Try symbol
	call	symSelect
	call	symFind
	ret	nz	; not found
	; Found! index in A, let's fetch value
	push	de
	call	symGetVal
	; value in DE. We need it in IX
	ld	ixh, d
	ld	ixl, e
	pop	de
	cp	a		; ensure Z
	ret
