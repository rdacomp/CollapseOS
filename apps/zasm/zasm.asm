#include "user.inc"

; *** Consts ***
ARGSPEC_SINGLE_CNT	.equ	7
ARGSPEC_TBL_CNT	.equ	12

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
	call	readWord
	call	toWord
	jr	nz, .end
	ld	de, curArg2
	call	readWord
.end:
	pop	de
	ret

; match argument string at (HL) with argspec A.
; Set Z/NZ on match
matchArg:
	push	bc
	push	de
	push	ix

	cp	0
	jr	z, .matchnone
	; Let's see if our argspec is a "single" one.
	ex	hl, de		; For "simple" cmp, we don't need HL. But we'll
				; need it later.
	ld	hl, argspecsSingle
	ld	bc, ARGSPEC_SINGLE_CNT
.loop1:
	cpi
	jr	z, .matchsingle		; our argspec in the "single" list
	jp	po, .loop1end
	jr	.loop1
.loop1end:
	; Not a "single" arg. Do the real thing then.
	ex	hl, de		; now we need HL back...
	ld	de, argspecTbl
	ld	b, ARGSPEC_TBL_CNT
.loop2:
	ld	ixl, a
	ld	a, (de)
	cp	ixl
	jr	z, .found		; got it!
	ld	a, 5
	call	JUMP_ADDDE
	ld	a, ixl
	djnz	.loop2
	; exhausted? we have a problem os specifying a wrong argspec. This is
	; an internal consistency error.
	jr	.end
.found:
	; found the matching argspec row. Let's compare the strings now.
	inc	de	; the string starts on the 2nd byte of the row
	ld	a, 4
	call	JUMP_STRNCMP	; Z is set
	jr	.end

.matchsingle:
	; single match is easy: compare A with (HL). They must be equal.
	ex	hl, de
	ld	b, a
	ld	a, (hl)
	cp	b	; Z set if A == B
	jr	.end

.matchnone:
	ld	a, (hl)
	cp	0	; arg must be null to match
.end:
	pop	ix
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
	ld	hl, curArg1
	ld	a, (ix+4)
	call	matchArg
	jr	nz, .end
	ld	hl, curArg2
	ld	a, (ix+5)
	call	matchArg
.end:
	pop	ix
	pop	hl
	ret

; Parse line at (HL) and write resulting opcode(s) in (DE). Returns the number
; of bytes written in A.
parseLine:
	call	readLine
	push	de
	ld	de, instTBlPrimary
.loop:
	ld	a, (de)
	cp	0
	jr	z, .nomatch	; we reached last entry
	call	matchPrimaryRow
	jr	z, .match
	ld	a, 7
	call	JUMP_ADDDE
	jr	.loop

.nomatch:
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
; constant (no group code to insert).
; That doesn't mean that they don't take any argument though. For example,
; "DEC IX" leads to a special upcode. These kind of constants are indicated
; as a single byte to save space. Meaning:
;
; All single char registers (A/B/C etc) -> themselves
; HL -> h
; (HL) -> l
; DE -> d
; (DE) -> e
; BC -> b
; (BC) -> c
; IX -> X
; (IX) -> x
; IY -> Y
; (IY) -> y
; AF -> a
; AF' -> f
; SP -> s
; (SP) -> p
; None -> 0
;
; This is a sorted list of "primary" (single byte) instructions along with
; metadata
; 4 bytes for the name (fill with zero)
; 1 byte for arg constant
; 1 byte for 2nd arg constant
; 1 byte for upcode
instTBlPrimary:
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
	.db 0

; *** Variables ***
; enough space for 4 chars and a null
curWord:
	.db	0, 0, 0, 0, 0
curArg1:
	.db	0, 0, 0, 0, 0
curArg2:
	.db	0, 0, 0, 0, 0

