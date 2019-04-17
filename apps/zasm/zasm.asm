#include "user.inc"

; *** Consts ***
; Number of rows in the argspec table
ARGSPEC_TBL_CNT		.equ	27
; Number of rows in the primary instructions table
INSTR_TBLP_CNT		.equ	74
; size in bytes of each row in the primary instructions table
INSTR_TBLP_ROWSIZE	.equ	8

; *** Code ***
.org	USER_CODE
call	parseLine
ld	b, 0
ld	c, a	; written bytes
ret

unsetZ:
	push	bc
	ld	b, a
	inc	b
	cp	b
	pop	bc
	ret

; run RLA the number of times specified in B
rlaX:
	; first, see if B == 0 to see if we need to bail out
	inc	b
	dec	b
	ret	z	; Z flag means we had B = 0
.loop:	rla
	djnz	.loop
	ret

; If string at (HL) starts with ( and ends with ), "enter" into the parens
; (advance HL and put a null char at the end of the string) and set Z.
; Otherwise, do nothing and reset Z.
enterParens:
	ld	a, (hl)
	cp	'('
	ret	nz		; nothing to do
	push	hl
	ld	a, 0	; look for null char
	; advance until we get null
.loop:
	cpi
	jp	z, .found
	jr	.loop
.found:
	dec	hl	; cpi over-advances. go back to null-char
	dec	hl	; looking at the last char before null
	ld	a, (hl)
	cp	')'
	jr	nz, .doNotEnter
	; We have parens. While we're here, let's put a null
	xor	a
	ld	(hl), a
	pop	hl	; back at the beginning. Let's advance.
	inc	hl
	cp	a	; ensure Z
	ret		; we're good!
.doNotEnter:
	pop	hl
	call	unsetZ
	ret

; Checks whether A is 'N' or 'M'
checkNOrM:
	cp	'N'
	ret	z
	cp	'M'
	ret

; Parse the decimal char at A and extract it's 0-9 numerical value. Put the
; result in A.
;
; On success, the carry flag is reset. On error, it is set.
parseDecimal:
	; First, let's see if we have an easy 0-9 case
	cp	'0'
	ret	c	; if < '0', we have a problem
	cp	'9'+1
	; We are in the 0-9 range
	sub	a, '0'		; C is clear
	ret

; Parses the string at (HL) and returns the 16-bit value in IX.
; As soon as the number doesn't fit 16-bit any more, parsing stops and the
; number is invalid. If the number is valid, Z is set, otherwise, unset.
; If (HL) contains a number inside parens, we properly enter into it.
; Upon successful return, A is set to 'N' for a parens-less number, 'M' for
; a number inside parens.
parseNumber:
	push	hl
	push	de
	push	bc

	; Let's see if we have parens and already set the A result in B.
	ld	b, 'N'		; if no parens
	call	enterParens
	jr	nz, .noparens
	ld	b, 'M'		; we have parens and entered it.
.noparens:
	ld	ix, 0
.loop:
	ld	a, (hl)
	cp	0
	jr	z, .end	; success!
	call	parseDecimal
	jr	c, .error

	; Now, let's add A to IX. First, multiply by 10.
	ld	d, ixh	; we need a copy of the initial copy for later
	ld	e, ixl
	add	ix, ix	; x2
	add	ix, ix	; x4
	add	ix, ix	; x8
	add	ix, de	; x9
	add	ix, de	; x10
	add	a, ixl
	jr	nc, .nocarry
	inc	ixh
.nocarry:
	ld	ixl, a

	; We didn't bother checking for the C flag at each step because we
	; check for overflow afterwards. If ixh < d, we overflowed
	ld	a, ixh
	cp	d
	jr	c, .error	; carry is set? overflow

	inc	hl
	jr	.loop

.error:
	call	unsetZ
.end:
	ld	a, b
	pop	bc
	pop	de
	pop	hl
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

; read word in (HL) and put it in (DE), null terminated, for a maximum of A
; characters. As a result, A is the read length. HL is advanced to the next
; separator char.
readWord:
	push	bc
	ld	b, a
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
	ld	de, tmpBuf
	ld	a, 6
	call	readWord
	push	hl
	ld	hl, tmpBuf
	call	parseArg
	pop	hl
	pop	de
	ld	(de), a
	; When A is a number, IX is set with the value of that number. Because
	; We don't use the space allocated to store those numbers in any other
	; occasion, we store IX there unconditonally, LSB first.
	inc	de
	ld	a, ixl
	ld	(de), a
	inc	de
	ld	a, ixh
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
	ld	a, 4
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
; Return value 0xff holds a special meaning: arg is not empty, but doesn't match
; any argspec (A == 0 means arg is empty). A return value of 0xff means an
; error.
;
; If the parsed argument is a number constant, 'N' is returned and IX contains
; the value of that constant.
parseArg:
	call	strlen
	cp	0
	ret	z		; empty string? A already has our result: 0

	push	bc
	push	de
	push	hl

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

	; We exhausted the argspecs. Let's see if it's a number. This sets
	; A to 'N' or 'M'
	call	parseNumber
	jr	z, .end		; Alright, we have a parsed number in IX. We're
				; done.
	; not a number
	ld	a, 0xff
	jr	.end
.found:
	; found the matching argspec row. Our result is one byte left of DE.
	dec	de
	ld	a, (de)
.end:
	pop	hl
	pop	de
	pop	bc
	ret

; Returns, with Z, whether A is a groupId
isGroupId:
	cp	0xc	; max group id + 1
	jr	nc, .notgroup	; >= 0xc? not a group
	cp	0
	jr	z, .notgroup	; 0? not supposed to happen. something's wrong.
	; A is a group. ensure Z is set
	cp	a
	ret
.notgroup:
	call	unsetZ
	ret

; Find argspec A in group id H.
; Set Z according to whether we found the argspec
; If found, the value in A is the argspec value in the group (its index).
findInGroup:
	push	bc
	push	hl

	cp	0	; is our arg empty? If yes, we have nothing to do
	jr	z, .notfound

	push	af
	ld	a, h
	cp	0xa
	jr	z, .specialGroupCC
	cp	0xb
	jr	z, .specialGroupABCDEHL
	pop	af
	; regular group
	push	de
	ld	de, argGrpTbl
	; group ids start at 1. decrease it, then multiply by 4 to have a
	; proper offset in argGrpTbl
	dec	h
	push	af
	ld	a, h
	rla
	rla
	call	JUMP_ADDDE	; At this point, DE points to our group
	pop	af
	ex	hl, de		; And now, HL points to the group
	pop	de

	ld	bc, 4
	jr	.find

.specialGroupCC:
	ld	hl, argGrpCC
	jr	.specialGroupEnd
.specialGroupABCDEHL:
	ld	hl, argGrpABCDEHL
.specialGroupEnd:
	pop	af	; from the push af just before the special group check
	ld	bc, 8

.find:
	; This part is common to regular and special group. We expect HL to
	; point to the group and BC to contain its length.
	push	bc		; save the start value loop index so we can sub
.loop:
	cpi
	jr	z, .found
	jp	po, .notfound
	jr	.loop
.found:
	; we found our result! Now, what we want to put in A is the index of
	; the found argspec.
	pop	hl	; we pop from the "push bc" above. L is now 4 or 8
	ld	a, l
	sub	c
	dec	a	; cpi DECs BC even when there's a match, so C == the
			; number of iterations we've made. But our index is
			; zero-based (1 iteration == 0 index).
	cp	a	; ensure Z is set
	jr	.end
.notfound:
	pop	bc	; from the push bc in .find
	call	unsetZ
.end:
	pop	hl
	pop	bc
	ret

; Compare argspec from instruction table in A with argument in (HL).
; For constant args, it's easy: if A == (HL), it's a success.
; If it's not this, then we check if it's a numerical arg.
; If A is a group ID, we do something else: we check that (HL) exists in the
; groupspec (argGrpTbl)
matchArg:
	cp	a, (hl)
	ret	z
	; not an exact match, let's check for numerical constants.
	call	JUMP_UPCASE
	call	checkNOrM
	jr	z, .expectsNumber
	jr	.notNumber
.expectsNumber:
	; Our argument is a number N or M. Never a lower-case version. At this
	; point in the processing, we don't care about whether N or M is upper,
	; we do truncation tests later. So, let's just perform the same == test
	; but in a case-insensitive way instead
	cp	a, (hl)
	ret			; whether we match or not, the result of Z is
				; the good one.
.notNumber:
	; A bit of a delicate situation here: we want A to go in H but also
	; (HL) to go in A. If not careful, we overwrite each other. EXX is
	; necessary to avoid invoving other registers.
	push	hl
	exx
	ld	h, a
	push	hl
	exx
	ld	a, (hl)
	pop	hl
	call	findInGroup
	pop	hl
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
;
; Overwrites IX
parseLine:
	call	readLine
	; Check whether we have errors. We don't do any parsing if we do.
	ld	a, (curArg1)
	cp	0xff
	jr	z, .error
	ret	z
	ld	a, (curArg2)
	cp	0xff
	jr	nz, .noerror
.error:
	ld	a, 0
	ret
.noerror:
	push	de
	ld	de, instrTBlPrimary
	ld	b, INSTR_TBLP_CNT
.loop:
	ld	a, (de)
	call	matchPrimaryRow
	jr	z, .match
	ld	a, INSTR_TBLP_ROWSIZE
	call	JUMP_ADDDE
	djnz	.loop
	; no match
	xor	a
	pop	de
	ret
.match:
	; We have our matching instruction row. We're getting pretty near our
	; goal here!
	; First, let's go in IX mode. It's easier to deal with offsets here.
	ld	ixh, d
	ld	ixl, e
	; First, let's see if we're dealing with a group here
	ld	a, (ix+4)	; first argspec
	call	isGroupId
	jr	z, .firstArgIsGroup
	; First arg not a group. Maybe second is?
	ld	a, (ix+5)	; 2nd argspec
	call	isGroupId
	jr	nz, .notgroup
	; Second arg is group
	ld	de, curArg2
	jr	.isGroup
.firstArgIsGroup:
	ld	de, curArg1
.isGroup:
	; A is a group, good, now let's get its value. DE is pointing to
	; the argument.
	push	hl
	ld	h, a
	ld	a, (de)
	call	findInGroup	; we don't check for match, it's supposed to
				; always match. Something is very wrong if it
				; doesn't
	; Now, we have our arg "group value" in A. Were going to need to
	; displace it left by the number of steps specified in the table.
	push	bc
	push	af
	ld	a, (ix+6)	; displacement bit
	and	a, 0xf		; we only use the lower nibble.
	ld	b, a
	pop	af
	call	rlaX
	pop	bc

	; At this point, we have a properly displaced value in A. We'll want
	; to OR it with the opcode.
	or	(ix+7)		; upcode
	pop	hl

	; Success!
	jr	.writeFirstOpcode
.notgroup:
	; not a group? easy as pie: we return the opcode directly.
	ld	a, (ix+7)	; upcode is on 8th byte
.writeFirstOpcode:
	; At the end, we have our final opcode in A!
	pop	de
	ld	(de), a

	; Good, we are probably finished here for many primary opcodes. However,
	; some primary opcodes take 8 or 16 bit constants as an argument and
	; if that's the case here, we need to write it too.
	; We still have our instruction row in IX. Let's revisit it.
	push	hl	; we use HL to point to the currently read arg
	ld	a, (ix+4)	; first argspec
	ld	hl, curArg1
	call	checkNOrM
	jr	z, .withWord
	cp	'n'
	jr	z, .withByte
	cp	'm'
	jr	z, .withByte
	ld	a, (ix+5)	; second argspec
	ld	hl, curArg2
	call	checkNOrM
	jr	z, .withWord
	cp	'n'
	jr	z, .withByte
	cp	'm'
	jr	z, .withByte
	; nope, no number, aright, only one opcode
	ld	a, 1
	jr	.end
.withByte:
	; verify that the MSB in argument is zero
	inc	hl
	inc	hl	; MSB is 2nd byte
	ld	a, (hl)
	dec	hl	; HL now points to LSB
	cp	0
	jr	nz, .numberTruncated
	; HL points to our number
	; one last thing to check. Is the 7th bit on the displacement value set?
	; if yes, we have to decrease our value by 2. Uses for djnz and jr.
	bit	7, (ix+6)
	jr	z, .skipDecrease
	; Yup, it's set.
	dec	(hl)
	dec	(hl)
.skipDecrease:
	inc	de
	ldi
	ld	a, 2
	jr	.end

.withWord:
	inc	de
	inc	hl	; HL now points to LSB
	; Clear to proceed. HL already points to our number
	ldi	; LSB written, we point to MSB now
	ldi	; MSB written
	ld	a, 3
	jr	.end
.numberTruncated:
	; problem: not zero, so value is truncated. error
	xor	a
.end:
	pop	hl
	ret


; In instruction metadata below, argument types arge indicated with a single
; char mnemonic that is called "argspec". This is the table of correspondance.
; Single letters are represented by themselves, so we don't need as much
; metadata.
; Special meaning:
; 0 : no arg
; 1-10 : group id (see Groups section)
; 0xff: error

; Format: 1 byte argspec + 4 chars string
argspecTbl:
	.db	'A', "A", 0, 0, 0
	.db	'B', "B", 0, 0, 0
	.db	'C', "C", 0, 0, 0
	.db	'D', "D", 0, 0, 0
	.db	'E', "E", 0, 0, 0
	.db	'H', "H", 0, 0, 0
	.db	'L', "L", 0, 0, 0
	.db	'h', "HL", 0, 0
	.db	'l', "(HL)"
	.db	'd', "DE", 0, 0
	.db	'e', "(DE)"
	.db	'b', "BC", 0, 0
	.db	'c', "(BC)"
	.db	'a', "AF", 0, 0
	.db	'f', "AF'", 0
	.db	'x', "(IX)"		; always come with displacement
	.db	'y', "(IY)"		; with JP
	.db	's', "SP", 0, 0
	.db	'p', "(SP)"
; we also need argspecs for the condition flags
	.db	'Z', "Z", 0, 0, 0
	.db	'z', "NZ",   0, 0
	.db	'^', "C", 0, 0, 0
	.db	'=', "NC",   0, 0
	.db	'+', "P", 0, 0, 0
	.db	'-', "M", 0, 0, 0
	.db	'1', "PO",   0, 0
	.db	'2', "PE",   0, 0

; argspecs not in the list:
; n -> N
; N -> NN
; m -> (N)  (running out of mnemonics. 'm' for 'memory pointer')
; M -> (NN)

; Groups
; Groups are specified by strings of argspecs. To facilitate jumping to them,
; we have a fixed-sized table. Because most of them are 2 or 4 bytes long, we
; have a table that is 4 in size to minimize consumed space. We treat the two
; groups that take 8 bytes in a special way.
;
; The table below is in order, starting with group 0x01
argGrpTbl:
	.db	"bdha"		; 0x01
	.db	"Zz^="		; 0x02
	.db	"bdhs"		; 0x03

argGrpCC:
	.db	"Zz^=+-12"	; 0xa
argGrpABCDEHL:
	.db	"BCDEHL_A"	; 0xb

; This is a list of primary instructions (single upcode) that lead to a
; constant (no group code to insert). Format:
;
; 4 bytes for the name (fill with zero)
; 1 byte for arg constant
; 1 byte for 2nd arg constant
; 1 byte displacement for group arguments + flags
; 1 byte for upcode
;
; The displacement bit is split in 2 nibbles: lower nibble is the displacement
; value, upper nibble is for flags. There is one flag currently, on bit 7, that
; indicates that the numerical argument is of the 'e' type and has to be
; decreased by 2 (djnz, jr).

instrTBlPrimary:
	.db "ADC", 0, 'A', 'h', 0, 0x8e		; ADC A, HL
	.db "ADC", 0, 'A', 0xb, 0, 0b10001000	; ADC A, r
	.db "ADC", 0, 'A', 'n', 0, 0xce		; ADC A, n
	.db "ADD", 0, 'A', 'h', 0, 0x86		; ADD A, HL
	.db "ADD", 0, 'A', 0xb, 0, 0b10000000	; ADD A, r
	.db "ADD", 0, 'A', 'n', 0, 0xc6 	; ADD A, n
	.db "ADD", 0, 'h', 0x3, 4, 0b00001001 	; ADD HL, ss
	.db "AND", 0, 'l', 0,   0, 0xa6		; AND (HL)
	.db "AND", 0, 0xa, 0,   0, 0b10100000	; AND r
	.db "AND", 0, 'n', 0,   0, 0xe6		; AND n
	.db "CALL",   0xa, 'N', 3, 0b11000100	; CALL cc, NN
	.db "CALL",   'N', 0,   0, 0xcd		; CALL NN
	.db "CCF", 0, 0,   0,   0, 0x3f		; CCF
	.db "CP",0,0, 'l', 0,   0, 0xbe		; CP (HL)
	.db "CP",0,0, 0xb, 0,   0, 0b10111000	; CP r
	.db "CP",0,0, 'n', 0,   0, 0xfe		; CP n
	.db "CPL", 0, 0,   0,   0, 0x2f		; CPL
	.db "DAA", 0, 0,   0,   0, 0x27		; DAA
	.db "DI",0,0, 0,   0,   0, 0xf3		; DI
	.db "DEC", 0, 'l', 0,   0, 0x35		; DEC (HL)
	.db "DEC", 0, 0xb, 0,   3, 0b00000101	; DEC r
	.db "DEC", 0, 0x3, 0,   4, 0b00001011	; DEC s
	.db "DJNZ",   'n', 0,0x80, 0x10		; DJNZ e
	.db "EI",0,0, 0,   0,   0, 0xfb		; EI
	.db "EX",0,0, 'p', 'h', 0, 0xe3		; EX (SP), HL
	.db "EX",0,0, 'a', 'f', 0, 0x08		; EX AF, AF'
	.db "EX",0,0, 'd', 'h', 0, 0xeb		; EX DE, HL
	.db "EXX", 0, 0,   0,   0, 0xd9		; EXX
	.db "HALT",   0,   0,   0, 0x76		; HALT
	.db "IN",0,0, 'A', 'm', 0, 0xdb		; IN A, (n)
	.db "INC", 0, 'l', 0,   0, 0x34		; INC (HL)
	.db "INC", 0, 0xb, 0,   3, 0b00000100	; INC r
	.db "INC", 0, 0x3, 0,   4, 0b00000011	; INC s
	.db "JP",0,0, 'l', 0,   0, 0xe9		; JP (HL)
	.db "JP",0,0, 'N', 0,   0, 0xc3		; JP NN
	.db "JR",0,0, 'n', 0,0x80, 0x18		; JR e
	.db "JR",0,0,'^','n',0x80, 0x38		; JR C, e
	.db "JR",0,0,'=','n',0x80, 0x30		; JR NC, e
	.db "JR",0,0,'Z','n',0x80, 0x28		; JR Z, e
	.db "JR",0,0,'z','n',0x80, 0x20		; JR NZ, e
	.db "LD",0,0, 'c', 'A', 0, 0x02		; LD (BC), A
	.db "LD",0,0, 'e', 'A', 0, 0x12		; LD (DE), A
	.db "LD",0,0, 'A', 'c', 0, 0x0a		; LD A, (BC)
	.db "LD",0,0, 'A', 'e', 0, 0x0a		; LD A, (DE)
	.db "LD",0,0, 's', 'h', 0, 0x0a		; LD SP, HL
	.db "LD",0,0, 'l', 0xb, 0, 0b01110000	; LD (HL), r
	.db "LD",0,0, 0xb, 'l', 3, 0b01000110	; LD r, (HL)
	.db "LD",0,0, 'l', 'n', 0, 0x36		; LD (HL), n
	.db "LD",0,0, 0xb, 'n', 3, 0b00000110	; LD r, (HL)
	.db "LD",0,0, 0x3, 'N', 4, 0b00000001	; LD dd, n
	.db "LD",0,0, 'M', 'A', 0, 0x32		; LD (NN), A
	.db "LD",0,0, 'A', 'M', 0, 0x3a		; LD A, (NN)
	.db "LD",0,0, 'M', 'h', 0, 0x22		; LD (NN), HL
	.db "LD",0,0, 'h', 'M', 0, 0x2a		; LD HL, (NN)
	.db "NOP", 0, 0,   0,   0, 0x00		; NOP
	.db "OR",0,0, 'l', 0,   0, 0xb6		; OR (HL)
	.db "OR",0,0, 0xb, 0,   0, 0b10110000	; OR r
	.db "OUT", 0, 'm', 'A', 0, 0xd3		; OUT (n), A
	.db "POP", 0, 0x1, 0,   4, 0b11000001	; POP qq
	.db "PUSH",   0x1, 0,   4, 0b11000101	; PUSH qq
	.db "RET", 0, 0xa, 0,   3, 0b11000000	; RET cc
	.db "RET", 0, 0,   0,   0, 0xc9		; RET
	.db "RLA", 0, 0,   0,   0, 0x17		; RLA
	.db "RLCA",   0,   0,   0, 0x07		; RLCA
	.db "RRA", 0, 0,   0,   0, 0x1f		; RRA
	.db "RRCA",   0,   0,   0, 0x0f		; RRCA
	.db "SBC", 0, 'A', 'h', 0, 0x9e		; SBC A, HL
	.db "SBC", 0, 'A', 0xb, 0, 0b10011000	; SBC A, r
	.db "SCF", 0, 0,   0,   0, 0x37		; SCF
	.db "SUB", 0, 'A', 'h', 0, 0x96		; SUB A, HL
	.db "SUB", 0, 'A', 0xb, 0, 0b10010000	; SUB A, r
	.db "SUB", 0, 'n', 0,   0, 0xd6 	; SUB n
	.db "XOR", 0, 'l', 0,   0, 0xae		; XOR (HL)
	.db "XOR", 0, 0xb, 0,   0, 0b10101000	; XOR r


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
tmpBuf:
	.fill	0x20

