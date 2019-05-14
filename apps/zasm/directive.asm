; *** CONSTS ***

.equ	D_DB	0x00
.equ	D_DW	0x01
.equ	D_EQU	0x02
.equ	D_BAD	0xff

; *** Variables ***
.equ	DIREC_SCRATCHPAD	DIREC_RAMSTART
.equ	DIREC_RAMEND		DIREC_SCRATCHPAD+SCRATCHPAD_SIZE
; *** CODE ***

; 4 bytes per row, fill with zero
directiveNames:
	.db	".DB", 0
	.db	".DW", 0
	.db	".EQU"

; This is a list of handlers corresponding to indexes in directiveNames
directiveHandlers:
	.dw	handleDB
	.dw	handleDW
	.dw	handleEQU

handleDB:
	push	hl
	call	toWord
	call	readWord
	ld	hl, scratchpad
	call	parseLiteral
	ld	a, ixl
	ld	(direcData), a
	ld	a, 1
	pop	hl
	ret

handleDW:
	push	hl
	call	toWord
	call	readWord
	ld	hl, scratchpad
	call	parseNumberOrSymbol
	ld	a, ixl
	ld	(direcData), a
	ld	a, ixh
	ld	(direcData+1), a
	ld	a, 2
	pop	hl
	ret

handleEQU:
	call	zasmIsFirstPass
	jr	nz, .begin
	; first pass? .equ are noops
	xor	a
	ret
.begin:
	push	hl
	push	de
	push	bc
	; Read our constant name
	call	toWord
	call	readWord
	; We can't register our symbol yet: we don't have our value!
	; Let's copy it over.
	push	hl
		ld	hl, scratchpad
		ld	de, DIREC_SCRATCHPAD
		ld	bc, SCRATCHPAD_SIZE
		ldir
	pop	hl

	; Now, read the value associated to it
	call	toWord
	call	readWord
	ld	hl, scratchpad
	call	parseNumberOrSymbol
	jr	nz, .error
	ld	hl, DIREC_SCRATCHPAD
	ld	d, ixh
	ld	e, ixl
	call	symRegister
	jr	.end
.error:
.end:
	xor	a		; 0 bytes written
	pop	bc
	pop	de
	pop	hl
	ret

; Reads string in (HL) and returns the corresponding ID (D_*) in A. Sets Z if
; there's a match.
getDirectiveID:
	push	bc
	push	de
	ld	b, D_EQU+1		; D_EQU is last
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
	call	JUMP_INTODE
	ld	ixh, d
	ld	ixl, e
	pop	de
	jp	(ix)

; *** Variables ***
direcData:
	.fill 2
