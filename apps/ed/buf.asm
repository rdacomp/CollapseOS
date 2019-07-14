; buf - manage line buffer
;
; Lines in edited file aren't loaded in memory, their offsets is referenced to
; in this buffer.
;
; *** Consts ***
;
; Maximum number of lines allowed in the buffer.
.equ	BUF_MAXLINES	0x800
; Size of our scratchpad
.equ	BUF_PADMAXLEN	0x1000

; *** Variables ***
; Number of lines currently in the buffer
.equ	BUF_LINECNT	BUF_RAMSTART
; List of words pointing to scratchpad offsets
.equ	BUF_LINES	BUF_LINECNT+2
; size of file we read in bufInit. That offset is the beginning of our
; in-memory scratchpad.
.equ	BUF_FSIZE	BUF_LINES+BUF_MAXLINES*2
; The in-memory scratchpad
.equ	BUF_PADLEN	BUF_FSIZE+2
.equ	BUF_PAD		BUF_PADLEN+2

.equ	BUF_RAMEND	BUF_PAD+BUF_PADMAXLEN

; *** Code ***

; On initialization, we read the whole contents of target blkdev and add lines
; as we go.
bufInit:
	ld	hl, 0
	ld	(BUF_PADLEN), hl
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
	; HL currently has the result of the last blkTell
	ld	(BUF_FSIZE), hl
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
	; and now HL has it. We're ready to call ioGetLine!
	pop	de
	cp	a	; ensure Z
	jp	ioGetLine	; preserves AF
.outOfBounds:
	pop	de
	jp	unsetZ

; Given line indexes in HL and DE where HL < DE < CNT, move all lines between
; DE and CNT by an offset of DE-HL. Also, adjust BUF_LINECNT by DE-HL.
; WARNING: no bounds check. The only consumer of this routine already does
; bounds check.
bufDelLines:
	ex	de, hl
	push	hl	; --> lvl 1
	scf \ ccf
	sbc	hl, de	; HL now has delcount -1
	inc	hl	; adjust for actual delcount
	; We have the number of lines to delete in HL. We're going to move this
	; to BC for a LDIR, but before we do, there's two things we need to do:
	; adjust buffer line count and multiply by 2 (we move words, not bytes).
	push	de	; --> lvl 2
	ex	de, hl	; del cnt now in DE
	ld	hl, (BUF_LINECNT)
	scf \ ccf
	sbc	hl, de	; HL now has adjusted line cnt
	ld	(BUF_LINECNT), hl
	; Good! one less thing to think about. Now, let's prepare moving DE
	; (delcnt) to BC. But first, we'll multiply by 2.
	sla	e \ rl d
	push	hl \ pop bc	; BC: delcount * 2
	pop	de	; <-- lvl 2
	pop	hl	; <-- lvl 1
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
