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
; file being read itself. The second one is is memory, for modifications we
; make to the file. When reading the file, we note the offset at which it ends.
; All offsets under this limit refer to the first scratchpad. Other offsets
; refer to the second.
;
; Then, our line list if just an array of 16-bit offsets. This means that we
; don't have an easy access to line length and we have to move a lot of memory
; around whenever we add or delete lines. Hopefully, "LDIR" will be our friend
; here...
;
; *** Requirements ***
; printstr
; printcrlf
; stdioReadC
; stdioGetLine

edMain:
edLoop:
	ld	hl, .prompt
	call	printstr
.inner:
	call	stdioReadC
	jr	nz, .inner	; not done? loop
	; We're done. Process line.
	call	printcrlf
	call	stdioGetLine
	call	edProcessLine
	ret	z
	jr	edLoop

.prompt:
	.db	":", 0

; Sets Z if we need to quit
edProcessLine:
	call	printstr
	ld	a, (hl)
	cp	'q'
	ret	z
	call	printcrlf
	jp	unsetZ
