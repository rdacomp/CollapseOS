; I/Os in zasm
;
; As a general rule, I/O in zasm is pretty straightfoward. We receive, as a
; parameter, two blockdevs: One that we can read and seek and one that we can
; write to (we never seek into it).
;
; This unit also has the responsibility of counting the number of written bytes,
; maintaining IO_PC and of properly disabling output on first pass.
;
; On top of that, this unit has the responsibility of keeping track of the
; current lineno. Whenever GetC is called, we check if the fetched char is a
; newline. If it is, we increase our lineno. This unit is the best place to
; keep track of this because we have to handle ioRecallPos.
;
; zasm doesn't buffers its reads during tokenization, which simplifies its
; process. However, it also means that it needs, in certain cases, a "putback"
; mechanism, that is, a way to say "you see that character I've just read? that
; was out of my bounds. Could you make it as if I had never read it?". That
; buffer is one character big and is made with the expectation that ioPutBack
; is always called right after a ioGetC (when it's called).
;
; ioPutBack will mess up seek and tell offsets, so thath "put back" should be
; consumed before having to seek and tell.
;
; That's for the general rules.
;
; Now, let's enter includes. To simplify processing, we make include mostly
; transparent to all other units. They always read from ioGetC and a include
; directive should have the exact same effect as copy/pasting the contents of
; the included file in the caller.
;
; By the way: we don't support multiple level of inclusion. Only top level files
; can include.
;
; When we include, all we do here is open the file with fsOpen and set a flag
; indicating that we're inside an include. When that flag is on, GetC, Seek and
; Tell are transparently redirected to their fs* counterpart.
;
; When we reach EOF in an included file, we transparently unset the "in include"
; flag and continue on the general IN stream.

; *** Variables ***
.equ	IO_IN_GETC	IO_RAMSTART
.equ	IO_IN_PUTC	IO_IN_GETC+2
.equ	IO_IN_SEEK	IO_IN_PUTC+2
.equ	IO_IN_TELL	IO_IN_SEEK+2
.equ	IO_OUT_GETC	IO_IN_TELL+2
.equ	IO_OUT_PUTC	IO_OUT_GETC+2
.equ	IO_OUT_SEEK	IO_OUT_PUTC+2
.equ	IO_OUT_TELL	IO_OUT_SEEK+2
; Save pos for ioSavePos and ioRecallPos
.equ	IO_SAVED_POS	IO_OUT_TELL+2
; File handle for included source
.equ	IO_INCLUDE_HDL	IO_SAVED_POS+2
; see ioPutBack below
.equ	IO_PUTBACK_BUF	IO_INCLUDE_HDL+FS_HANDLE_SIZE
.equ	IO_IN_INCLUDE	IO_PUTBACK_BUF+1
.equ	IO_PC		IO_IN_INCLUDE+1
; Current lineno in top-level file
.equ	IO_LINENO	IO_PC+2
; Line number (can be top-level or include) when ioSavePos was last called.
.equ	IO_SAVED_LINENO	IO_LINENO+2
.equ	IO_RAMEND	IO_SAVED_LINENO+2

; *** Code ***

ioInit:
	xor	a
	ld	(IO_PUTBACK_BUF), a
	ld	(IO_IN_INCLUDE), a
	jp	ioResetCounters

ioGetC:
	ld	a, (IO_PUTBACK_BUF)
	or	a		; cp 0
	jr	nz, .getback
	call	ioInInclude
	jr	z, .normalmode
	; We're in "include mode", read from FS
	push	de
	ld	de, IO_INCLUDE_HDL
	call	fsGetC
	pop	de
	or	a		; cp 0
	ret	nz		; not zero, all good
	; We reached EOF. What we do depends on whether we're in Local Pass
	; mode. Yes, I know, a bit hackish. Normally, we *should* be
	; transparently getting of include mode and avoid meddling with global
	; states, but here, we need to tell main.asm that the local scope if
	; over *before* we get off include mode, otherwise, our IO_SAVED_POS
	; will be wrong (an include IO_SAVED_POS used in global IN stream).
	call	zasmIsLocalPass
	ld	a, 0			; doesn't affect Z flag
	ret	z			; local pass? return EOF
	; regular pass (first or second)? transparently get off include mode.
	ld	(IO_IN_INCLUDE), a	; A already 0
	; continue on to "normal" reading. We don't want to return our zero
.normalmode:
	; normal mode, read from IN stream
	ld	ix, (IO_IN_GETC)
	call	_callIX
	cp	0x0a		; newline
	ret	nz		; not newline? return
	; inc current lineno
	push	hl
	ld	hl, IO_LINENO
	inc	(hl)
	pop	hl
	cp	a		; ensure Z
	ret

.getback:
	push	af
	xor	a
	ld	(IO_PUTBACK_BUF), a
	pop	af
	ret

_callIX:
	jp	(ix)
	ret

; Put back non-zero character A into the "ioGetC stack". The next ioGetC call,
; instead of reading from IO_IN_GETC, will return that character. That's the
; easiest way I found to handle the readWord/gotoNextLine problem.
ioPutBack:
	ld	(IO_PUTBACK_BUF), a
	ret

ioPutC:
	push	hl
	ld	hl, (IO_PC)
	inc	hl
	ld	(IO_PC), hl
	pop	hl
	push	af
	call	zasmIsFirstPass
	jr	z, .skip
	pop	af
	ld	ix, (IO_OUT_PUTC)
	jp	(ix)
.skip:
	pop	af
	ret

ioSavePos:
	ld	hl, (IO_LINENO)
	ld	(IO_SAVED_LINENO), hl
	call	_ioTell
	ld	(IO_SAVED_POS), hl
	ret

ioRecallPos:
	ld	hl, (IO_SAVED_LINENO)
	ld	(IO_LINENO), hl
	ld	hl, (IO_SAVED_POS)
	jr	_ioSeek

ioRewind:
	call	ioResetCounters		; sets HL to 0
	jr	_ioSeek

ioResetCounters:
	ld	hl, 0
	ld	(IO_PC), hl
	ld	(IO_LINENO), hl
	ld	(IO_SAVED_LINENO), hl
	ret

; always in absolute mode (A = 0)
_ioSeek:
	call	ioInInclude
	ld	a, 0		; don't alter flags
	jr	nz, .include
	; normal mode, seek in IN stream
	ld	ix, (IO_IN_SEEK)
	jp	(ix)
.include:
	; We're in "include mode", seek in FS
	push	de
	ld	de, IO_INCLUDE_HDL
	call	fsSeek
	pop	de
	ret

_ioTell:
	call	ioInInclude
	jp	nz, .include
	; normal mode, seek in IN stream
	ld	ix, (IO_IN_TELL)
	jp	(ix)
.include:
	; We're in "include mode", tell from FS
	push	de
	ld	de, IO_INCLUDE_HDL
	call	fsTell
	pop	de
	ret

; Sets Z according to whether we're inside an include
ioInInclude:
	ld	a, (IO_IN_INCLUDE)
	or	a		; cp 0
	ret

; Open include file name specified in (HL).
; Sets Z on success, unset on error.
ioOpenInclude:
	call	fsFindFN
	ret	nz
	ld	hl, IO_INCLUDE_HDL
	call	fsOpen
	ld	a, 1
	ld	(IO_IN_INCLUDE), a
	cp	a		; ensure Z
	ret

; Return current lineno in HL
ioLineNo:
	ld	hl, (IO_LINENO)
	ret
