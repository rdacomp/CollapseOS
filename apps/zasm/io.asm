; *** Variables ***
.equ	IO_IN_GETC	IO_RAMSTART
.equ	IO_IN_PUTC	IO_IN_GETC+2
.equ	IO_IN_SEEK	IO_IN_PUTC+2
.equ	IO_IN_TELL	IO_IN_SEEK+2
.equ	IO_OUT_GETC	IO_IN_TELL+2
.equ	IO_OUT_PUTC	IO_OUT_GETC+2
.equ	IO_OUT_SEEK	IO_OUT_PUTC+2
.equ	IO_OUT_TELL	IO_OUT_SEEK+2
; see ioPutBack below
.equ	IO_PUTBACK_BUF	IO_OUT_TELL+2
.equ	IO_RAMEND	IO_PUTBACK_BUF+1

; *** Code ***

ioInit:
	xor	a
	ld	(IO_PUTBACK_BUF), a
	ret

ioGetC:
	ld	a, (IO_PUTBACK_BUF)
	or	a		; cp 0
	jr	nz, .getback
	ld	ix, (IO_IN_GETC)
	jp	(ix)
.getback:
	push	af
	xor	a
	ld	(IO_PUTBACK_BUF), a
	pop	af
	ret

; Put back non-zero character A into the "ioGetC stack". The next ioGetC call,
; instead of reading from IO_IN_GETC, will return that character. That's the
; easiest way I found to handle the readWord/gotoNextLine problem.
ioPutBack:
	ld	(IO_PUTBACK_BUF), a
	ret

ioPutC:
	ld	ix, (IO_OUT_PUTC)
	jp	(ix)

ioSeek:
	ld	ix, (IO_IN_SEEK)
	jp	(ix)

ioTell:
	ld	ix, (IO_IN_TELL)
	jp	(ix)
