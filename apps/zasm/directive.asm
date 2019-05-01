; *** CONSTS ***

D_DB	.equ	0x00
D_BAD	.equ	0xff

; *** CODE ***

; 4 bytes per row, fill with zero
directiveNames:
	.db	".DB", 0

; This is a list of handlers corresponding to indexes in directiveNames
directiveHandlers:
	.dw	handleDB

handleDB:
	push	de
	push	hl
	call	toWord
	ld	de, scratchpad
	ld	a, 8
	call	readWord
	ld	hl, scratchpad
	call	parseNumber
	ld	a, ixl
	ld	(direcData), a
	ld	a, 1
	pop	hl
	pop	de
	ret


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

; Parse directive specified in A (D_* const) with args in (HL) and act in
; an appropriate manner. If the directive results in writing data at its
; current location, that data is in (direcData) and A is the number of bytes
; in it.
parseDirective:
	push	de
	; double A to have a proper offset in directiveHandlers
	add	a, a
	ld	de, directiveHandlers
	call	JUMP_ADDDE
	ld	ixh, d
	ld	ixl, e
	pop	de
	jp	(ix)

; *** Variables ***
direcData:
	.fill 2
