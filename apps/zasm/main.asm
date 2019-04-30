#include "user.inc"

; *** Code ***
.org	USER_CODE

; Parse asm file in (HL) and outputs its upcodes in (DE). Returns the number
; of bytes written in C.
main:
	ld	bc, 0		; C is our written bytes counter
.loop:
	call	parseLine
	or	a		; is zero? stop
	jr	z, .stop
	add	a, c
	ld	c, a
	call	gotoNextLine
	jr	nz, .stop	; error? stop
	jr	.loop
.stop:
	ret

; Parse line in (HL), write the resulting opcode(s) in (DE) and returns the
; number of written bytes in A. Advances HL where tokenization stopped and DE
; to where we should write the next upcode.
parseLine:
	push	bc

	call	gotoNextNotBlankLine
	push	de
	ld	de, tokInstr
	call	tokenize
	ld	de, tokArg1
	call	tokenizeInstrArg
	ld	de, tokArg2
	call	tokenizeInstrArg
	pop	de
	call	parseTokens
	or	a	; is zero?
	jr	z, .error
	ld	b, 0
	ld	c, a	; written bytes
	push	hl
	ld	hl, curUpcode
	call	copy
	pop	hl
	call	JUMP_ADDDE
	jr	.end
.error:
	xor	a
.end:
	pop	bc
	ret

#include "util.asm"
#include "tok.asm"
#include "instr.asm"

; *** Variables ***

tokInstr:
	.fill	5
tokArg1:
	.fill	9
tokArg2:
	.fill	9

