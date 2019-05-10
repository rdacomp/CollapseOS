; *** Requirements ***
; blockdev
; JUMP_STRNCMP
; JUMP_ADDDE
; JUMP_ADDHL
; JUMP_UPCASE
; JUMP_UNSETZ
; JUMP_INTODE
; JUMP_FINDCHAR
; RAMSTART	(where we put our variables in RAM)

; *** Code ***
; Read file through GetC routine pointer at HL and outputs its upcodes through
; the PutC routine pointer at DE.
main:
	ld	(ioGetCPtr), hl
	ld	(ioPutCPtr), de
	ld	hl, 0
	ld	(curOutputOffset), hl
.loop:
	call	ioReadLine
	or	a		; is A 0?
	jr	z, .stop	; We have EOF
	call	parseLine
	jr	nz, .stop
	jr	.loop
.stop:
	ret

#include "util.asm"
#include "io.asm"
#include "parse.asm"
#include "literal.asm"
#include "instr.asm"
#include "directive.asm"
.equ	SYM_RAMSTART	RAMSTART
#include "symbol.asm"

; Increase (curOutputOffset) by A
incOutputOffset:
	push	de
	ld	de, (curOutputOffset)
	call	JUMP_ADDDE
	ld	(curOutputOffset), de
	pop	de
	ret

; Parse line in (HL), write the resulting opcode(s) in (DE) and increases
; (curOutputOffset) by the number of bytes written. Advances HL where
; tokenization stopped and DE to where we should write the next upcode.
; Sets Z if parse was successful, unset if there was an error or EOF.
parseLine:
	push	bc

	call	tokenize
	ld	a, b		; TOK_*
	cp	TOK_INSTR
	jr	z, .instr
	cp	TOK_DIRECTIVE
	jr	z, .direc
	cp	TOK_LABEL
	jr	z, .label
	cp	TOK_EMPTY
	jr	z, .success	; empty line? do nothing but don't error out.
	jr	.error		; token not supported
.instr:
	ld	a, c		; I_*
	call	parseInstruction
	or	a	; is zero?
	jr	z, .error
	call	incOutputOffset
	ld	b, a
	ld	hl, instrUpcode
.loopInstr:
	ld	a, (hl)
	call	ioPutC
	inc	hl
	djnz	.loopInstr
	jr	.success
.direc:
	ld	a, c		; D_*
	call	parseDirective
	call	incOutputOffset
	ld	b, a
	ld	hl, direcData
.loopDirec:
	ld	a, (hl)
	call	ioPutC
	inc	hl
	djnz	.loopDirec
	jr	.success
.label:
	; The string in (scratchpad) is a label with its trailing ':' removed.
	ld	hl, scratchpad
	ld	de, (curOutputOffset)
	call	symRegister

	jr	.success
.success:
	xor	a		; ensure Z
	jr	.end
.error:
	call	JUMP_UNSETZ
.end:
	pop	bc
	ret

; *** Variables ***
; The offset where we currently are with regards to outputting opcodes
curOutputOffset:
	.fill	2
