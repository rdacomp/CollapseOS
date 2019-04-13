; acia
;
; Manage I/O from an asynchronous communication interface adapter (ACIA).
; provides "aciaPutC" to put c char on the ACIA as well as an input buffer.
; You have to call "aciaInt" on interrupt for this module to work well.
;
; "aciaInit" also has to be called on boot, but it doesn't call "ei" and "im 1",
; which is the responsibility of the main asm file, but is needed.

; *** DEFINES ***
; ACIA_CTL: IO port for the ACIA's control registers
; ACIA_IO: IO port for the ACIA's data registers
; ACIA_RAMSTART: Address at which ACIA-related variables should be stored in
;                RAM.

; *** CONSTS ***
; size of the input buffer. If our input goes over this size, we echo
; immediately.
ACIA_BUFSIZE	.equ	0x20

; *** VARIABLES ***
; Our input buffer starts there
ACIA_BUF	.equ	ACIA_RAMSTART

; index, in the buffer, where our next character will go. 0 when the buffer is
; empty, BUFSIZE-1 when it's almost full.
ACIA_BUFIDX	.equ	ACIA_BUF+ACIA_BUFSIZE
ACIA_RAMEND	.equ	ACIA_BUFIDX+1

aciaInit:
	; initialize variables
	xor	a
	ld	(ACIA_BUFIDX), a	; starts at 0

	; setup ACIA
	; CR7 (1) - Receive Interrupt enabled
	; CR6:5 (00) - RTS low, transmit interrupt disabled.
	; CR4:2 (101) - 8 bits + 1 stop bit
	; CR1:0 (10) - Counter divide: 64
	ld	a, 0b10010110
	out	(ACIA_CTL), a
	ret

; read char in the ACIA and put it in the read buffer
aciaInt:
	push	af
	push	hl

	; Read our character from ACIA into our BUFIDX
	in	a, (ACIA_CTL)
	bit	0, a		; is our ACIA rcv buffer full?
	jr	z, .end		; no? a interrupt was triggered for nothing.

	call	aciaBufPtr	; HL set, A set
	; is our input buffer full? If yes, we don't read anything. Something
	; is wrong: we don't process data fast enough.
	cp	ACIA_BUFSIZE
	jr	z, .end		; if BUFIDX == BUFSIZE, our buffer is full.

	; increase our buf ptr while we still have it in A
	inc	a
	ld	(ACIA_BUFIDX), a

	in	a, (ACIA_IO)
	ld	(hl), a

.end:
	pop	hl
	pop	af
	ei
	reti

; Set current buffer pointer in HL. The buffer pointer is where our *next* char
; will be written. A is set to the value of (BUFIDX)
aciaBufPtr:
	push	bc

	ld	a, (ACIA_BUFIDX)
	ld	hl, ACIA_BUF
	xor	b
	ld	c, a
	add	hl, bc		; hl now points to INPTBUF + BUFIDX

	pop	bc
	ret

; spits character in A in port SER_OUT
aciaPutC:
	push	af
.stwait:
	in	a, (ACIA_CTL)	; get status byte from SER
	bit	1, a		; are we still transmitting?
	jr	z, .stwait	; if yes, wait until we aren't
	pop	af
	out	(ACIA_IO), a	; push current char
	ret

