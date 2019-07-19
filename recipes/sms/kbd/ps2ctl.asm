.include "tn45def.inc"

; Receives keystrokes from PS/2 keyboard and send them to the '164. On the PS/2
; side, it works the same way as the controller in the rc2014/ps2 recipe.
; However, in this case, what we have on the other side isn't a z80 bus, it's
; the one of the two controller ports of the SMS through a DB9 connector.

; The PS/2 related code is copied from rc2014/ps2 without much change. The only
; differences are that it pushes its data to a '164 instead of a '595 and that
; it synchronizes with the SMS with a SR latch, so we don't need PCINT. We can
; also afford to run at 1MHz instead of 8.

; *** Register Usage ***
;
; GPIOR0 flags:
;	0 - when set, indicates that the DATA pin was high when we received a
;           bit through INT0. When we receive a bit, we set flag T to indicate
;           it.
;
; R16: tmp stuff
; R17: recv buffer. Whenever we receive a bit, we push it in there.
; R18: recv step:
;      - 0: idle
;      - 1: receiving data
;      - 2: awaiting parity bit
;      - 3: awaiting stop bit
; R19: Register used for parity computations and tmp value in some other places
; R20: data being sent to the '164
; Y: pointer to the memory location where the next scan code from ps/2 will be
;    written.
; Z: pointer to the next scan code to push to the 595
;
; *** Constants ***
.equ	CLK = PINB2
.equ	DATA = PINB1
.equ	CP = PINB3
; SR-Latch's Q pin
.equ	LQ = PINB0
; SR-Latch's R pin
.equ	LR = PINB4

; init value for TCNT0 so that overflow occurs in 100us
.equ	TIMER_INITVAL = 0x100-100

; *** Code ***

	rjmp	main
	rjmp	hdlINT0

; Read DATA and set GPIOR0/0 if high. Then, set flag T.
; no SREG fiddling because no SREG-modifying instruction
hdlINT0:
	sbic	PINB, DATA	; DATA clear? skip next
	sbi	GPIOR0, 0
	set
	reti

main:
        ldi     r16, low(RAMEND)
        out     SPL, r16
        ldi     r16, high(RAMEND)
        out     SPH, r16

	; init variables
	clr	r18
	out	GPIOR0, r18

	; Setup int0
	; INT0, falling edge
	ldi	r16, (1<<ISC01)
	out	MCUCR, r16
	; Enable INT0
	ldi	r16, (1<<INT0)
	out	GIMSK, r16

	; Setup buffer
	clr	YH
	ldi	YL, low(SRAM_START)
	clr	ZH
	ldi	ZL, low(SRAM_START)

	; Setup timer. We use the timer to clear up "processbit" registers after
	; 100us without a clock. This allows us to start the next frame in a
	; fresh state. at 1MHZ, no prescaling is necessary. Each TCNT0 tick is
	; already 1us long.
	ldi	r16, (1<<CS00)	; no prescaler
	out	TCCR0B, r16

	; init DDRB
	sbi	DDRB, CP
	cbi	PORTB, LR
	sbi	DDRB, LR

	sei

loop:
	brts	processbit	; flag T set? we have a bit to process
	cp	YL, ZL		; if YL == ZL, buffer is empty
	brne	sendTo164	; YL != ZL? our buffer has data

	; nothing to do. Before looping, let's check if our communication timer
	; overflowed.
	in	r16, TIFR
	sbrc	r16, TOV0
	rjmp	processbitReset	; Timer0 overflow? reset processbit

	; Nothing to do for real.
	rjmp	loop

; Process the data bit received in INT0 handler.
processbit:
	in	r19, GPIOR0	; backup GPIOR0 before we reset T
	andi	r19, 0x1	; only keep the first flag
	cbi	GPIOR0, 0
	clt			; ready to receive another bit

	; We've received a bit. reset timer
	rcall	resetTimer

	; Which step are we at?
	tst	r18
	breq	processbits0
	cpi	r18, 1
	breq	processbits1
	cpi	r18, 2
	breq	processbits2
	; step 3: stop bit
	clr	r18		; happens in all cases
	; DATA has to be set
	tst	r19		; Was DATA set?
	breq	loop		; not set? error, don't push to buffer
	; push r17 to the buffer
	st	Y+, r17
	rcall	checkBoundsY
	rjmp	loop

processbits0:
	; step 0 - start bit
	; DATA has to be cleared
	tst	r19		; Was DATA set?
	brne	loop		; Set? error. no need to do anything. keep r18
				; as-is.
	; DATA is cleared. prepare r17 and r18 for step 1
	inc	r18
	ldi	r17, 0x80
	rjmp	loop

processbits1:
	; step 1 - receive bit
	; We're about to rotate the carry flag into r17. Let's set it first
	; depending on whether DATA is set.
	clc
	sbrc	r19, 0		; skip if DATA cleared.
	sec
	; Carry flag is set
	ror	r17
	; Good. now, are we finished rotating? If carry flag is set, it means
	; that we've rotated in 8 bits.
	brcc	loop		; we haven't finished yet
	; We're finished, go to step 2
	inc	r18
	rjmp	loop
processbits2:
	; step 2 - parity bit
	mov	r1, r19
	mov	r19, r17
	rcall	checkParity	; --> r16
	cp	r1, r16
	brne	processbitError	; r1 != r16? wrong parity
	inc	r18
	rjmp	loop

processbitError:
	clr	r18
	ldi	r19, 0xfe
	rcall	sendToPS2
	rjmp	loop

processbitReset:
	clr	r18
	rcall	resetTimer
	rjmp	loop

; Send the value of r20 to the '164
sendTo164:
	sbis	PINB, LQ	; LQ is set? we can send the next byte
	rjmp	loop		; Even if we have something in the buffer, we
				; can't: the SMS hasn't read our previous
				; buffer yet.
	; We disable any interrupt handling during this routine. Whatever it
	; is, it has no meaning to us at this point in time and processing it
	; might mess things up.
	cli
	sbi	DDRB, DATA

	ld	r20, Z+
	rcall	checkBoundsZ
	ldi	r16, 8

sendTo164Loop:
	cbi	PORTB, DATA
	sbrc	r20, 7		; if leftmost bit isn't cleared, set DATA high
	sbi	PORTB, DATA
	; toggle CP
	cbi	PORTB, CP
	lsl	r20
	sbi	PORTB, CP
	dec	r16
	brne	sendTo164Loop	; not zero yet? loop

	; release PS/2
	cbi	DDRB, DATA
	sei

	; Reset the latch to indicate that the next number is ready
	sbi	PORTB, LR
	cbi	PORTB, LR
	rjmp	loop

resetTimer:
	ldi	r16, TIMER_INITVAL
	out	TCNT0, r16
	ldi	r16, (1<<TOV0)
	out	TIFR, r16
	ret

; Send the value of r19 to the PS/2 keyboard
sendToPS2:
	cli

	; First, indicate our request to send by holding both Clock low for
	; 100us, then pull Data low
	; lines low for 100us.
	cbi	PORTB, CLK
	sbi	DDRB, CLK
	rcall	resetTimer

	; Wait until the timer overflows
	in	r16, TIFR
	sbrs	r16, TOV0
	rjmp	PC-2
	; Good, 100us passed.

	; Pull Data low, that's our start bit.
	cbi	PORTB, DATA
	sbi	DDRB, DATA

	; Now, let's release the clock. At the next raising edge, we'll be
	; expected to have set up our first bit (LSB). We set up when CLK is
	; low.
	cbi	DDRB, CLK	; Should be starting high now.

	; We will do the next loop 8 times
	ldi	r16, 8
	; Let's remember initial r19 for parity
	mov	r1, r19

sendToPS2Loop:
	; Wait for CLK to go low
	sbic	PINB, CLK
	rjmp	PC-1

	; set up DATA
	cbi	PORTB, DATA
	sbrc	r19, 0		; skip if LSB is clear
	sbi	PORTB, DATA
	lsr	r19

	; Wait for CLK to go high
	sbis	PINB, CLK
	rjmp	PC-1

	dec	r16
	brne	sendToPS2Loop	; not zero? loop

	; Data was sent, CLK is high. Let's send parity
	mov	r19, r1		; recall saved value
	rcall	checkParity	; --> r16

	; Wait for CLK to go low
	sbic	PINB, CLK
	rjmp	PC-1

	; set parity bit
	cbi	PORTB, DATA
	sbrc	r16, 0		; parity bit in r16
	sbi	PORTB, DATA

	; Wait for CLK to go high
	sbis	PINB, CLK
	rjmp	PC-1

	; Wait for CLK to go low
	sbic	PINB, CLK
	rjmp	PC-1

	; We can now release the DATA line
	cbi	DDRB, DATA

	; Wait for DATA to go low. That's our ACK
	sbic	PINB, DATA
	rjmp	PC-1

	; Wait for CLK to go low
	sbic	PINB, CLK
	rjmp	PC-1

	; We're finished! Enable INT0, reset timer, everything back to normal!
	rcall	resetTimer
	clt			; also, make sure T isn't mistakely set.
	sei
	ret

; Check that Y is within bounds, reset to SRAM_START if not.
checkBoundsY:
	tst	YL
	breq	PC+2
	ret			; not zero, nothing to do
	; YL is zero. Reset Y
	clr	YH
	ldi	YL, low(SRAM_START)
	ret

; Check that Z is within bounds, reset to SRAM_START if not.
checkBoundsZ:
	tst	ZL
	breq	PC+2
	ret			; not zero, nothing to do
	; ZL is zero. Reset Z
	clr	ZH
	ldi	ZL, low(SRAM_START)
	ret

; Counts the number of 1s in r19 and set r16 to 1 if there's an even number of
; 1s, 0 if they're odd.
checkParity:
	ldi	r16, 1
	lsr	r19
	brcc	PC+2		; Carry unset? skip next
	inc	r16		; Carry set? We had a 1
	tst	r19		; is r19 zero yet?
	brne	checkParity+1	; no? loop and skip first LDI
	andi	r16, 0x1	; Sets Z accordingly
	ret

