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

.fill 0x38-$
	jr	handleInterrupt

init:
	di

	; setup stack
	ld	hl, RAMEND
	ld	sp, hl

	; initialize variables
	xor	a
	ld	(BUFIDX), a	; starts at 0

	; RC2014's serial I/O is based on interrupt mode 1. We'd prefer im 2,
	; but for now, let's go with the simpler im 1.
	im	1

	; setup ACIA
	; CR7 (1) - Receive Interrupt enabled
	; CR6:5 (00) - RTS low, transmit interrupt disabled.
	; CR4:2 (101) - 8 bits + 1 stop bit
	; CR1:0 (10) - Counter divide: 64
	ld	a, 0b10010110
	out	(ACIA_CTL), a

	; print prompt
	ld	hl, d_welcome
	call	printstr
	call	printcrlf

	; alright, ready to receive
	ei

mainloop:
	call	chkbuf
	jr	mainloop

; read char in the ACIA and put it in the read buffer
handleInterrupt:
	push	af
	push	hl

	; Read our character from ACIA into our BUFIDX
	in	a, (ACIA_CTL)
	bit	0, a		; is our ACIA rcv buffer full?
	jr	z, .end		; no? a interrupt was triggered for nothing.

	call	getbufptr	; HL set, A set
	; is our input buffer full? If yes, we don't read anything. Something
	; is wrong: we don't process data fast enough.
	cp	BUFSIZE
	jr	z, .end		; if BUFIDX == BUFSIZE, our buffer is full.

	; increase our buf ptr while we still have it in A
	inc	a
	ld	(BUFIDX), a

	in	a, (ACIA_IO)
	ld	(hl), a

.end:
	pop	hl
	pop	af
	ei
	reti

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


; check if the input buffer is full or ends in CR or LF. If it does, prints it
; back and empty it.
chkbuf:
	call	getbufptr
	cp	0
	ret	z		; BUFIDX is zero? nothing to check.

	cp	BUFSIZE
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
	ld	(BUFIDX), a

	; alright, let's go!
	ld	hl, INPTBUF
	call	printstr
	call	printcrlf
	ret

; Set current buffer pointer in HL. The buffer pointer is where our *next* char
; will be written. A is set to the value of (BUFIDX)
getbufptr:
	push	bc

	ld	a, (BUFIDX)
	ld	hl, INPTBUF
	xor	b
	ld	c, a
	add	hl, bc		; hl now points to INPTBUF + BUFIDX

	pop	bc
	ret

; *** DATA ***
d_welcome:	.byte	"Welcome to Collapse OS", 0
