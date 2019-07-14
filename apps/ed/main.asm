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
	call	cmdParse
	jr	nz, .error
	ld	a, (CMD_TYPE)
	cp	'q'
	jr	z, .doQuit
	cp	'd'
	jr	z, .doDel
	jr	.doPrint

.doQuit:
	xor	a
	ret

.doDel:
	call	edReadAddrs
	jr	nz, .error
	; bufDelLines expects an exclusive upper bound, which is why we inc DE.
	inc	de
	call	bufDelLines
	jr	.mainLoop
.doPrint:
	call	edReadAddrs
	jr	nz, .error
.doPrintLoop:
	push	hl
	call	bufGetLine
	jr	nz, .error
	call	printstr
	call	printcrlf
	pop	hl
	call	cpHLDE
	jr	z, .doPrintEnd
	inc	hl
	jr	.doPrintLoop
.doPrintEnd:
	ld	(ED_CURLINE), hl
	jr	.mainLoop
.error:
	ld	a, '?'
	call	stdioPutC
	call	printcrlf
	jr	.mainLoop


; Transform an address "cmd" in IX into an absolute address in HL.
edResolveAddr:
	ld	a, (ix)
	cp	RELATIVE
	jr	z, .relative
	; absolute
	ld	l, (ix+1)
	ld	h, (ix+2)
	ret
.relative:
	ld	hl, (ED_CURLINE)
	push	de
	ld	e, (ix+1)
	ld	d, (ix+2)
	add	hl, de
	pop	de
	ret

; Read absolute addr1 in HL and addr2 in DE. Also, check bounds and set Z if
; both addresses are within bounds, unset if not.
edReadAddrs:
	ld	ix, CMD_ADDR2
	call	edResolveAddr
	ex	de, hl
	ld	hl, (BUF_LINECNT)
	ex	de, hl		; HL: addr2 DE: cnt
	call	cpHLDE
	jp	nc, unsetZ	; HL (addr2) >= DE (cnt). no good
	ex	de, hl		; DE: addr2
	ld	ix, CMD_ADDR1
	call	edResolveAddr
	ex	de, hl		; HL: addr2, DE: addr1
	call	cpHLDE
	jp	c, unsetZ	; HL (addr2) < DE (addr1). no good
	ex	de, hl		; HL: addr1, DE: addr2
	cp	a		; ensure Z
	ret

