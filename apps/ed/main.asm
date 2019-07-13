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

edMain:
	; Fill line buffer
.loop:
	call	blkTell		; --> HL
	call	blkGetC
	jr	nz, edLoop
	call	bufAddLine
	call	ioGetLine
	jr	.loop
	; Continue to loop

edLoop:
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
	jr	edLoop

; Sets Z if we need to quit
.processLine:
	ld	a, (hl)
	cp	'q'
	ret	z
	call	parseDecimal
	jr	z, .processNumber
	jr	.error
.processNumber:
	; number is in IX
	; Because we don't have a line buffer yet, let's simply print seek
	; offsets.
	push	ix \ pop	hl
	dec	hl		; from 1-based to zero-based
	call	bufGetLine
	jr	nz, .error
	call	printstr
	call	printcrlf
	; continue to end
.processEnd:
	call	printcrlf
	jp	unsetZ
.error:
	ld	a, '?'
	call	stdioPutC
	call	printcrlf
	jp	unsetZ

