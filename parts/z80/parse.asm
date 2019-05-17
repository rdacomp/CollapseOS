; Parse the hex char at A and extract it's 0-15 numerical value. Put the result
; in A.
;
; On success, the carry flag is reset. On error, it is set.
parseHex:
	; First, let's see if we have an easy 0-9 case
	cp	'0'
	jr	c, .error	; if < '0', we have a problem
	cp	'9'+1
	jr	nc, .alpha	; if >= '9'+1, we might have alpha
	; We are in the 0-9 range
	sub	'0'		; C is clear
	ret

.alpha:
	call	upcase
	cp	'A'
	jr	c, .error	; if < 'A', we have a problem
	cp	'F'+1
	jr	nc, .error	; if >= 'F', we have a problem
	; We have alpha.
	sub	'A'-10		; C is clear
	ret

.error:
	scf
	ret

; Parses 2 characters of the string pointed to by HL and returns the numerical
; value in A. If the second character is a "special" character (<0x21) we don't
; error out: the result will be the one from the first char only.
; HL is set to point to the last char of the pair.
;
; On success, the carry flag is reset. On error, it is set.
parseHexPair:
	push	bc

	ld	a, (hl)
	call	parseHex
	jr	c, .end		; error? goto end, keeping the C flag on
	rla \ rla \ rla \ rla	; let's push this in MSB
	ld	b, a
	inc	hl
	ld	a, (hl)
	cp	0x21
	jr	c, .single	; special char? single digit
	call	parseHex
	jr	c, .end		; error?
	or	b		; join left-shifted + new. we're done!
	; C flag was set on parseHex and is necessarily clear at this point
	jr	.end

.single:
	; If we have a single digit, our result is already stored in B, but
	; we have to right-shift it back.
	ld	a, b
	and	0xf0
	rra \ rra \ rra \ rra
	dec	hl

.end:
	pop	bc
	ret
