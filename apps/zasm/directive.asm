; *** CONSTS ***

D_DB	.equ	0x00
D_BAD	.equ	0xff

; *** CODE ***

; 4 bytes per row, fill with zero
directiveNames:
	.db	".DB", 0

; Reads string in (HL) and returns the corresponding ID (D_*) in A. Sets Z if
; there's a match.
getDirectiveID:
	push	bc
	push	de
	ld	b, 1
	ld	c, 4
	ld	de, directiveNames
	call	findStringInList
	pop	de
	pop	bc
	ret

parseDirective:
	xor	a
	ret
