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
; *** Requirements ***
; BLOCKDEV_SIZE
; FS_HANDLE_SIZE
; _blkGetC
; _blkPutC
; _blkSeek
; _blkTell
; addHL
; cpHLDE
; fsFindFN
; fsOpen
; fsGetC
; fsPutC
; intoHL
; printstr
; printcrlf
; stdioReadLine
; stdioPutC
; unsetZ
;
; *** Variables ***
;
.equ	ED_CURLINE	ED_RAMSTART
.equ	ED_RAMEND	ED_CURLINE+2

edMain:
	; because ed only takes a single string arg, we can use HL directly
	call	ioInit
	ret	nz
	; diverge from UNIX: start at first line
	ld	hl, 0
	ld	(ED_CURLINE), hl

	call	bufInit

.mainLoop:
	ld	a, ':'
	call	stdioPutC
	call	stdioReadLine	; --> HL
	; Now, process line.
	call	printcrlf
	call	cmdParse
	jr	nz, .error
	ld	a, (CMD_TYPE)
	cp	'q'
	jr	z, .doQuit
	; The rest of the commands need an address
	call	edReadAddrs
	jr	nz, .error
	ld	a, (CMD_TYPE)
	cp	'd'
	jr	z, .doDel
	cp	'a'
	jr	z, .doAppend
	cp	'i'
	jr	z, .doInsert
	jr	.doPrint

.doQuit:
	xor	a
	ret

.doDel:
	; bufDelLines expects an exclusive upper bound, which is why we inc DE.
	inc	de
	call	bufDelLines
	jr	.mainLoop
.doAppend:
	inc	de
.doInsert:
	call	stdioReadLine	; --> HL
	call	bufScratchpadAdd	; --> HL
	; insert index in DE, line offset in HL. We want the opposite.
	ex	de, hl
	call	bufInsertLine
	call	printcrlf
	jr	.mainLoop

.doPrint:
	push	hl
	call	bufGetLine
	jr	nz, .error
	call	printstr
	call	printcrlf
	pop	hl
	call	cpHLDE
	jr	z, .doPrintEnd
	inc	hl
	jr	.doPrint
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

