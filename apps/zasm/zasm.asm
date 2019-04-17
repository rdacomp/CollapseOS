#include "user.inc"

; *** Consts ***
ARGSPEC_SINGLE_CNT	.equ	7
ARGSPEC_TBL_CNT		.equ	12
INSTR_TBL_PRIMARYC_CNT	.equ	25

; *** Code ***
.org	USER_CODE
call	parseLine
ld	b, 0
ld	c, a	; written bytes
ret

; Sets Z is A is ';', CR, LF, or null.
isLineEnd:
	cp	';'
	ret	z
	cp	0
	ret	z
	cp	0x0d
	ret	z
	cp	0x0a
	ret

; Sets Z is A is ' ' or ','
isSep:
	cp	' '
	ret	z
	cp	','
	ret

; Sets Z is A is ' ', ',', ';', CR, LF, or null.
isSepOrLineEnd:
	call	isSep
	ret	z
	call	isLineEnd
	ret

; read word in (HL) and put it in (DE), null terminated. A is the read
; length. HL is advanced to the next separator char.
readWord:
	push	bc
	ld	b, 4
.loop:
	ld	a, (hl)
	call	isSepOrLineEnd
	jr	z, .success
	call	JUMP_UPCASE
	ld	(de), a
	inc	hl
	inc	de
	djnz	.loop
.success:
	xor	a
	ld	(de), a
	ld	a, 4
	sub	a, b
	jr	.end
.error:
	xor	a
	ld	(de), a
.end:
	pop	bc
	ret

; (HL) being a string, advance it to the next non-sep character.
; Set Z if we could do it before the line ended, reset Z if we couldn't.
toWord:
.loop:
	ld	a, (hl)
	call	isLineEnd
	jr	z, .error
	call	isSep
	jr	nz, .success
	inc	hl
	jr	.loop
.error:
	; we need the Z flag to be unset and it is set now. Let's CP with
	; something it can't be equal to, something not a line end.
	cp	'a'	; Z flag unset
	ret
.success:
	; We need the Z flag to be set and it is unset. Let's compare it with
	; itself to return a set Z
	cp	a
	ret


; Read arg from (HL) into argspec at (DE)
; HL is advanced to the next word. Z is set if there's a next word.
readArg:
	push	de
	ld	de, tmpVal
	call	readWord
	push	hl
	ld	hl, tmpVal
	call	matchArg
	pop	hl
	pop	de
	ld	(de), a
	call	toWord
	ret

; Read line from (HL) into (curWord), (curArg1) and (curArg2)
readLine:
	push	de
	xor	a
	ld	(curWord), a
	ld	(curArg1), a
	ld	(curArg2), a
	ld	de, curWord
	call	readWord
	call	toWord
	jr	nz, .end
	ld	de, curArg1
	call	readArg
	jr	nz, .end
	ld	de, curArg2
	call	readArg
.end:
	pop	de
	ret

; Returns length of string at (HL) in A.
strlen:
	push	bc
	push	hl
	ld	bc, 0
	ld	a, 0	; look for null char
.loop:
	cpi
	jp	z, .found
	jr	.loop
.found:
	; How many char do we have? the (NEG BC)-1, which started at 0 and
	; decreased at each CPI call. In this routine, we stay in the 8-bit
	; realm, so C only.
	ld	a, c
	neg
	dec	a
	pop	hl
	pop	bc
	ret

; find argspec for string at (HL). Returns matching argspec in A.
; Return value 1 holds a special meaning: arg is not empty, but doesn't match
; any argspec (A == 0 means arg is empty). A return value of 1 means an error.
matchArg:
	call	strlen
	cp	0
	ret	z		; empty string? A already has our result: 0

	push	bc
	push	de
	push	hl

	cp	1
	jr	z, .matchsingle	; Arg is one char? We have a "single" type.

	; Not a "single" arg. Do the real thing then.
	ld	de, argspecTbl
	; DE now points the the "argspec char" part of the entry, but what
	; we're comparing in the loop is the string next to it. Let's offset
	; DE by one so that the loop goes through strings.
	inc	de
	ld	b, ARGSPEC_TBL_CNT
.loop1:
	ld	a, 4
	call	JUMP_STRNCMP
	jr	z, .found		; got it!
	ld	a, 5
	call	JUMP_ADDDE
	djnz	.loop1
	; exhausted? we have a problem os specifying a wrong argspec. This is
	; an internal consistency error.
	ld	a, 1
	jr	.end
.found:
	; found the matching argspec row. Our result is one byte left of DE.
	dec	de
	ld	a, (de)
	jr	.end

.matchsingle:
	ld	a, (hl)
	ld	hl, argspecsSingle
	ld	bc, ARGSPEC_SINGLE_CNT
.loop2:
	cpi
	jr	z, .end		; found! our result is already in A. go straight
				; to end.
	jp	po, .loop2notfound
	jr	.loop2
.loop2notfound:
	; something's wrong. error
	ld	a, 1
	jr	.end

.end:
	pop	hl
	pop	de
	pop	bc
	ret

; Compare primary row at (DE) with string at curWord. Sets Z flag if there's a
; match, reset if not.
matchPrimaryRow:
	push	hl
	push	ix
	ld	hl, curWord
	ld	a, 4
	call	JUMP_STRNCMP
	jr	nz, .end
	; name matches, let's see the rest
	ld	ixh, d
	ld	ixl, e
	ld	a, (curArg1)
	cp	(ix+4)
	jr	nz, .end
	ld	a, (curArg2)
	cp	(ix+5)
.end:
	pop	ix
	pop	hl
	ret

; Parse line at (HL) and write resulting opcode(s) in (DE). Returns the number
; of bytes written in A.
parseLine:
	call	readLine
	push	de
	ld	de, instrTBlPrimaryC
	ld	b, INSTR_TBL_PRIMARYC_CNT
.loop:
	ld	a, (de)
	call	matchPrimaryRow
	jr	z, .match
	ld	a, 7
	call	JUMP_ADDDE
	djnz	.loop
	; no match
	xor	a
	pop	de
	ret
.match:
	ld	a, 6	; upcode is on 7th byte
	call	JUMP_ADDDE
	ld	a, (de)
	pop	de
	ld	(de), a
	ld	a, 1
	ret

; In instruction metadata below, argument types arge indicated with a single
; char mnemonic that is called "argspec". This is the table of correspondance.
; Single letters are represented by themselves, so we don't need as much
; metadata.

argspecsSingle:
	.db	"ABCDEHL"

; Format: 1 byte argspec + 4 chars string
argspecTbl:
	.db	'h', "HL", 0, 0
	.db	'l', "(HL)"
	.db	'd', "DE", 0, 0
	.db	'e', "(DE)"
	.db	'b', "BC", 0, 0
	.db	'c', "(BC)"
	.db	'a', "AF", 0, 0
	.db	'f', "AF'", 0
	.db	'x', "(IX)"
	.db	'y', "(IY)"
	.db	's', "SP", 0, 0
	.db	'p', "(SP)"

; This is a list of primary instructions (single upcode) that lead to a
; constant (no group code to insert). Format:
;
; 4 bytes for the name (fill with zero)
; 1 byte for arg constant
; 1 byte for 2nd arg constant
; 1 byte for upcode
instrTBlPrimaryC:
	.db "ADD", 0, 'A', 'h', 0x86		; ADD A, HL
	.db "CCF", 0, 0,   0,   0x3f		; CCF
	.db "CPL", 0, 0,   0,   0x2f		; CPL
	.db "DAA", 0, 0,   0,   0x27		; DAA
	.db "DI",0,0, 0,   0,   0xf3		; DI
	.db "EI",0,0, 0,   0,   0xfb		; EI
	.db "EX",0,0, 'p', 'h', 0xe3		; EX (SP), HL
	.db "EX",0,0, 'a', 'f', 0x08		; EX AF, AF'
	.db "EX",0,0, 'd', 'h', 0xeb		; EX DE, HL
	.db "EXX", 0, 0,   0,   0xd9		; EXX
	.db "HALT",   0,   0,   0x76		; HALT
	.db "INC", 0, 'l', 0,   0x34		; INC (HL)
	.db "JP",0,0, 'l', 0,   0xe9		; JP (HL)
	.db "LD",0,0, 'c', 'A', 0x02		; LD (BC), A
	.db "LD",0,0, 'e', 'A', 0x12		; LD (DE), A
	.db "LD",0,0, 'A', 'c', 0x0a		; LD A, (BC)
	.db "LD",0,0, 'A', 'e', 0x0a		; LD A, (DE)
	.db "LD",0,0, 's', 'h', 0x0a		; LD SP, HL
	.db "NOP", 0, 0,   0,   0x00		; NOP
	.db "RET", 0, 0,   0,   0xc9		; RET
	.db "RLA", 0, 0,   0,   0x17		; RLA
	.db "RLCA",   0,   0,   0x07		; RLCA
	.db "RRA", 0, 0,   0,   0x1f		; RRA
	.db "RRCA",   0,   0,   0x0f		; RRCA
	.db "SCF", 0, 0,   0,   0x37		; SCF

; *** Variables ***
; enough space for 4 chars and a null
curWord:
	.db	0, 0, 0, 0, 0

; Args are 3 bytes: argspec, then values of numerical constants (when that's
; appropriate)
curArg1:
	.db	0, 0, 0
curArg2:
	.db	0, 0, 0

; space for tmp stuff
tmpVal:
	.db	0, 0, 0, 0, 0

