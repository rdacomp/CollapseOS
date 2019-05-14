; core
;
; Routines used by pretty much all parts. You will want to include it first
; in your glue file.

; *** CONSTS ***
.equ	ASCII_CR	0x0d
.equ	ASCII_LF	0x0a

; *** DATA ***
; Useful data to point to, when a pointer is needed.
P_NULL:		.db 0

; *** REGISTER FIDDLING ***

; add the value of A into DE
addDE:
	push	af
	add	a, e
	jr	nc, .end	; no carry? skip inc
	inc	d
.end:
	ld	e, a
	pop	af
	ret

; copy (DE) into DE, little endian style (addresses in z80 are always have
; their LSB before their MSB)
intoDE:
	push	af
	ld	a, (de)
	inc	de
	ex	af, af'
	ld	a, (de)
	ld	d, a
	ex	af, af'
	ld	e, a
	pop	af
	ret

intoHL:
	push	de
	ex	de, hl
	call	intoDE
	ex	de, hl
	pop	de
	ret

; add the value of A into HL
addHL:
	push	af
	add	a, l
	jr	nc, .end	; no carry? skip inc
	inc	h
.end:
	ld	l, a
	pop	af
	ret


; Write the contents of HL in (DE)
writeHLinDE:
	push	af
	ld	a, l
	ld	(de), a
	inc	de
	ld	a, h
	ld	(de), a
	dec	de
	pop	af
	ret

; jump to the location pointed to by IX. This allows us to call IX instead of
; just jumping it. We use IX because we never use this for arguments.
callIX:
	jp	(ix)
	ret

callIY:
	jp	(iy)
	ret

; Ensures that Z is unset (more complicated than it sounds...)
unsetZ:
	push	bc
	ld	b, a
	inc	b
	cp	b
	pop	bc
	ret

; *** STRINGS ***

; Fill B bytes at (HL) with A
fill:
	push	bc
	push	hl
.loop:
	ld	(hl), a
	inc	hl
	djnz	.loop
	pop	hl
	pop	bc
	ret

; Increase HL until the memory address it points to is equal to A for a maximum
; of 0xff bytes. Returns the new HL value as well as the number of bytes
; iterated in A.
; If a null char is encountered before we find A, processing is stopped in the
; same way as if we found our char (so, we look for A *or* 0)
; Set Z if the character is found. Unsets it if not
findchar:
	push	bc
	ld	c, a	; let's use C as our cp target
	ld	a, 0xff
	ld	b, a

.loop:	ld	a, (hl)
	cp	c
	jr	z, .match
	or	a		; cp 0
	jr	z, .nomatch
	inc	hl
	djnz	.loop
.nomatch:
	call	unsetZ
	jr	.end
.match:
	; We ran 0xff-B loops. That's the result that goes in A.
	ld	a, 0xff
	sub	a, b
	cp	a	; ensure Z
.end:
	pop	bc
	ret

; Format the lower nibble of A into a hex char and stores the result in A.
fmtHex:
	and	0xf
	cp	10
	jr	nc, .alpha	; if >= 10, we have alpha
	add	a, '0'
	ret
.alpha:
	add	a, 'A'-10
	ret

; Formats value in A into a string hex pair. Stores it in the memory location
; that HL points to. Does *not* add a null char at the end.
fmtHexPair:
	push	af

	; let's start with the rightmost char
	inc	hl
	call	fmtHex
	ld	(hl), a

	; and now with the leftmost
	dec	hl
	pop	af
	push	af
	and	0xf0
	rra \ rra \ rra \ rra
	call	fmtHex
	ld	(hl), a

	pop	af
	ret

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

; Compares strings pointed to by HL and DE up to A count of characters. If
; equal, Z is set. If not equal, Z is reset.
strncmp:
	push	bc
	push	hl
	push	de

	ld	b, a
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
	djnz	.loop
	; We went through all chars with success, but our current Z flag is
	; unset because of the cp 0. Let's do a dummy CP to set the Z flag.
	cp	a

.end:
	pop	de
	pop	hl
	pop	bc
	; Because we don't call anything else than CP that modify the Z flag,
	; our Z value will be that of the last cp (reset if we broke the loop
	; early, set otherwise)
	ret

; Transforms the character in A, if it's in the a-z range, into its upcase
; version.
upcase:
	cp	'a'
	ret	c	; A < 'a'. nothing to do
	cp	'z'+1
	ret	nc	; A >= 'z'+1. nothing to do
	; 'a' - 'A' == 0x20
	sub	0x20
	ret

