; buf - manage line buffer
;
; *** Variables ***
; Number of lines currently in the buffer
.equ	BUF_LINECNT	BUF_RAMSTART
; List of pointers to strings in scratchpad
.equ	BUF_LINES	BUF_LINECNT+2
; Points to the end of the scratchpad, that is, one byte after the last written
; char in it.
.equ	BUF_PADEND	BUF_LINES+ED_BUF_MAXLINES*2
; The in-memory scratchpad
.equ	BUF_PAD		BUF_PADEND+2

.equ	BUF_RAMEND	BUF_PAD+ED_BUF_PADMAXLEN

; *** Code ***

; On initialization, we read the whole contents of target blkdev and add lines
; as we go.
bufInit:
	ld	hl, BUF_PAD	; running pointer to end of pad
	ld	de, BUF_PAD	; points to beginning of current line
	ld	ix, BUF_LINES	; points to current line index
	ld	bc, 0		; line count
	; init pad end in case we have an empty file.
	ld	(BUF_PADEND), hl
.loop:
	call	ioGetC
	jr	nz, .loopend
	or	a		; null? hum, weird. same as LF
	jr	z, .lineend
	cp	0x0a
	jr	z, .lineend
	ld	(hl), a
	inc	hl
	jr	.loop
.lineend:
	; We've just finished reading a line, writing each char in the pad.
	; Null terminate it.
	xor	a
	ld	(hl), a
	inc	hl
	; Now, let's register its pointer in BUF_LINES
	ld	(ix), e
	inc	ix
	ld	(ix), d
	inc	ix
	inc	bc
	ld	(BUF_PADEND), hl
	ld	de, (BUF_PADEND)
	jr	.loop
.loopend:
	ld	(BUF_LINECNT), bc
	ret

; transform line index HL into its corresponding memory address in BUF_LINES
; array.
bufLineAddr:
	push	de
	ex	de, hl
	ld	hl, BUF_LINES
	add	hl, de
	add	hl, de	; twice, because two bytes per line
	pop	de
	ret

; Read line number specified in HL and make HL point to its contents.
; Sets Z on success, unset if out of bounds.
bufGetLine:
	push	de		; --> lvl 1
	ld	de, (BUF_LINECNT)
	call	cpHLDE
	pop	de		; <-- lvl 1
	jp	nc, unsetZ	; HL > (BUF_LINECNT)
	call	bufLineAddr
	; HL now points to an item in BUF_LINES.
	call	intoHL
	; Now, HL points to our contents
	cp	a		; ensure Z
	ret

; Given line indexes in HL and DE where HL < DE < CNT, move all lines between
; DE and CNT by an offset of DE-HL. Also, adjust BUF_LINECNT by DE-HL.
; WARNING: no bounds check. The only consumer of this routine already does
; bounds check.
bufDelLines:
	; Let's start with setting up BC, which is (CNT-DE) * 2
	push	hl	; --> lvl 1
	ld	hl, (BUF_LINECNT)
	scf \ ccf
	sbc	hl, de
	; mult by 2 and we're done
	sla	l \ rl h
	push	hl \ pop bc
	pop	hl	; <-- lvl 1
	; Good! BC done. Now, let's adjust BUF_LINECNT by DE-HL
	push	hl	; --> lvl 1
	scf \ ccf
	sbc	hl, de	; HL -> nb of lines to delete, negative
	push	de	; --> lvl 2
	ld	de, (BUF_LINECNT)
	add	hl, de	; adding DE to negative HL
	ld	(BUF_LINECNT), hl
	pop	de	; <-- lvl 2
	pop	hl	; <-- lvl 1
	; Line count updated!
	; One other thing... is BC zero? Because if it is, then we shouldn't
	; call ldir (otherwise we're on for a veeeery long loop), BC=0 means
	; that only last lines were deleted. nothing to do.
	ld	a, b
	or	c
	ret	z	; BC==0, return

	; let's have invert HL and DE to match LDIR's signature
	ex	de, hl
	; At this point we have higher index in HL, lower index in DE and number
	; of bytes to delete in BC. It's convenient because it's rather close
	; to LDIR's signature! The only thing we need to do now is to translate
	; those HL and DE indexes in memory addresses, that is, multiply by 2
	; and add BUF_LINES
	push	hl	; --> lvl 1
	ex	de, hl
	call	bufLineAddr
	ex	de, hl
	pop	hl	; <-- lvl 1
	call	bufLineAddr
	; Both HL and DE are translated. Go!
	ldir
	ret

; Insert string where DE points to memory scratchpad, then insert that line
; at index HL, offsetting all lines by 2 bytes.
bufInsertLine:
	call	bufIndexInBounds
	jr	nz, .append
	push	de	; --> lvl 1, scratchpad ptr
	push	hl	; --> lvl 2, insert index
	; The logic below is mostly copy-pasted from bufDelLines, but with a
	; LDDR logic (to avoid overwriting). I learned, with some pain involved,
	; that generalizing this code wasn't working very well. I don't repeat
	; the comments, refer to bufDelLines
	ex	de, hl	; line index now in DE
	ld	hl, (BUF_LINECNT)
	scf \ ccf
	sbc	hl, de
	; mult by 2 and we're done
	sla	l \ rl h
	push	hl \ pop bc
	; From this point, we don't need our line index in DE any more because
	; LDDR will start from BUF_LINECNT-1 with count BC. We'll only need it
	; when it's time to insert the line in the space we make.
	ld	hl, (BUF_LINECNT)
	call	bufLineAddr
	; HL is pointing to *first byte* after last line. Our source needs to
	; be the second byte of the last line and our dest is the second byte
	; after the last line.
	push	hl \ pop	de
	dec	hl	; second byte of last line
	inc	de	; second byte beyond last line
	; HL = BUF_LINECNT-1, DE = BUF_LINECNT, BC is set. We're good!
	lddr
.set:
	; We still need to increase BUF_LINECNT
	ld	hl, (BUF_LINECNT)
	inc	hl
	ld	(BUF_LINECNT), hl
	; A space has been opened at line index HL. Let's fill it with our
	; inserted line.
	pop	hl		; <-- lvl 2, insert index
	call	bufLineAddr
	pop	de		; <-- lvl 1, scratchpad offset
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ret
.append:
	; nothing to move, just put the line there. Let's piggy-back on the end
	; of the regular routine by carefully pushing the right register in the
	; right place.
	; But before that, make sure that HL isn't too high. The only place we
	; can append to is at (BUF_LINECNT)
	ld	hl, (BUF_LINECNT)
	push	de		; --> lvl 1
	push	hl		; --> lvl 2
	jr	.set

; copy string that HL points to to scratchpad and return its pointer in
; scratchpad, in HL.
bufScratchpadAdd:
	push	de
	ld	de, (BUF_PADEND)
	push	de	; --> lvl 1
	call	strcpyM
	inc	de		; pad end is last char + 1
	ld	(BUF_PADEND), de
	pop	hl	; <-- lvl 1
	pop	de
	ret

; Sets Z according to whether the line index in HL is within bounds.
bufIndexInBounds:
	push	de
	ld	de, (BUF_LINECNT)
	call	cpHLDE
	pop	de
	jr	c, .withinBounds
	; out of bounds
	jp	unsetZ
.withinBounds:
	cp	a	; ensure Z
	ret
