; buf - manage line buffer
;
; Lines in edited file aren't loaded in memory, their offsets is referenced to
; in this buffer.
;
; About scratchpad and offsets. There are two scratchpads: file and memory.
; The file one is the contents of the active blkdev. The second one is
; in-memory, for edits. We differentiate between the two with a
; "scatchpad mask". When the high bits of the offset match the mask, then we
; know that this offset is from the scratchpad.
;
; *** Consts ***
;
; Maximum number of lines allowed in the buffer.
.equ	BUF_MAXLINES	0x800
; Size of our scratchpad
.equ	BUF_PADMAXLEN	0x1000
; Scratchpad mask (only applies on high byte)
.equ	BUF_SCRATCHPAD_MASK	0b11110000

; *** Variables ***
; Number of lines currently in the buffer
.equ	BUF_LINECNT	BUF_RAMSTART
; List of words pointing to scratchpad offsets
.equ	BUF_LINES	BUF_LINECNT+2
; Points to the end of the scratchpad
.equ	BUF_PADEND	BUF_LINES+BUF_MAXLINES*2
; The in-memory scratchpad
.equ	BUF_PAD		BUF_PADEND+2

.equ	BUF_RAMEND	BUF_PAD+BUF_PADMAXLEN

; *** Code ***

; On initialization, we read the whole contents of target blkdev and add lines
; as we go.
bufInit:
	ld	hl, BUF_PAD
	ld	(BUF_PADEND), hl
	ld	ix, BUF_LINES
	ld	bc, 0		; line count
.loop:
	call	blkTell		; --> HL
	call	blkGetC
	jr	nz, .loopend
	ld	(ix), l
	inc	ix
	ld	(ix), h
	inc	ix
	inc	bc
	call	ioGetLine
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

; Read line number specified in HL and loads the I/O buffer with it.
; Like ioGetLine, sets HL to line buffer pointer.
; Sets Z on success, unset if out of bounds.
bufGetLine:
	push	de
	ld	de, (BUF_LINECNT)
	call	cpHLDE
	jr	nc, .outOfBounds	; HL > (BUF_LINECNT)
	call	bufLineAddr
	; HL now points to seek offset in memory
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	; DE has seek offset
	ex	de, hl
	pop	de
	; is it a scratchpad offset?
	ld	a, h
	and	BUF_SCRATCHPAD_MASK
	cp	BUF_SCRATCHPAD_MASK
	jr	z, .fromScratchpad
	; not from scratchpad
	cp	a	; ensure Z
	jp	ioGetLine	; preserves AF
.fromScratchpad:
	; remove scratchpad mask
	ld	a, BUF_SCRATCHPAD_MASK
	xor	0xff
	and	h
	ld	h, a
	; HL is now a mask-less offset to BUF_PAD
	push	de	; --> lvl 1
	ld	de, BUF_PAD
	add	hl, de
	pop	de	; <-- lvl 1
	ret
.outOfBounds:
	pop	de
	jp	unsetZ

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
	push	de	; --> lvl 1, scratchpad offset
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
	push	hl \ pop	de
	dec	hl
	dec	hl
	; HL = BUF_LINECNT-1, DE = BUF_LINECNT, BC is set. We're good!
	lddr
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

; copy string that HL points to to scratchpad and return its seek offset, in HL.
bufScratchpadAdd:
	push	de
	ld	de, (BUF_PADEND)
	push	de	; --> lvl 1
	call	strcpyM
	ld	(BUF_PADEND), de
	pop	hl	; <-- lvl 1
	; we have a memory offset in HL, but it's not what we want! we want a
	; seek offset stamped with the "scratchpad mask"
	ld	de, BUF_PAD
	scf \ ccf
	sbc	hl, de
	ld	a, h
	or	BUF_SCRATCHPAD_MASK
	ld	h, a
	; now we're good...
	pop	de
	ret
