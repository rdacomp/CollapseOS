; shell
;
; Runs a shell over an asynchronous communication interface adapter (ACIA).
; for now, this unit is tightly coupled to acia.asm, but it will eventually be
; more general than that.

; Incomplete. For now, this outputs a welcome prompt and then waits for input.
; Whenever input is CR or LF, we echo back what we've received and empty the
; input buffer. This also happen when the buffer is full.

; *** CONSTS ***
CR	.equ	0x0d
LF	.equ	0x0a

shellInit:
	; print prompt
	ld	hl, d_welcome
	call	printstr
	call	printcrlf
	ret

shellLoop:
	call	chkbuf
	jr	shellLoop

; print null-terminated string pointed to by HL
printstr:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	ret	z		; if yes, we're finished
	call	aciaPutC
	inc	hl
	jr	printstr
	; no ret because our only way out is ret z above

printcrlf:
	ld	a, CR
	call	aciaPutC
	ld	a, LF
	call	aciaPutC
	ret


; check if the input buffer is full or ends in CR or LF. If it does, prints it
; back and empty it.
chkbuf:
	call	aciaBufPtr
	cp	0
	ret	z		; BUFIDX is zero? nothing to check.

	cp	ACIA_BUFSIZE
	jr	z, .do		; if BUFIDX == BUFSIZE? do!

	; our previous char is in BUFIDX - 1. Fetch this
	dec	hl
	ld	a, (hl)		; now, that's our char we have in A
	inc	hl		; put HL back where it was

	cp	CR
	jr	z, .do		; char is CR? do!
	cp	LF
	jr	z, .do		; char is LF? do!

	; nothing matched? don't do anything
	ret

.do:
	; terminate our string with 0
	xor	a
	ld	(hl), a
	; reset buffer index
	ld	(ACIA_BUFIDX), a

	; alright, let's go!
	ld	hl, ACIA_BUF
	call	printstr
	call	printcrlf
	ret

; *** DATA ***
d_welcome:	.byte	"Welcome to Collapse OS", 0
