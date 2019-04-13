; shell
;
; Runs a shell over an asynchronous communication interface adapter (ACIA).

; Incomplete. For now, this outputs a welcome prompt and then waits for input.
; Whenever input is CR or LF, we echo back what we've received and empty the
; input buffer. This also happen when the buffer is full.

#include "platform.inc"

; *** CONSTS ***
CR	.equ	0x0d
LF	.equ	0x0a

; size of the input buffer. If our input goes over this size, we echo
; immediately.
BUFSIZE	.equ	0x20

; *** VARIABLES ***
; Our input buffer starts there
INPTBUF		.equ	RAMSTART

; index, in the buffer, where our next character will go. 0 when the buffer is
; empty, BUFSIZE-1 when it's almost full.
BUFIDX		.equ	INPTBUF+BUFSIZE

; *** CODE ***
	jr	init

init:
	; disable interrupts we don't need them
	di

	; setup stack
	ld	hl, RAMEND
	ld	sp, hl

	; initialize variables
	xor	a
	ld	(BUFIDX), a	; starts at 0

	; setup ACIA
	; CR7 (1) - Receive Interrupt disabled
	; CR6:5 (00) - RTS low, transmit interrupt disabled.
	; CR4:2 (101) - 8 bits + 1 stop bit
	; CR1:0 (10) - Counter divide: 64
	ld	a, 0b00010110
	out	(ACIA_CTL), a

	; print prompt
	ld	hl, d_welcome
	call	printstr
	call	printcrlf

mainloop:
	call	readc
	call	chkbuf
	jr	mainloop

; spits character in A in port SER_OUT
printc:
	push	af
.stwait:
	in	a, (ACIA_CTL)	; get status byte from SER
	bit	1, a		; are we still transmitting?
	jr	z, .stwait	; if yes, wait until we aren't
	pop	af
	out	(ACIA_IO), a	; push current char
	ret

; print null-terminated string pointed to by HL
printstr:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	ret	z		; if yes, we're finished
	call	printc
	inc	hl
	jr	printstr
	; no ret because our only way out is ret z above

printcrlf:
	ld	a, CR
	call	printc
	ld	a, LF
	call	printc
	ret

; wait until a char is read in the ACIA and put it in the read buffer
readc:
	; first thing first: is our input buffer full? If yes, we don't even
	; bother reading the ACIA. Something is wrong: we don't process data
	; fast enough.
	ld	a, (BUFIDX)
	cp	BUFSIZE
	ret	z		; if BUFIDX == BUFSIZE, our buffer is full.

	call	getbufptr

	; increase our buf ptr while we still have it in A
	inc	a
	ld	(BUFIDX), a

.loop:
	; Read our character from ACIA into our BUFIDX
	in	a, (ACIA_CTL)
	bit	0, a		; is our ACIA rcv buffer full?
	jr	z, .loop	; no? loop

	in	a, (ACIA_IO)
	ld	(hl), a

	ret

; check if the input buffer is full or ends in CR or LF. If it does, prints it
; back and empty it.
chkbuf:
	ld	a, (BUFIDX)
	cp	0
	ret	z		; BUFIDX is zero? nothing to check.

	cp	BUFSIZE
	jr	z, .do		; if BUFIDX == BUFSIZE? do!

	call	getbufptr
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
	ld	(BUFIDX), a

	; alright, let's go!
	ld	hl, INPTBUF
	call	printstr
	call	printcrlf
	ret

; Set current buffer pointer in HL. The buffer pointer is where our *next* char
; will be written.
getbufptr:
	ld	hl, INPTBUF
	xor	b
	ld	c, a
	add	hl, bc		; hl now points to INPTBUF + BUFIDX
	ret

; *** DATA ***
d_welcome:	.byte	"Welcome to Collapse OS", 0
