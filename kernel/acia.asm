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
; size of the input buffer. If our input goes over this size, we start losing
; data.
.equ	ACIA_BUFSIZE	0x20

; *** VARIABLES ***
; Our input buffer starts there. This is a circular buffer.
.equ	ACIA_BUF	ACIA_RAMSTART

; The "read" index of the circular buffer. It points to where the next char
; should be read. If rd == wr, the buffer is empty. Not touched by the
; interrupt.
.equ	ACIA_BUFRDIDX	ACIA_BUF+ACIA_BUFSIZE
; The "write" index of the circular buffer. Points to where the next char
; should be written. Should only be touched by the interrupt. if wr == rd-1,
; the interrupt will *not* write in the buffer until some space has been freed.
.equ	ACIA_BUFWRIDX	ACIA_BUFRDIDX+1
.equ	ACIA_RAMEND	ACIA_BUFWRIDX+1

aciaInit:
	; initialize variables
	xor	a
	ld	(ACIA_BUFRDIDX), a	; starts at 0
	ld	(ACIA_BUFWRIDX), a

	; setup ACIA
	; CR7 (1) - Receive Interrupt enabled
	; CR6:5 (00) - RTS low, transmit interrupt disabled.
	; CR4:2 (101) - 8 bits + 1 stop bit
	; CR1:0 (10) - Counter divide: 64
	ld	a, 0b10010110
	out	(ACIA_CTL), a
	ret

; Increase the circular buffer index in A, properly considering overflow.
; returns value in A.
aciaIncIndex:
	inc	a
	cp	ACIA_BUFSIZE
	ret	nz	; not equal? nothing to do
	; equal? reset
	xor	a
	ret

; read char in the ACIA and put it in the read buffer
aciaInt:
	push	af
	push	hl

	; Read our character from ACIA into our BUFIDX
	in	a, (ACIA_CTL)
	bit	0, a		; is our ACIA rcv buffer full?
	jr	z, .end		; no? a interrupt was triggered for nothing.

	; Load both read and write indexes so we can compare them. To do so, we
	; perform a "fake" read increase and see if it brings it to the same
	; value as the write index.
	ld	a, (ACIA_BUFRDIDX)
	call	aciaIncIndex
	ld	l, a
	ld	a, (ACIA_BUFWRIDX)
	cp	l
	jr	z, .end		; Equal? buffer is full

	push	de		; <|
	; Alrighty, buffer not full|. let's write.
	ld	de, ACIA_BUF	;  |
	; A already contains our wr|ite index, add it to DE
	call	addDE		;  |
	; increase our buf ptr whil|e we still have it in A
	call	aciaIncIndex	;  |
	ld	(ACIA_BUFWRIDX), a ;
				;  |
	; And finally, fetch the va|lue and write it.
	in	a, (ACIA_IO)	;  |
	ld	(de), a		;  |
	pop	de		; <|

.end:
	pop	hl
	pop	af
	ei
	reti


; *** BLOCKDEV ***
; These function below follow the blockdev API.

aciaGetC:
	push	de

	ld	a, (ACIA_BUFWRIDX)
	ld	e, a
	ld	a, (ACIA_BUFRDIDX)
	cp	e
	jr	z, .nothingToRead	; equal? nothing to read.

	; Alrighty, buffer not empty. let's read.
	ld	de, ACIA_BUF
	; A already contains our read index, add it to DE
	call	addDE
	; increase our buf ptr while we still have it in A
	call	aciaIncIndex
	ld	(ACIA_BUFRDIDX), a

	; And finally, fetch the value.
	ld	a, (de)
	cp	a		; ensure Z
	jr	.end

.nothingToRead:
	call	unsetZ
.end:
	pop	de
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

