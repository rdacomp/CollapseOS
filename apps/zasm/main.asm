; *** Requirements ***
; JUMP_STRNCMP
; JUMP_ADDDE
; JUMP_UPCASE
; JUMP_UNSETZ
; JUMP_INTODE

; *** Code ***
; Parse asm file in (HL) and outputs its upcodes in (DE). Returns the number
; of bytes written in C.
main:
	ld	bc, 0		; C is our written bytes counter
.loop:
	call	parseLine
	jr	nz, .stop
	ld	a, c
	add	a, ixl
	ld	c, a
	call	gotoNextLine
	jr	nz, .stop	; error? stop
	jr	.loop
.stop:
	ret

#include "util.asm"
#include "parse.asm"
#include "literal.asm"
#include "instr.asm"
#include "tok.asm"
#include "directive.asm"

; Parse line in (HL), write the resulting opcode(s) in (DE) and returns the
; number of written bytes in IXL. Advances HL where tokenization stopped and DE
; to where we should write the next upcode.
; Sets Z if parse was successful, unset if there was an error or EOF.
parseLine:
	push	bc

	call	gotoNextNotBlankLine
	jr	nz, .error
	call	tokenize
	ld	a, b		; TOK_*
	cp	TOK_INSTR
	jr	z, .instr
	cp	TOK_DIRECTIVE
	jr	z, .direc
	jr	.error		; token not supported
.instr:
	ld	a, c		; I_*
	call	parseInstruction
	or	a	; is zero?
	jr	z, .error
	ld	b, 0
	ld	c, a	; written bytes
	push	hl
	ld	hl, instrUpcode
	call	copy
	pop	hl
	call	JUMP_ADDDE
	jr	.success
.direc:
	ld	a, c		; D_*
	call	parseDirective
	ld	b, 0
	ld	c, a	; written bytes
	push	hl
	ld	hl, direcData
	call	copy
	pop	hl
	call	JUMP_ADDDE
	jr	.success
.success:
	ld	ixl, a
	xor	a		; ensure Z
	jr	.end
.error:
	xor	ixl
	call	JUMP_UNSETZ
.end:
	pop	bc
	ret

