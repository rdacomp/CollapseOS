; buf - manage line buffer
;
; Lines in edited file aren't loaded in memory, their offsets is referenced to
; in this buffer.
;
; *** Consts ***
;
; Maximum number of lines allowed in the buffer.
.equ	BUF_MAXLINES	0x800

; *** Variables ***
; Number of lines currently in the buffer
.equ	BUF_LINECNT	BUF_RAMSTART
; List of words pointing to scratchpad offsets
.equ	BUF_LINES	BUF_LINECNT+2
.equ	BUF_RAMEND	BUF_LINES+BUF_MAXLINES*2

; *** Code ***

bufInit:
	xor	a
	ld	(BUF_LINECNT), a
	ret

; Add a new line with offset HL to the buffer
bufAddLine:
	push	de
	push	hl
	ld	hl, BUF_LINES
	ld	de, (BUF_LINECNT)
	add	hl, de
	add	hl, de	; twice, because two bytes per line
	; HL now points to the specified line offset in memory
	pop	de	; what used to be in HL ends up in DE
	; line offset popped back in HL
	ld	(hl), e
	inc	hl
	ld	(hl), d
	; increase line count
	ld	hl, (BUF_LINECNT)
	inc	hl
	ld	(BUF_LINECNT), hl
	; our initial HL is in DE. Before we pop DE back, let's swap these
	; two so that all registers are preserved.
	ex	de, hl
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
	ex	de, hl
	ld	hl, BUF_LINES
	add	hl, de
	add	hl, de	; twice, because two bytes per line
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
