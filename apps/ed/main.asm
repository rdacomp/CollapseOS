; ed - line editor
;
; A text editor modeled after UNIX's ed, but simpler. The goal is to stay tight
; on resources and to avoid having to implement screen management code (that is,
; develop the machinery to have ncurses-like apps in Collapse OS).
;
; ed has a mechanism to avoid having to move a lot of memory around at each
; edit. Each line is an element in an doubly-linked list and each element point
; to an offset in the "scratchpad". The scratchpad starts with the file
; contents and every time we change or add a line, that line goes to the end of
; the scratch pad and linked lists are reorganized whenever lines are changed.
; Contents itself is always appended to the scratchpad.
;
; That's on a resourceful UNIX system.
;
; That doubly linked list on the z80 would use 7 bytes per line (prev, next,
; offset, len), which is a bit much. Moreover, there's that whole "scratchpad
; being loaded in memory" thing that's a bit iffy. We sacrifice speed for
; memory usage.
;
; So here's what we do. First, we have two scratchpads. The first one is the
; file being read itself. The second one is memory, for modifications we
; make to the file. When reading the file, we note the offset at which it ends.
; All offsets under this limit refer to the first scratchpad. Other offsets
; refer to the second.
;
; Then, our line list is just an array of 16-bit offsets. This means that we
; don't have an easy access to line length and we have to move a lot of memory
; around whenever we add or delete lines. Hopefully, "LDIR" will be our friend
; here...
;
; *** Usage ***
;
; ed takes no argument. It reads from the currently selected blkdev and writes
; to it. It repeatedly presents a prompt, waits for a command, execute the
; command. 'q' to quit.
;
; Enter a number to print this line's number. For ed, we break with Collapse
; OS's tradition of using hex representation. It would be needlessly confusing
; when combined with commands (p, c, d, a, i). All numbers in ed are
; represented in decimals.
;
; Like in ed, line indexing is one-based. This is only in the interface,
; however. In the code, line indexes are zero-based.
;
; *** Requirements ***
; BLOCKDEV_SIZE
; addHL
; blkGetC
; blkSeek
; blkTell
; cpHLDE
; intoHL
; printstr
; printcrlf
; stdioGetLine
; stdioPutC
; stdioReadC
; unsetZ
;
; *** Variables ***
;
.equ	ED_CURLINE	ED_RAMSTART
.equ	ED_RAMEND	ED_CURLINE+2

edMain:
	; diverge from UNIX: start at first line
	ld	hl, 0
	ld	(ED_CURLINE), hl

	; Fill line buffer
.fillLoop:
	call	blkTell		; --> HL
	call	blkGetC
	jr	nz, .mainLoop
	call	bufAddLine
	call	ioGetLine
	jr	.fillLoop

.mainLoop:
	ld	a, ':'
	call	stdioPutC
.inner:
	call	stdioReadC
	jr	nz, .inner	; not done? loop
	; We're done. Process line.
	call	printcrlf
	call	stdioGetLine
	call	.processLine
	ret	z
	jr	.mainLoop

; Sets Z if we need to quit
.processLine:
	ld	a, (hl)
	cp	'q'
	ret	z
	call	edReadAddr
	jr	z, .processNumber
	jr	.processError
.processNumber:
	; number is in DE
	; We expect HL (rest of the cmdline) to be a null char, otherwise it's
	; garbage
	ld	a, (hl)
	or	a
	jr	nz, .processError
	ex	de, hl
	ld	(ED_CURLINE), hl
	call	bufGetLine
	jr	nz, .processError
	call	printstr
	call	printcrlf
	; continue to end
.processEnd:
	call	printcrlf
	jp	unsetZ
.processError:
	ld	a, '?'
	call	stdioPutC
	call	printcrlf
	jp	unsetZ

; Parse the string at (HL) and sets its corresponding address in DE, properly
; considering implicit values (current address when nothing is specified).
; advances HL to the char next to the last parsed char.
; It handles "+" and "-" addresses such as "+3", "-2", "+", "-".
; Sets Z on success, unset on error. Line out of bounds isn't an error. Only
; overflows.
edReadAddr:
	ld	a, (hl)
	cp	'+'
	jr	z, .plusOrMinus
	cp	'-'
	jr	z, .plusOrMinus
	call	parseDecimalDigit
	jr	c, .notHandled
	; straight number
	call	.parseDecimalM	; Z has proper value
	dec	de	; from 1-based to 0-base. 16bit doesn't affect flags.
	ret
.notHandled:
	; something else. Something we don't handle. Our addr is therefore
	; (ED_CURLINE).
	push	hl
	ld	hl, (ED_CURLINE)
	ex	de, hl
	pop	hl
	cp	a		; ensure Z
	ret
.plusOrMinus:
	push	af		; preserve that + or -
	inc	hl		; advance cmd cursor
	ld	a, (hl)
	ld	de, 1		; if .pmNoSuffix
	call	parseDecimalDigit
	jr	c, .pmNoSuffix
	call	.parseDecimalM	; --> DE
.pmNoSuffix:
	pop	af		; bring back that +/-
	push	hl
	ld	hl, (ED_CURLINE)
	cp	'-'
	jr	z, .pmIsMinus
	add	hl, de
	jr	.pmEnd
.pmIsMinus:
	sbc	hl, de
.pmEnd:
	ex	de, hl
	pop	hl
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
	ld	b, a
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
