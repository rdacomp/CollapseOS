; *** CONSTS ***

.equ	D_DB	0x00
.equ	D_DW	0x01
.equ	D_EQU	0x02
.equ	D_ORG	0x03
.equ	D_FIL	0x04
.equ	D_INC	0x05
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
	.db	".ORG"
	.db	".FIL"
	.db	"#inc"

; This is a list of handlers corresponding to indexes in directiveNames
directiveHandlers:
	.dw	handleDB
	.dw	handleDW
	.dw	handleEQU
	.dw	handleORG
	.dw	handleFIL
	.dw	handleINC

handleDB:
	push	hl
.loop:
	call	readWord
	jr	nz, .badfmt
	ld	hl, scratchpad
	call	enterDoubleQuotes
	jr	z, .stringLiteral
	call	parseExpr
	jr	nz, .badarg
	push	ix \ pop hl
	ld	a, h
	or	a		; cp 0
	jr	nz, .overflow	; not zero? overflow
	ld	a, l
	call	ioPutC
.stopStrLit:
	call	readComma
	jr	z, .loop
	cp	a		; ensure Z
	pop	hl
	ret
.badfmt:
	ld	a, ERR_BAD_FMT
	jr	.error
.badarg:
	ld	a, ERR_BAD_ARG
	jr	.error
.overflow:
	ld	a, ERR_OVFL
.error:
	call	unsetZ
	pop	hl
	ret

.stringLiteral:
	ld	a, (hl)
	inc	hl
	or	a		; when we encounter 0, that was what used to
	jr	z, .stopStrLit	; be our closing quote. Stop.
	; Normal character, output
	call	ioPutC
	jr	.stringLiteral

handleDW:
	push	hl
.loop:
	call	readWord
	jr	nz, .badfmt
	ld	hl, scratchpad
	call	parseExpr
	jr	nz, .badarg
	push	ix \ pop hl
	ld	a, l
	call	ioPutC
	ld	a, h
	call	ioPutC
	call	readComma
	jr	z, .loop
	cp	a		; ensure Z
	pop	hl
	ret
.badfmt:
	ld	a, ERR_BAD_FMT
	jr	.error
.badarg:
	ld	a, ERR_BAD_ARG
.error:
	call	unsetZ
	pop	hl
	ret

handleEQU:
	push	hl
	push	de
	push	bc
	; Read our constant name
	call	readWord
	; We can't register our symbol yet: we don't have our value!
	; Let's copy it over.
	ld	de, DIREC_SCRATCHPAD
	ld	bc, SCRATCHPAD_SIZE
	ldir

	; Now, read the value associated to it
	call	readWord
	ld	hl, scratchpad
	call	parseExpr
	jr	nz, .end
	ld	hl, DIREC_SCRATCHPAD
	push	ix \ pop de
	call	symRegister
.end:
	xor	a		; 0 bytes written
	pop	bc
	pop	de
	pop	hl
	ret

handleORG:
	call	readWord
	call	parseExpr
	ret	nz
	push	ix \ pop hl
	call	zasmSetOrg
	cp	a		; ensure Z
	ret

handleFIL:
	call	readWord
	call	parseExpr
	ret	nz
	push	bc
	push	ix \ pop bc
	xor	a
	ld	b, c
.loop:
	call	ioPutC
	djnz	.loop
	cp	a		; ensure Z
	pop	bc
	ret

handleINC:
	call	readWord
	jr	nz, .end
	; HL points to scratchpad
	call	enterDoubleQuotes
	jr	nz, .end
	call	ioOpenInclude
.end:
	xor	a		; zero bytes written
	ret

; Reads string in (HL) and returns the corresponding ID (D_*) in A. Sets Z if
; there's a match.
getDirectiveID:
	push	bc
	push	de
	ld	b, D_INC+1		; D_INC is last
	ld	c, 4
	ld	de, directiveNames
	call	findStringInList
	pop	de
	pop	bc
	ret

; Parse directive specified in A (D_* const) with args in I/O and act in
; an appropriate manner. If the directive results in writing data at its
; current location, that data is directly written through ioPutC.
; Each directive has the same return value pattern: Z on success, not-Z on
; error, A contains the error number (ERR_*).
parseDirective:
	push	de
	; double A to have a proper offset in directiveHandlers
	add	a, a
	ld	de, directiveHandlers
	call	addDE
	call	intoDE
	push	de \ pop ix
	pop	de
	jp	(ix)
