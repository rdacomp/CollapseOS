; stdio
;
; Allows other modules to print to "standard out", and get data from "standard
; in", that is, the console through which the user is connected in a decoupled
; manner.
;
; *** Consts ***
; Size of the readline buffer. If a typed line reaches this size, the line is
; flushed immediately (same as pressing return).
.equ	STDIO_BUFSIZE		0x20

; *** Variables ***
; Used to store formatted hex values just before printing it.
.equ	STDIO_HEX_FMT	STDIO_RAMSTART
.equ	STDIO_GETC	STDIO_HEX_FMT+2
.equ	STDIO_PUTC	STDIO_GETC+2

; Line buffer. We read types chars into this buffer until return is pressed
; This buffer is null-terminated and we don't keep an index around: we look
; for the null-termination every time we write to it. Simpler that way.
.equ	STDIO_BUF	STDIO_PUTC+2

; Index where the next char will go in stdioGetC.
.equ	STDIO_BUFIDX	STDIO_BUF+STDIO_BUFSIZE
.equ	STDIO_RAMEND	STDIO_BUFIDX+1

; Sets GetC to the routine where HL points to and PutC to DE.
stdioInit:
	ld	(STDIO_GETC), hl
	ld	(STDIO_PUTC), de
	xor	a
	ld	(STDIO_BUF), a
	ld	(STDIO_BUFIDX), a
	ret

stdioGetC:
	ld	ix, (STDIO_GETC)
	jp	(ix)

stdioPutC:
	ld	ix, (STDIO_PUTC)
	jp	(ix)

; print null-terminated string pointed to by HL
printstr:
	push	af
	push	hl

.loop:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	jr	z, .end		; if yes, we're finished
	call	stdioPutC
	inc	hl
	jr	.loop

.end:
	pop	hl
	pop	af
	ret

; print B characters from string that HL points to
printnstr:
	push	bc
	push	hl
.loop:
	ld	a, (hl)		; load character to send
	call	stdioPutC
	inc	hl
	djnz	.loop

.end:
	pop	hl
	pop	bc
	ret

printcrlf:
	push	af
	ld	a, ASCII_CR
	call	stdioPutC
	ld	a, ASCII_LF
	call	stdioPutC
	pop	af
	ret

; Print the hex char in A
printHex:
	push	bc
	push	hl
	ld	hl, STDIO_HEX_FMT
	call	fmtHexPair
	ld	b, 2
	call	printnstr
	pop	hl
	pop	bc
	ret

; Print the hex pair in HL
printHexPair:
	push	af
	ld	a, h
	call	printHex
	ld	a, l
	call	printHex
	pop	af
	ret

; Call stdioGetC and put the result in the buffer. Sets Z according to whether
; the buffer is "complete", that is, whether CR or LF have been pressed or if
; the the buffer is full. Z is set if the line is "complete", unset if not.
; The next call to stdioReadC after a completed line will start a new line.
;
; This routine also takes care of echoing received characters back to the TTY.
;
; This routine doesn't wait after a typed char. If nothing is typed, we return
; immediately with Z flag unset.
;
; Note that this routine doesn't bother returning the typed character.
stdioReadC:
	; Let's wait until something is typed.
	call	stdioGetC
	ret	nz		; nothing typed? nothing to do
	; got it. Now, is it a CR or LF?
	cp	ASCII_CR
	jr	z, .complete	; char is CR? buffer complete!
	cp	ASCII_LF
	jr	z, .complete
	cp	ASCII_DEL
	jr	z, .delchr
	cp	ASCII_BS
	jr	z, .delchr

	; Echo the received character right away so that we see what we type
	call	stdioPutC

	; Ok, gotta add it do the buffer
	; save char for later
	ex	af, af'
	ld	a, (STDIO_BUFIDX)
	push	hl			; --> lvl 1
	ld	hl, STDIO_BUF
	; make HL point to dest spot
	call	addHL
	; Write our char down
	ex	af, af'
	ld	(hl), a
	; follow up with a null char
	inc	hl
	xor	a
	ld	(hl), a
	pop	hl			; <-- lvl 1
	; inc idx, which still is in AF'
	ex	af, af'
	inc	a
	cp	STDIO_BUFSIZE-1 ; -1 is because we always want to keep our
				; last char at zero.
	jr	z, .complete	; end of buffer reached? buffer is full.

	; not complete. save idx back
	ld	(STDIO_BUFIDX), a
	; Z already unset
	ret

.complete:
	; The line in our buffer is complete.
	; But before we do that, let's take care of a special case: the empty
	; line. If we didn't add any character since the last "complete", then
	; our buffer's content is the content from the last time. Let's set this
	; to an empty string.
	ld	a, (STDIO_BUFIDX)
	or	a
	jr	nz, .completeSkip
	ld	(STDIO_BUF), a
.completeSkip:
	xor	a		; sets Z
	ld	(STDIO_BUFIDX), a
	ret

.delchr:
	ld	a, (STDIO_BUFIDX)
	or	a
	jp	z, unsetZ	; buf empty? nothing to do
	; buffer not empty, let's go back one char and set a null char there.
	dec	a
	ld	(STDIO_BUFIDX), a
	push	hl			;<|
	ld	hl, STDIO_BUF		; |
	; make HL point to dest spot	  |
	call	addHL			; |
	xor	a			; |
	ld	(hl), a			; |
	pop	hl			;<|
	; Char deleted in buffer, now send BS + space + BS for the terminal
	; to clear its previous char
	ld	a, ASCII_BS
	call	stdioPutC
	ld	a, ' '
	call	stdioPutC
	ld	a, ASCII_BS
	call	stdioPutC
	jp	unsetZ


; Make HL point to the line buffer. It is always null terminated.
stdioGetLine:
	ld	hl, STDIO_BUF
	ret

; Repeatedly call stdioReadC until Z is set, then make HL point to the read
; buffer.
stdioReadLine:
	call	stdioReadC
	jr	nz, stdioReadLine
	ld	hl, STDIO_BUF
	ret

