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
parseDecimal:
	push	hl
	push	de
	push	bc

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
	push	de
	ld	d, 0
	inc	hl	; get rid of "0x"
	inc	hl
	call	strlen
	cp	3
	jr	c, .single
	cp	4
	jr	c, .doubleShort	; 0x123
	cp	5
	jr	c, .double	; 0x1234
	; too long, error
	jr	.error
.double:
	call	parseHexPair
	jr	c, .error
	inc	hl			; now HL is on first char of next pair
	ld	d, a
	jr	.single
.doubleShort:
	ld	a, (hl)
	call	parseHex
	jr	c, .error
	inc	hl			; now HL is on first char of next pair
	ld	d, a
.single:
	call	parseHexPair
	jr	c, .error
	ld	e, a
	cp	a			; ensure Z
	jr	.end
.error:
	call	unsetZ
.end:
	push	de \ pop ix
	pop	de
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

; Parse string at (HL) as a binary value (0b010101) and return value in IX.
; High IX byte is always clear.
; Sets Z on success.
parseBinaryLiteral:
	call	hasBinPrefix
	ret	nz
	push	bc
	push	hl
	push	de
	ld	d, 0
	inc	hl	; get rid of "0b"
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
	ld	e, c
	cp	a		; ensure Z
	jr	.end
.error:
	call	unsetZ
.end:
	push	de \ pop ix
	pop	de
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
; corresponding value in IX. High IX byte is always clear.
;
; A valid char literal starts with ', ends with ' and has one character in the
; middle. No escape sequence are accepted, but ''' will return the apostrophe
; character.
parseCharLiteral:
	ld	a, 0x27		; apostrophe (') char
	cp	(hl)
	ret	nz

	push	hl
	push	de
	inc	hl
	inc	hl
	cp	(hl)
	jr	nz, .end	; not ending with an apostrophe
	inc	hl
	ld	a, (hl)
	or	a		; cp 0
	jr	nz, .end	; string has to end there
	; Valid char, good
	ld	d, a		; A is zero, take advantage of that
	dec	hl
	dec	hl
	ld	a, (hl)
	ld	e, a
	cp	a		; ensure Z
.end:
	push	de \ pop ix
	pop	de
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
	; Not a number. Try PC
	push	de
	ld	de, .sDollar
	call	strcmp
	pop	de
	jr	z, .returnPC
	; Not PC either, try symbol
	call	symSelect
	call	symFind
	jr	nz, .notfound
	; Found! let's fetch value
	push	de
	call	symGetVal
	; value in DE. We need it in IX
	push	de \ pop ix
	pop	de
	cp	a		; ensure Z
	ret
.notfound:
	; If not found, check if we're in first pass. If we are, it doesn't
	; matter that we didn't find our symbol. Return success anyhow.
	; Otherwise return error. Z is already unset, so in fact, this is the
	; same as jumping to zasmIsFirstPass
	jp	zasmIsFirstPass

.returnPC:
	push	hl
	call	zasmGetPC
	push	hl \ pop ix
	pop	hl
	ret
.sDollar:
	.db	'$', 0
