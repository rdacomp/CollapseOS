; shell
;
; Runs a shell over an asynchronous communication interface adapter (ACIA).

; *** STATUS ***
; Incomplete. This just outputs the welcome prompt then halts

; *** PLATFORM ***
; this is specific to a classic RC2014 setup (8K ROM + 32K RAM). This will be
; reorganized into something better.

RAMEND		.equ	0xa000
ACIA_CTL	.equ	0x80	; Control and status. RS off.
ACIA_IO		.equ	0x81	; Transmit. RS on.

; *** CONSTS ***
CR	.equ	0x0d
LF	.equ	0x0a

; *** CODE ***
	jr	init

init:
	di			; no need for interrupts yet

	; setup stack
	ld	hl, RAMEND
	ld	sp, hl

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
	halt

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

; *** DATA ***
d_welcome:	.byte	"Welcome to Collapse OS", CR, LF, 0
