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
; JUMP_INTOHL
; JUMP_FINDCHAR
; JUMP_BLKSEL
; RAMSTART	(where we put our variables in RAM)

; *** Variables ***

; A bool flag indicating that we're on first pass. When we are, we don't care
; about actual output, but only about the length of each upcode. This means
; that when we parse instructions and directive that error out because of a
; missing symbol, we don't error out and just write down a dummy value.
.equ	ZASM_FIRST_PASS	RAMSTART
; The offset where we currently are with regards to outputting opcodes
.equ	ZASM_PC		ZASM_FIRST_PASS+1
.equ	ZASM_RAMEND	ZASM_PC+2

; *** Code ***
jp	zasmMain

#include "util.asm"
.equ	IO_RAMSTART	ZASM_RAMEND
#include "io.asm"
#include "tok.asm"
#include "parse.asm"
#include "expr.asm"
#include "instr.asm"
.equ	DIREC_RAMSTART	IO_RAMEND
#include "directive.asm"
.equ	SYM_RAMSTART	DIREC_RAMEND
#include "symbol.asm"

; Read file through blockdev ID in H and outputs its upcodes through blockdev
; ID in L.
zasmMain:
	; Init I/O
	ld	a, h
	ld	de, IO_IN_GETC
	call	JUMP_BLKSEL
	ld	a, l
	ld	de, IO_OUT_GETC
	call	JUMP_BLKSEL
	; Init modules
	call	ioInit
	call	symInit

	; First pass
	ld	a, 1
	ld	(ZASM_FIRST_PASS), a
	call	zasmParseFile
	ret	nz
	; Second pass
	ld	hl, 0
	call	ioSeek
	xor	a
	ld	(ZASM_FIRST_PASS), a
	call	zasmParseFile
	ret

; Sets Z according to whether we're in first pass.
zasmIsFirstPass:
	ld	a, (ZASM_FIRST_PASS)
	cp	1
	ret

; Increase (ZASM_PC) by A
incOutputOffset:
	push	de
	ld	de, (ZASM_PC)
	call	JUMP_ADDDE
	ld	(ZASM_PC), de
	pop	de
	ret

; Repeatedly reads lines from IO, assemble them and spit the binary code in
; IO. Z is set on success, unset on error. DE contains the last line number to
; be read (first line is 1).
zasmParseFile:
	ld	de, 0
	ld	(ZASM_PC), de
.loop:
	inc	de
	call	parseLine
	ret	nz		; error
	ld	a, b		; TOK_*
	cp	TOK_EOF
	ret	z		; if EOF, return now with success
	jr	.loop

; Parse next token and accompanying args (when relevant) in I/O, write the
; resulting opcode(s) through ioPutC and increases (ZASM_PC) by the number of
; bytes written. BC is set to the result of the call to tokenize.
; Sets Z if parse was successful, unset if there was an error. EOF is not an
; error.
parseLine:
	call	tokenize
	ld	a, b		; TOK_*
	cp	TOK_INSTR
	jp	z, _parseInstr
	cp	TOK_DIRECTIVE
	jp	z, _parseDirec
	cp	TOK_LABEL
	jr	z, _parseLabel
	cp	TOK_EOF
	ret			; Z is correct. If EOF, Z is set and not an
				; error, otherwise, it means bad token and
				; errors out.

_parseInstr:
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
	; continue to success
.success:
	xor	a		; ensure Z
	ret
.error:
	call	JUMP_UNSETZ
	ret

_parseDirec:
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
	; continue to success
.success:
	xor	a		; ensure Z
	ret

_parseLabel:
	; The string in (scratchpad) is a label with its trailing ':' removed.
	ld	hl, scratchpad
	call	zasmIsFirstPass
	jr	z, .registerLabel	; When we encounter a label in the first
					; pass, we register it in the symbol
					; list
	; When we're not in the first pass, we set the context (if label is not
	; local) to that label.
	call	symIsLabelLocal
	jr	z, .success		; local? don't set context
	call	symSetContext
	jr	z, .success
	; NZ? this means that (HL) couldn't be found in symbol list. Weird
	jr	.error
.registerLabel:
	ld	de, (ZASM_PC)
	call	symRegister
	jr	nz, .error
	; continue to .success
.success:
	xor	a		; ensure Z
	ret
.error:
	call	JUMP_UNSETZ
	ret
