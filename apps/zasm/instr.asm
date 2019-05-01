; *** Consts ***
; Number of rows in the argspec table
ARGSPEC_TBL_CNT		.equ	31
; Number of rows in the primary instructions table
INSTR_TBL_CNT		.equ	135
; size in bytes of each row in the primary instructions table
INSTR_TBL_ROWSIZE	.equ	6
; Instruction IDs They correspond to the index of the table in instrNames
I_ADC	.equ	0x00
I_ADD	.equ	0x01
I_AND	.equ	0x02
I_BIT	.equ	0x03
I_CALL	.equ	0x04
I_CCF	.equ	0x05
I_CP	.equ	0x06
I_CPD	.equ	0x07
I_CPDR	.equ	0x08
I_CPI	.equ	0x09
I_CPIR	.equ	0x0a
I_CPL	.equ	0x0b
I_DAA	.equ	0x0c
I_DEC	.equ	0x0d
I_DI	.equ	0x0e
I_DJNZ	.equ	0x0f
I_EI	.equ	0x10
I_EX	.equ	0x11
I_EXX	.equ	0x12
I_HALT	.equ	0x13
I_IM	.equ	0x14
I_IN	.equ	0x15
I_INC	.equ	0x16
I_IND	.equ	0x17
I_INDR	.equ	0x18
I_INI	.equ	0x19
I_INIR	.equ	0x1a
I_JP	.equ	0x1b
I_JR	.equ	0x1c
I_LD	.equ	0x1d
I_LDD	.equ	0x1e
I_LDDR	.equ	0x1f
I_LDI	.equ	0x20
I_LDIR	.equ	0x21
I_NEG	.equ	0x22
I_NOP	.equ	0x23
I_OR	.equ	0x24
I_OTDR	.equ	0x25
I_OTIR	.equ	0x26
I_OUT	.equ	0x27
I_POP	.equ	0x28
I_PUSH	.equ	0x29
I_RET	.equ	0x2a
I_RLA	.equ	0x2b
I_RLCA	.equ	0x2c
I_RRA	.equ	0x2d
I_RRCA	.equ	0x2e
I_SBC	.equ	0x2f
I_SCF	.equ	0x30
I_SUB	.equ	0x31
I_XOR	.equ	0x32

; Checks whether A is 'N' or 'M'
checkNOrM:
	cp	'N'
	ret	z
	cp	'M'
	ret

; Checks whether A is 'n', 'm', 'x' or 'y'
checknmxy:
	cp	'n'
	ret	z
	cp	'm'
	ret	z
	cp	'x'
	ret	z
	cp	'y'
	ret

; Reads string in (HL) and returns the corresponding ID (I_*) in A. Sets Z if
; there's a match.
getInstID:
	push	bc
	push	de
	ld	b, I_XOR+1	; I_XOR is the last
	ld	c, 4
	ld	de, instrNames
	call	findStringInList
	pop	de
	pop	bc
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
parseNumber:
	push	hl
	push	de
	push	bc

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
	call	JUMP_UNSETZ
.end:
	pop	bc
	pop	de
	pop	hl
	ret

; Parse the string at (HL) and check if it starts with IX+, IY+, IX- or IY-.
; Sets Z if yes, unset if no.
parseIXY:
	push	hl
	ld	a, (hl)
	cp	'I'
	jr	nz, .end	; Z already unset
	inc	hl
	ld	a, (hl)
	cp	'X'
	jr	z, .match1
	cp	'Y'
	jr	z, .match1
	jr	.end		; Z already unset
.match1:
	; Alright, we have IX or IY. Let's see if we have + or - next.
	inc	hl
	ld	a, (hl)
	cp	'+'
	jr	z, .end		; Z is already set
	cp	'-'
	; The value of Z at this point is our final result
.end:
	pop	hl
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

	; We always initialize IX to zero so that non-numerical args end up with
	; a clean zero.
	ld	ix, 0

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

	; We exhausted the argspecs. Let's see if we're inside parens.
	call	enterParens
	jr	z, .withParens
	; (HL) has no parens
	call	parseNumber
	jr	nz, .nomatch
	; We have a proper number in no parens. Number in IX.
	ld	a, 'N'
	jr	.end
.withParens:
	ld	c, 'M'		; C holds the argspec type until we reach
				; .numberInParens
	; We have parens. First, let's see if we have a (IX+d) type of arg.
	call	parseIXY
	jr	nz, .parseNumberInParens	; not I{X,Y}. just parse number.
	; We have IX+/IY+/IX-/IY-.
	; note: the "-" part isn't supported yet.
	inc	hl	; (HL) now points to X or Y
	ld	a, (hl)
	inc	hl	; advance HL to the number part
	inc	hl	; this is the number
	cp	'Y'
	jr	nz, .notY
	ld	c, 'y'
	jr	.parseNumberInParens
.notY:
	ld	c, 'x'
.parseNumberInParens:
	call	parseNumber
	jr	nz, .nomatch
	; We have a proper number in parens. Number in IX
	ld	a, c	; M, x, or y
	jr	.end
.nomatch:
	; We get no match
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
	call	JUMP_UNSETZ
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
	jr	nc, .notfound	; > 0xb? not a group
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
	call	JUMP_UNSETZ
.end:
	pop	hl
	pop	bc
	ret

; Compare argspec from instruction table in A with argument in (HL).
; For constant args, it's easy: if A == (HL), it's a success.
; If it's not this, then we check if it's a numerical arg.
; If A is a group ID, we do something else: we check that (HL) exists in the
; groupspec (argGrpTbl). Moreover, we go and write the group's "value" (index)
; in (HL+1). This will save us significant processing later in getUpcode.
; Set Z according to whether we match or not.
matchArg:
	cp	a, (hl)
	ret	z
	; not an exact match. Before we continue: is A zero? Because if it is,
	; we have to stop right here: no match possible.
	cp	0
	jr	nz, .checkIfNumber	; not a zero, we can continue
	; zero, stop here
	call	JUMP_UNSETZ
	ret
.checkIfNumber:
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
	ret	nz
	; we found our group? let's write down its "value" in (HL+1). We hold
	; this value in A at the moment.
	inc	hl
	ld	(hl), a
	dec	hl
	ret

; Compare primary row at (DE) with ID in A. Sets Z flag if there's a match.
matchPrimaryRow:
	push	hl
	push	ix
	ld	ixh, d
	ld	ixl, e
	cp	(ix)
	jr	nz, .end
	; name matches, let's see the rest
	ld	hl, curArg1
	ld	a, (ix+1)
	call	matchArg
	jr	nz, .end
	ld	hl, curArg2
	ld	a, (ix+2)
	call	matchArg
.end:
	pop	ix
	pop	hl
	ret

; *** Special opcodes ***
; The special upcode handling routines below all have the same signature.
; Instruction row is at IX and we're expected to perform the same task as
; getUpcode. The number of bytes, however, must go in C instead of A
; No need to preserve HL, DE, BC and IX: it's handled by getUpcode already.

; Handle like a regular "JP (IX+d)" except that we refuse any displacement: if
; a displacement is specified, we error out.
handleJPIX:
	ld	a, 0xdd
	jr	handleJPIXY
handleJPIY:
	ld	a, 0xfd
handleJPIXY:
	ld	(curUpcode), a
	ld	a, (curArg1+1)
	cp	0		; numerical argument *must* be zero
	jr	nz, .error
	; ok, we're good
	ld	a, 0xe9		; second upcode
	ld	(curUpcode+1), a
	ld	c, 2
	ret
.error:
	xor	c
	ret

; Handle the first argument of BIT. Sets Z if first argument is valid, unset it
; if there's an error.
handleBIT:
	ld	a, (curArg1+1)
	cp	8
	jr	nc, .error	; >= 8? error
	; We're good
	cp	a		; ensure Z
	ret
.error:
	xor	c
	call	JUMP_UNSETZ
	ret

handleBITHL:
	call	handleBIT
	ret	nz		; error
	ld	a, 0xcb		; first upcode
	ld	(curUpcode), a
	ld	a, (curArg1+1)	; 0-7
	ld	b, 3		; displacement
	call	rlaX
	or	0b01000110	; 2nd upcode
	ld	(curUpcode+1), a
	ld	c, 2
	ret

handleBITIX:
	ld	a, 0xdd
	jr	handleBITIXY
handleBITIY:
	ld	a, 0xfd
handleBITIXY:
	ld	(curUpcode), a	; first upcode
	call	handleBIT
	ret	nz		; error
	ld	a, 0xcb		; 2nd upcode
	ld	(curUpcode+1), a
	ld	a, (curArg2+1)	; IXY displacement
	ld	(curUpcode+2), a
	ld	a, (curArg1+1)	; 0-7
	ld	b, 3		; displacement
	call	rlaX
	or	0b01000110	; 4th upcode
	ld	(curUpcode+3), a
	ld	c, 4
	ret

handleBITR:
	call	handleBIT
	ret	nz		; error
	; get group value
	ld	a, (curArg2+1)	; group value
	ld	c, a
	; write first upcode
	ld	a, 0xcb		; first upcode
	ld	(curUpcode), a
	; get bit value
	ld	a, (curArg1+1)	; 0-7
	ld	b, 3		; displacement
	call	rlaX
	; Now we have group value in stack, bit value in A (properly shifted)
	; and we want to OR them together
	or	c		; Now we have our ORed value
	or	0b01000000	; and with the constant value for that byte...
				; we're good!
	ld	(curUpcode+1), a
	ld	c, 2
	ret

handleIM:
	ld	a, (curArg1+1)
	cp	0
	jr	z, .im0
	cp	1
	jr	z, .im1
	cp	2
	jr	z, .im2
	; error
	ld	c, 0
	ret
.im0:
	ld	a, 0x46
	jr	.proceed
.im1:
	ld	a, 0x56
	jr	.proceed
.im2:
	ld	a, 0x5e
.proceed:
	ld	(curUpcode+1), a
	ld	a, 0xed
	ld	(curUpcode), a
	ld	c, 2
	ret

handleLDIXn:
	ld	a, 0xdd
	jr	handleLDIXYn
handleLDIYn:
	ld	a, 0xfd
handleLDIXYn:
	ld	(curUpcode), a
	ld	a, 0x36		; second upcode
	ld	(curUpcode+1), a
	ld	a, (curArg1+1)	; IXY displacement
	ld	(curUpcode+2), a
	ld	a, (curArg2+1)	; N
	ld	(curUpcode+3), a
	ld	c, 4
	ret
.error:
	xor	c
	ret

handleLDIXr:
	ld	a, 0xdd
	jr	handleLDIXYr
handleLDIYr:
	ld	a, 0xfd
handleLDIXYr:
	ld	(curUpcode), a
	ld	a, (curArg2+1)	; group value
	or	0b01110000	; second upcode
	ld	(curUpcode+1), a
	ld	a, (curArg1+1)	; IXY displacement
	ld	(curUpcode+2), a
	ld	c, 3
	ret
.error:
	xor	c
	ret

; Compute the upcode for argspec row at (DE) and arguments in curArg{1,2} and
; writes the resulting upcode in curUpcode. A is the number if bytes written
; to curUpcode (can be zero if something went wrong).
getUpcode:
	push	ix
	push	de
	push	hl
	push	bc
	; First, let's go in IX mode. It's easier to deal with offsets here.
	ld	ixh, d
	ld	ixl, e

	; Are we a "special instruction"?
	bit	5, (ix+3)
	jr	z, .normalInstr		; not set: normal instruction
	; We are a special instruction. Fetch handler (little endian, remember).
	ld	l, (ix+4)
	ld	h, (ix+5)
	call	callHL
	; We have our result written in curUpcode and C is set.
	jp	.end

.normalInstr:
	; we begin by writing our "base upcode", which can be one or two bytes
	ld	a, (ix+4)	; first upcode
	ld	(curUpcode), a
	ld	de, curUpcode	; from this point, DE points to "where we are"
				; in terms of upcode writing.
	inc	de		; make DE point to where we should write next.
	ld	a, (ix+5)	; second upcode
	cp	0		; do we have a second upcode?
	jr	z, .onlyOneUpcode
	; we have two upcodes
	ld	(de), a
	inc	de
.onlyOneUpcode:
	; now, let's see if we're dealing with a group here
	ld	a, (ix+1)	; first argspec
	call	isGroupId
	jr	z, .firstArgIsGroup
	; First arg not a group. Maybe second is?
	ld	a, (ix+2)	; 2nd argspec
	call	isGroupId
	jr	nz, .writeExtraBytes	; not a group? nothing to do. go to
					; next step: write extra bytes
	; Second arg is group
	ld	hl, curArg2
	jr	.isGroup
.firstArgIsGroup:
	ld	hl, curArg1
.isGroup:
	; A is a group, good, now let's get its value. HL is pointing to
	; the argument. Our group value is at (HL+1).
	inc	hl
	ld	a, (hl)
	; Now, we have our arg "group value" in A. Were going to need to
	; displace it left by the number of steps specified in the table.
	push	af
	ld	a, (ix+3)	; displacement bit
	and	a, 0xf		; we only use the lower nibble.
	ld	b, a
	pop	af
	call	rlaX

	; At this point, we have a properly displaced value in A. We'll want
	; to OR it with the opcode.
	; However, we first have to verify whether this ORing takes place on
	; the second upcode or the first.
	bit	6, (ix+3)
	jr	z, .firstUpcode	; not set: first upcode
	or	(ix+5)		; second upcode
	ld	(curUpcode+1), a
	jr	.writeExtraBytes
.firstUpcode:
	or	(ix+4)		; first upcode
	ld	(curUpcode), a
	jr	.writeExtraBytes
.writeExtraBytes:
	; Good, we are probably finished here for many primary opcodes. However,
	; some primary opcodes take 8 or 16 bit constants as an argument and
	; if that's the case here, we need to write it too.
	; We still have our instruction row in IX and we have DE pointing to
	; where we should write next (which could be the second or the third
	; byte of curUpcode).
	ld	a, (ix+1)	; first argspec
	ld	hl, curArg1
	call	checkNOrM
	jr	z, .withWord
	call	checknmxy
	jr	z, .withByte
	ld	a, (ix+2)	; second argspec
	ld	hl, curArg2
	call	checkNOrM
	jr	z, .withWord
	call	checknmxy
	jr	z, .withByte
	; nope, no number, alright, we're finished here
	ld	c, 1
	jr	.computeBytesWritten
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
	bit	7, (ix+3)
	jr	z, .skipDecrease
	; Yup, it's set.
	dec	(hl)
	dec	(hl)
.skipDecrease:
	ldi
	ld	c, 2
	jr	.computeBytesWritten

.withWord:
	inc	hl	; HL now points to LSB
	; Clear to proceed. HL already points to our number
	ldi	; LSB written, we point to MSB now
	ldi	; MSB written
	ld	c, 3
	jr	.computeBytesWritten
.computeBytesWritten:
	; At this point, everything that we needed to write in curUpcode is
	; written an C is 1 if we have no extra byte, 2 if we have an extra
	; byte and 3 if we have an extra word. What we need to do here is check
	; if ix+5 is non-zero and increase C if it is.
	ld	a, (ix+5)
	cp	0
	jr	z, .end		; no second upcode? nothing to do.
	; We have 2 base upcodes
	inc	c
	jr	.end
.numberTruncated:
	; problem: not zero, so value is truncated. error
	xor	c
.end:
	ld	a, c
	pop	bc
	pop	hl
	pop	de
	pop	ix
	ret

; Parse next argument in string (HL) and place it in (DE)
; Sets Z on success, reset on error.
processArg:
	push	de
	call	toWord
	xor	a
	ld	de, scratchpad
	ld	(de), a
	ld	a, 8
	call	readWord
	pop	de
	; Read word is in scratchpad, (DE) is back to initial value, HL is
	; properly advanced. Now, let's push that HL value and replace it with
	; (scratchpad) so that we can parse that arg.
	push	hl
	ld	hl, scratchpad

	call	parseArg
	cp	0xff
	jr	z, .error
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
	cp	a		; ensure Z is set
	jr	.end
.error:
	call	JUMP_UNSETZ
.end:
	pop	hl
	ret

; Parse instruction specified in A (I_* const) with args in (HL) and write
; resulting opcode(s) in (curUpcode). Returns the number of bytes written in A.
parseInstruction:
	push	bc
	push	hl
	push	de
	; A is reused in matchPrimaryRow but that register is way too changing.
	; Let's keep a copy in a more cosy register.
	ld	c, a
	ld	de, curArg1
	call	processArg
	jr	nz, .error
	ld	de, curArg2
	call	processArg
	jr	nz, .error
	; Parsing done, no error, let's move forward to instr row matching!
	ld	de, instrTBl
	ld	b, INSTR_TBL_CNT
.loop:
	ld	a, c			; recall A param
	call	matchPrimaryRow
	jr	z, .match
	ld	a, INSTR_TBL_ROWSIZE
	call	JUMP_ADDDE
	djnz	.loop
	; no match
	xor	a
	jr	.end
.match:
	; We have our matching instruction row. We're getting pretty near our
	; goal here!
	call	getUpcode
	jr	.end
.error:
	xor	a
.end:
	pop	de
	pop	hl
	pop	bc
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
	.db	'k', "(C)", 0
	.db	'D', "D", 0, 0, 0
	.db	'E', "E", 0, 0, 0
	.db	'H', "H", 0, 0, 0
	.db	'L', "L", 0, 0, 0
	.db	'I', "I", 0, 0, 0
	.db	'R', "R", 0, 0, 0
	.db	'h', "HL", 0, 0
	.db	'l', "(HL)"
	.db	'd', "DE", 0, 0
	.db	'e', "(DE)"
	.db	'b', "BC", 0, 0
	.db	'c', "(BC)"
	.db	'a', "AF", 0, 0
	.db	'f', "AF'", 0
	.db	'X', "IX", 0, 0
	.db	'Y', "IY", 0, 0
	.db	'x', "(IX)"		; always come with displacement
	.db	'y', "(IY)"		; with JP
	.db	's', "SP", 0, 0
	.db	'p', "(SP)"
; we also need argspecs for the condition flags
	.db	'Z', "Z", 0, 0, 0
	.db	'z', "NZ",   0, 0
	; C is in conflict with the C register. The situation is ambiguous, but
	; doesn't cause actual problems.
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
	.db	"ZzC="		; 0x02
	.db	"bdhs"		; 0x03
	.db	"bdXs"		; 0x04
	.db	"bdYs"		; 0x05

argGrpCC:
	.db	"zZ=C12+-"	; 0xa
argGrpABCDEHL:
	.db	"BCDEHL_A"	; 0xb

; Each row is 4 bytes wide, fill with zeroes
instrNames:
	.db "ADC", 0
	.db "ADD", 0
	.db "AND", 0
	.db "BIT", 0
	.db "CALL"
	.db "CCF", 0
	.db "CP",0,0
	.db "CPD", 0
	.db "CPDR"
	.db "CPI", 0
	.db "CPIR"
	.db "CPL", 0
	.db "DAA", 0
	.db "DEC", 0
	.db "DI",0,0
	.db "DJNZ"
	.db "EI",0,0
	.db "EX",0,0
	.db "EXX", 0
	.db "HALT"
	.db "IM",0,0
	.db "IN",0,0
	.db "INC", 0
	.db "IND", 0
	.db "INDR"
	.db "INI", 0
	.db "INIR"
	.db "JP",0,0
	.db "JR",0,0
	.db "LD",0,0
	.db "LDD", 0
	.db "LDDR"
	.db "LDI", 0
	.db "LDIR"
	.db "NEG", 0
	.db "NOP", 0
	.db "OR",0,0
	.db "OTDR"
	.db "OTIR"
	.db "OUT", 0
	.db "POP", 0
	.db "PUSH"
	.db "RET", 0
	.db "RLA", 0
	.db "RLCA"
	.db "RRA", 0
	.db "RRCA"
	.db "SBC", 0
	.db "SCF", 0
	.db "SUB", 0
	.db "XOR", 0

; This is a list of all supported instructions. Each row represent a combination
; of instr/argspecs (which means more than one row per instr). Format:
;
; 1 byte for the instruction ID
; 1 byte for arg constant
; 1 byte for 2nd arg constant
; 1 byte displacement for group arguments + flags
; 2 bytes for upcode (2nd byte is zero if instr is one byte)
;
; An "arg constant" is a char corresponding to either a row in argspecTbl or
; a group index in argGrpTbl (values < 0x10 are considered group indexes).
;
; The displacement bit is split in 2 nibbles: lower nibble is the displacement
; value, upper nibble is for flags:
;
; Bit 7: indicates that the numerical argument is of the 'e' type and has to be
; decreased by 2 (djnz, jr).
; Bit 6: it indicates that the group argument's value is to be placed on the
; second upcode rather than the first.
; Bit 5: Indicates that this row is handled very specially: the next two bytes
; aren't upcode bytes, but a routine address to call to handle this case with
; custom code.

instrTBl:
	.db I_ADC, 'A', 'l', 0,    0x8e		, 0	; ADC A, (HL)
	.db I_ADC, 'A', 0xb, 0,    0b10001000	, 0	; ADC A, r
	.db I_ADC, 'A', 'n', 0,    0xce		, 0	; ADC A, n
	.db I_ADC, 'h', 0x3, 0x44, 0xed, 0b01001010	; ADC HL, ss
	.db I_ADD, 'A', 'l', 0,    0x86		, 0	; ADD A, (HL)
	.db I_ADD, 'A', 0xb, 0,    0b10000000	, 0	; ADD A, r
	.db I_ADD, 'A', 'n', 0,    0xc6 	, 0	; ADD A, n
	.db I_ADD, 'h', 0x3, 4,    0b00001001 	, 0	; ADD HL, ss
	.db I_ADD, 'X', 0x4, 0x44, 0xdd, 0b00001001	; ADD IX, pp
	.db I_ADD, 'Y', 0x5, 0x44, 0xfd, 0b00001001	; ADD IY, rr
	.db I_ADD, 'A', 'x', 0,    0xdd, 0x86	 	; ADD A, (IX+d)
	.db I_ADD, 'A', 'y', 0,    0xfd, 0x86	 	; ADD A, (IY+d)
	.db I_AND, 'l', 0,   0,    0xa6		, 0	; AND (HL)
	.db I_AND, 0xb, 0,   0,    0b10100000	, 0	; AND r
	.db I_AND, 'n', 0,   0,    0xe6		, 0	; AND n
	.db I_AND, 'x', 0,   0,    0xdd, 0xa6		; AND (IX+d)
	.db I_AND, 'y', 0,   0,    0xfd, 0xa6		; AND (IY+d)
	.db I_BIT, 'n', 'l', 0x20 \ .dw handleBITHL	; BIT b, (HL)
	.db I_BIT, 'n', 'x', 0x20 \ .dw handleBITIX	; BIT b, (IX+d)
	.db I_BIT, 'n', 'y', 0x20 \ .dw handleBITIY	; BIT b, (IY+d)
	.db I_BIT, 'n', 0xb, 0x20 \ .dw handleBITR	; BIT b, r
	.db I_CALL,0xa, 'N', 3,    0b11000100	, 0	; CALL cc, NN
	.db I_CALL,'N', 0,   0,    0xcd		, 0	; CALL NN
	.db I_CCF, 0,   0,   0,    0x3f		, 0	; CCF
	.db I_CP,  'l', 0,   0,    0xbe		, 0	; CP (HL)
	.db I_CP,  0xb, 0,   0,    0b10111000	, 0	; CP r
	.db I_CP,  'n', 0,   0,    0xfe		, 0	; CP n
	.db I_CP,  'x', 0,   0,    0xdd, 0xbe		; CP (IX+d)
	.db I_CP,  'y', 0,   0,    0xfd, 0xbe		; CP (IY+d)
	.db I_CPD, 0,   0,   0,    0xed, 0xa9		; CPD
	.db I_CPDR,0,   0,   0,    0xed, 0xb9		; CPDR
	.db I_CPI, 0,   0,   0,    0xed, 0xa1		; CPI
	.db I_CPIR,0,   0,   0,    0xed, 0xb1		; CPIR
	.db I_CPL, 0,   0,   0,    0x2f		, 0	; CPL
	.db I_DAA, 0,   0,   0,    0x27		, 0	; DAA
	.db I_DEC, 'l', 0,   0,    0x35		, 0	; DEC (HL)
	.db I_DEC, 'X', 0,   0,    0xdd, 0x2b		; DEC IX
	.db I_DEC, 'x', 0,   0,    0xdd, 0x35		; DEC (IX+d)
	.db I_DEC, 'Y', 0,   0,    0xfd, 0x2b		; DEC IY
	.db I_DEC, 'y', 0,   0,    0xfd, 0x35		; DEC (IY+d)
	.db I_DEC, 0xb, 0,   3,    0b00000101	, 0	; DEC r
	.db I_DEC, 0x3, 0,   4,    0b00001011	, 0	; DEC ss
	.db I_DI,  0,   0,   0,    0xf3		, 0	; DI
	.db I_DJNZ,'n', 0,   0x80, 0x10		, 0	; DJNZ e
	.db I_EI,  0,   0,   0,    0xfb		, 0	; EI
	.db I_EX, 'p', 'h',  0,    0xe3		, 0	; EX (SP), HL
	.db I_EX, 'p', 'X',  0,    0xdd, 0xe3		; EX (SP), IX
	.db I_EX, 'p', 'Y',  0,    0xfd, 0xe3		; EX (SP), IY
	.db I_EX, 'a', 'f',  0,    0x08		, 0	; EX AF, AF'
	.db I_EX, 'd', 'h',  0,    0xeb		, 0	; EX DE, HL
	.db I_EXX, 0,   0,   0,    0xd9		, 0	; EXX
	.db I_HALT,0,   0,   0,    0x76		, 0	; HALT
	.db I_IM,  'n', 0,   0x20 \ .dw handleIM	; IM {0,1,2}
	.db I_IN,  'A', 'm', 0,    0xdb		, 0	; IN A, (n)
	.db I_IN,  0xb, 'k', 0x43, 0xed, 0b01000000	; IN r, (C)
	.db I_INC, 'l', 0,   0,    0x34		, 0	; INC (HL)
	.db I_INC, 'X', 0,   0,    0xdd , 0x23		; INC IX
	.db I_INC, 'x', 0,   0,    0xdd , 0x34		; INC (IX+d)
	.db I_INC, 'Y', 0,   0,    0xfd , 0x23		; INC IY
	.db I_INC, 'y', 0,   0,    0xfd , 0x34		; INC (IY+d)
	.db I_INC, 0xb, 0,   3,    0b00000100	, 0	; INC r
	.db I_INC, 0x3, 0,   4,    0b00000011	, 0	; INC ss
	.db I_IND, 0,   0,   0,    0xed, 0xaa		; IND
	.db I_INDR,0,   0,   0,    0xed, 0xba		; INDR
	.db I_INI, 0,   0,   0,    0xed, 0xa2		; INI
	.db I_INIR,0,   0,   0,    0xed, 0xb2		; INIR
	.db I_JP,  'l', 0,   0,    0xe9		, 0	; JP (HL)
	.db I_JP,  0xa, 'N', 3,    0b11000010	, 0	; JP cc, NN
	.db I_JP,  'N', 0,   0,    0xc3		, 0	; JP NN
	.db I_JP,  'x', 0,   0x20 \ .dw handleJPIX	; JP (IX)
	.db I_JP,  'y', 0,   0x20 \ .dw handleJPIY	; JP (IY)
	.db I_JR,  'n', 0,   0x80, 0x18		, 0	; JR e
	.db I_JR,  'C', 'n', 0x80, 0x38		, 0	; JR C, e
	.db I_JR,  '=', 'n', 0x80, 0x30		, 0	; JR NC, e
	.db I_JR,  'Z', 'n', 0x80, 0x28		, 0	; JR Z, e
	.db I_JR,  'z', 'n', 0x80, 0x20		, 0	; JR NZ, e
	.db I_LD,  'c', 'A', 0,    0x02		, 0	; LD (BC), A
	.db I_LD,  'e', 'A', 0,    0x12		, 0	; LD (DE), A
	.db I_LD,  'A', 'c', 0,    0x0a		, 0	; LD A, (BC)
	.db I_LD,  'A', 'e', 0,    0x1a		, 0	; LD A, (DE)
	.db I_LD,  's', 'h', 0,    0xf9		, 0	; LD SP, HL
	.db I_LD,  'A', 'I', 0,    0xed, 0x57		; LD A, I
	.db I_LD,  'I', 'A', 0,    0xed, 0x47		; LD I, A
	.db I_LD,  'A', 'R', 0,    0xed, 0x5f		; LD A, R
	.db I_LD,  'R', 'A', 0,    0xed, 0x4f		; LD R, A
	.db I_LD,  'l', 0xb, 0,    0b01110000	, 0	; LD (HL), r
	.db I_LD,  0xb, 'l', 3,    0b01000110	, 0	; LD r, (HL)
	.db I_LD,  'l', 'n', 0,    0x36		, 0	; LD (HL), n
	.db I_LD,  0xb, 'n', 3,    0b00000110	, 0	; LD r, (HL)
	.db I_LD,  0x3, 'N', 4,    0b00000001	, 0	; LD dd, n
	.db I_LD,  'M', 'A', 0,    0x32		, 0	; LD (NN), A
	.db I_LD,  'A', 'M', 0,    0x3a		, 0	; LD A, (NN)
	.db I_LD,  'M', 'h', 0,    0x22		, 0	; LD (NN), HL
	.db I_LD,  'h', 'M', 0,    0x2a		, 0	; LD HL, (NN)
	.db I_LD,  'M', 'X', 0,    0xdd, 0x22		; LD (NN), IX
	.db I_LD,  'X', 'M', 0,    0xdd, 0x2a		; LD IX, (NN)
	.db I_LD,  'M', 'Y', 0,    0xfd, 0x22		; LD (NN), IY
	.db I_LD,  'Y', 'M', 0,    0xfd, 0x2a		; LD IY, (NN)
	.db I_LD,  'M', 0x3, 0x44, 0xed, 0b01000011	; LD (NN), dd
	.db I_LD,  0x3, 'M', 0x44, 0xed, 0b01001011	; LD dd, (NN)
	.db I_LD,  'x', 'n', 0x20 \ .dw handleLDIXn	; LD (IX+d), n
	.db I_LD,  'y', 'n', 0x20 \ .dw handleLDIYn	; LD (IY+d), n
	.db I_LD,  'x', 0xb, 0x20 \ .dw handleLDIXr	; LD (IX+d), r
	.db I_LD,  'y', 0xb, 0x20 \ .dw handleLDIYr	; LD (IY+d), r
	.db I_LDD, 0,   0,   0,    0xed, 0xa8		; LDD
	.db I_LDDR,0,   0,   0,    0xed, 0xb8		; LDDR
	.db I_LDI, 0,   0,   0,    0xed, 0xa0		; LDI
	.db I_LDIR,0,   0,   0,    0xed, 0xb0		; LDIR
	.db I_NEG, 0,   0,   0,    0xed, 0x44		; NEG
	.db I_NOP, 0,   0,   0,    0x00		, 0	; NOP
	.db I_OR,  'l', 0,   0,    0xb6		, 0	; OR (HL)
	.db I_OR,  0xb, 0,   0,    0b10110000	, 0	; OR r
	.db I_OR,  'n', 0,   0,    0xf6		, 0	; OR n
	.db I_OR,  'x', 0,   0,    0xdd, 0xb6		; OR (IX+d)
	.db I_OR,  'y', 0,   0,    0xfd, 0xb6		; OR (IY+d)
	.db I_OTDR,0,   0,   0,    0xed, 0xbb		; OTDR
	.db I_OTIR,0,   0,   0,    0xed, 0xb3		; OTIR
	.db I_OUT, 'm', 'A', 0,    0xd3		, 0	; OUT (n), A
	.db I_OUT, 'k', 0xb, 0x43, 0xed, 0b01000001	; OUT (C), r
	.db I_POP, 0x1, 0,   4,    0b11000001	, 0	; POP qq
	.db I_PUSH,0x1, 0,   4,    0b11000101	, 0	; PUSH qq
	.db I_RET, 0,   0,   0,    0xc9		, 0	; RET
	.db I_RET, 0xa, 0,   3,    0b11000000	, 0	; RET cc
	.db I_RLA, 0,   0,   0,    0x17		, 0	; RLA
	.db I_RLCA,0,   0,   0,    0x07		, 0	; RLCA
	.db I_RRA, 0,   0,   0,    0x1f		, 0	; RRA
	.db I_RRCA,0,   0,   0,    0x0f		, 0	; RRCA
	.db I_SBC, 'A', 'l', 0,    0x9e		, 0	; SBC A, (HL)
	.db I_SBC, 'A', 0xb, 0,    0b10011000	, 0	; SBC A, r
	.db I_SCF, 0,   0,   0,    0x37		, 0	; SCF
	.db I_SUB, 'A', 'l', 0,    0x96		, 0	; SUB A, (HL)
	.db I_SUB, 'A', 0xb, 0,    0b10010000	, 0	; SUB A, r
	.db I_SUB, 'n', 0,   0,    0xd6 	, 0	; SUB n
	.db I_XOR, 'l', 0,   0,    0xae		, 0	; XOR (HL)
	.db I_XOR, 0xb, 0,   0,    0b10101000	, 0	; XOR r


; *** Variables ***
; Args are 3 bytes: argspec, then values of numerical constants (when that's
; appropriate)
curArg1:
	.db	0, 0, 0
curArg2:
	.db	0, 0, 0

curUpcode:
	.db	0, 0, 0, 0

