; cmd - parse and interpret command
;
; *** Consts ***

; address type

.equ	ABSOLUTE	0
; handles +, - and ".". For +, easy. For -, addr is negative. For ., it's 0.
.equ	RELATIVE	1
.equ	BOF		2
.equ	EOF		3

; *** Variables ***

; An address is a one byte type and a two bytes line number (0-indexed)
.equ	CMD_ADDR1	CMD_RAMSTART
.equ	CMD_ADDR2	CMD_ADDR1+3
.equ	CMD_TYPE	CMD_ADDR2+3
.equ	CMD_RAMEND	CMD_TYPE+1

; *** Code ***

; Parse command line that HL points to and set unit's variables
; Sets Z on success, unset on error.
cmdParse:
	ld	a, (hl)
	cp	'q'
	jr	z, .simpleCmd
	cp	'w'
	jr	z, .simpleCmd
	ld	ix, CMD_ADDR1
	call	.readAddr
	ret	nz
	; Before we check for the existence of a second addr, let's set that
	; second addr to the same value as the first. That's going to be its
	; value if we have to ",".
	ld	a, (ix)
	ld	(CMD_ADDR2), a
	ld	a, (ix+1)
	ld	(CMD_ADDR2+1), a
	ld	a, (ix+2)
	ld	(CMD_ADDR2+2), a
	ld	a, (hl)
	cp	','
	jr	nz, .noaddr2
	inc	hl
	ld	ix, CMD_ADDR2
	call	.readAddr
	ret	nz
.noaddr2:
	; We expect HL (rest of the cmdline) to be a null char or an accepted
	; cmd, otherwise it's garbage
	ld	a, (hl)
	or	a
	jr	z, .nullCmd
	cp	'p'
	jr	z, .okCmd
	cp	'd'
	jr	z, .okCmd
	cp	'a'
	jr	z, .okCmd
	cp	'i'
	jr	z, .okCmd
	; unsupported cmd
	ret			; Z unset
.nullCmd:
	ld	a, 'p'
.okCmd:
	ld	(CMD_TYPE), a
	ret			; Z already set

.simpleCmd:
	; Z already set
	ld	(CMD_TYPE), a
	ret

; Parse the string at (HL) and sets its corresponding address in IX, properly
; considering implicit values (current address when nothing is specified).
; advances HL to the char next to the last parsed char.
; It handles "+" and "-" addresses such as "+3", "-2", "+", "-".
; Sets Z on success, unset on error. Line out of bounds isn't an error. Only
; overflows.
.readAddr:
	ld	a, (hl)
	cp	'+'
	jr	z, .plusOrMinus
	cp	'-'
	jr	z, .plusOrMinus
	call	parseDecimalDigit
	jr	c, .notHandled
	; straight number
	ld	a, ABSOLUTE
	ld	(ix), a
	call	.parseDecimalM
	ret	nz
	dec	de	; from 1-based to 0-base
	jr	.end
.notHandled:
	; something else. Something we don't handle. Our addr is therefore "."
	ld	a, RELATIVE
	ld	(ix), a
	xor	a		; sets Z
	ld	(ix+1), a
	ld	(ix+2), a
	ret
.plusOrMinus:
	push	af		; preserve that + or -
	ld	a, RELATIVE
	ld	(ix), a
	inc	hl		; advance cmd cursor
	ld	a, (hl)
	ld	de, 1		; if .pmNoSuffix
	call	parseDecimalDigit
	jr	c, .pmNoSuffix
	call	.parseDecimalM	; --> DE
.pmNoSuffix:
	pop	af		; bring back that +/-
	cp	'-'
	jr	nz, .end
	; we had a "-". Negate DE
	push	hl
	ld	hl, 0
	sbc	hl, de
	ex	de, hl
	pop	hl
.end:
	; we still have to save DE in memory
	ld	(ix+1), e
	ld	(ix+2), d
	cp	a		; ensure Z
	ret

; call parseDecimal and set HL to the character following the last digit
.parseDecimalM:
	push	bc
	push	ix
	push	hl
.loop:
	inc	hl
	ld	a, (hl)
	call	parseDecimalDigit
	jr	nc, .loop
	; We're at the first non-digit char. Let's save it because we're going
	; to temporarily replace it with a null.
	ld	b, (hl)		; refetch (HL), A has been mucked with in
				; parseDecimalDigit
	xor	a
	ld	(hl), a
	; Now, let's go back to the beginning of the string and parse it.
	; but before we do this, let's save the end of string in DE
	ex	de, hl
	pop	hl
	call	parseDecimal
	; Z is set properly at this point. nothing touches Z below.
	ld	a, b
	ld	(de), a
	ex	de, hl	; put end of string back from DE to HL
	; Put addr in its final register, DE
	push	ix \ pop de
	pop	ix
	pop	bc
	ret

