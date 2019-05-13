; zasm
;
; Reads input from specified blkdev ID, assemble the binary in two passes and
; spit the result in another specified blkdev ID.
;
; We don't buffer the whole source in memory, so we need our input blkdev to
; support Seek so we can read the file a second time. So, for input, we need
; GetC and Seek.
;
; For output, we only need PutC. Output doesn't start until the second pass.
;
; The goal of the second pass is to assign values to all symbols so that we
; can have forward references (instructions referencing a label that happens
; later).
;
; Labels and constants are both treated the same way, that is, they can be
; forward-referenced in instructions. ".equ" directives, however, are evaluated
; during the first pass so forward references are not allowed.
;
; *** Requirements ***
; blockdev
; JUMP_STRNCMP
; JUMP_ADDDE
; JUMP_ADDHL
; JUMP_UPCASE
; JUMP_UNSETZ
; JUMP_INTODE
; JUMP_FINDCHAR
; JUMP_BLKSEL
; RAMSTART	(where we put our variables in RAM)

; *** Variables ***

; A bool flag indicating that we're on first pass. When we are, we don't care
; about actual output, but only about the length of each upcode. This means
; that when we parse instructions and directive that error out because of a
; missing symbol, we don't error out and just write down a dummy value.
.equ	ZASM_FIRST_PASS	RAMSTART
.equ	ZASM_RAMEND	ZASM_FIRST_PASS+1

; *** Code ***
jp	zasmMain

#include "util.asm"
.equ	IO_RAMSTART	ZASM_RAMEND
#include "io.asm"
#include "tok.asm"
#include "parse.asm"
#include "instr.asm"
.equ	DIREC_RAMSTART	IO_RAMEND
#include "directive.asm"
.equ	SYM_RAMSTART	DIREC_RAMEND
#include "symbol.asm"

; Read file through blockdev ID in H and outputs its upcodes through blockdev
; ID in L.
zasmMain:
	ld	a, h
	ld	de, IO_IN_GETC
	call	JUMP_BLKSEL
	ld	a, l
	ld	de, IO_OUT_GETC
	call	JUMP_BLKSEL
	; First pass
	ld	a, 1
	ld	(ZASM_FIRST_PASS), a
	call	zasmParseFile
	ret	nz
	; Second pass
	call	ioRewind
	xor	a
	ld	(ZASM_FIRST_PASS), a
	call	zasmParseFile
	ret

; Sets Z according to whether we're in first pass.
zasmIsFirstPass:
	ld	a, (ZASM_FIRST_PASS)
	cp	1
	ret

; Increase (curOutputOffset) by A
incOutputOffset:
	push	de
	ld	de, (curOutputOffset)
	call	JUMP_ADDDE
	ld	(curOutputOffset), de
	pop	de
	ret

zasmParseFile:
	ld	hl, 0
	ld	(curOutputOffset), hl
.loop:
	call	ioReadLine
	or	a		; is A 0?
	ret	z		; We have EOF
	call	parseLine
	ret	nz		; error
	jr	.loop

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
	ld	b, a		; save output byte count
	call	incOutputOffset
	call	zasmIsFirstPass
	jr	z, .success		; first pass, nothing to write
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
	or	a		; cp 0
	jr	z, .success	; if zero, shortcut through
	ld	b, a		; save output byte count
	call	incOutputOffset
	call	zasmIsFirstPass
	jr	z, .success		; first pass, nothing to write
	ld	hl, direcData
.loopDirec:
	ld	a, (hl)
	call	ioPutC
	inc	hl
	djnz	.loopDirec
	jr	.success
.label:
	call	zasmIsFirstPass
	jr	nz, .success		; not in first pass? nothing to do
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
