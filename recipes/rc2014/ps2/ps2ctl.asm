.include "tn45def.inc"

; Receives keystrokes from PS/2 keyboard and send them to the 595. As long as
; that number is not collected, we buffer the scan code received from ps/2. As
; soon as that number is collected we put the next number in the buffer. If the
; buffer is empty, we do nothing (the 595 already had its SRCLR pin triggered
; and shows 0).
;
; PS/2 is a bidirectional protocol, but in this program, we only care about
; receiving keystrokes. We don't send anything to the keyboard.
;
; The PS/2 keyboard has two data wires: Clock and Data. It is the keyboard that
; drives the clock with about 30-50 us between each clock.
;
; We wire the Clock to INT0 (PB2) and make it trigger an interrupt on the
; falling edge (the edge, in the PS/2 protocol, when data is set).
;
; Data is sent by the keyboard in 11-bit frames. 1 start bit (0), 8 data bits,
; one parity bit, one stop bit (1).
;
; Parity bit is set if number of bits in data bits is even. Unset otherwise.
;
; *** Receiving a data frame ***
;
; In idle mode, R18 is zero. When INT0 is triggered, it is increased and R17 is
; loaded with 0x80. We do this because we're going to right shift our data in
; (byte is sent LSB first). When the carry flag is set, we'll know we're
; finished. When that happens, we increase R18 again. We're waiting for parity
; bit. When we get it, we check parity and increase R18 again. We're waiting
; for stop bit. After we receive stop bit, we reset R18 to 0.
;
; On error, we ignore and reset our counters.

; *** Buffering scan codes ***
;
; The buffer starts at SRAM and stops at 0x100. It leaves space for the stack
; and makes overflow check easy. Also, we don't need a very big buffer. In this
; address space, Z chasing Y. When Y == Z, the buffer is empty. When 0x100 is
; reached, we go back to SRAM_START.
;
; Whenever a new scan code is received, we place it in Y and increase it.
; Whenever we send a scan code to the 595 (which can't be done when Z == Y
; because Z points to an invalid value), we send the value of Z and increase.

; *** Sending to the 595 ***
;
; Whenever a scan code is read from the 595, CE goes low and triggers a PCINT
; on PB4. When we get it, we clear the GPIOR0/1 flag to indicate that we're
; ready to send a new scan code to the 595.
;
; Because that CE flip/flop is real fast (375ns), it requires us to run at 8MHz.
;
; During the PCINT, we also trigger RCLK once because CE is also wired to SRCLR
; and we want the z80 to be able to know that the device has nothing to give
; (has a value of zero) rather than having to second guess (is this value, which
; is the same as the one that was read before, a new value or not?). With that
; "quick zero-in" scheme, there's no ambiguity: no scan code can be ready twice
; because it's replaced by a 0 as soon as it's read, until it can be filled with
; the next char in the buffer.

; *** Register Usage ***
;
; GPIOR0 flags:
;	0 - when set, indicates that the DATA pin was high when we received a
;           bit through INT0. When we receive a bit, we set flag T to indicate
;           it.
;	1 - When set, indicate that the 595 holds a value that hasn't been read
;           by the z80 yet.
;
; R16: tmp stuff
; R17: recv buffer. Whenever we receive a bit, we push it in there.
; R18: recv step:
;      - 0: idle
;      - 1: receiving data
;      - 2: awaiting parity bit
;      - 3: awaiting stop bit
;      it reaches 11, we know we're finished with the frame.
; R19: Register used for parity computations and tmp value in some other places
; R20: data being sent to the 595
; Y: pointer to the memory location where the next scan code from ps/2 will be
;    written.
; Z: pointer to the next scan code to push to the 595
;
; *** Constants ***
;
.equ	CLK = PINB2
.equ	DATA = PINB1
.equ	SRCLK = PINB3
.equ	CE = PINB4
.equ	RCLK = PINB0

; init value for TCNT0 so that overflow occurs in 100us
.equ	TIMER_INITVAL = 0x100-100

	rjmp	main
	rjmp	hdlINT0
	rjmp	hdlPCINT

; Read DATA and set GPIOR0/0 if high. Then, set flag T.
; no SREG fiddling because no SREG-modifying instruction
hdlINT0:
	sbic	PINB, DATA	; DATA clear? skip next
	sbi	GPIOR0, 0
	set
	reti

; Only PB4 is hooked to PCINT and we don't bother checking the value of the PB4
; pin: things go too fast for this.
; no SREG fiddling because no SREG-modifying instruction
hdlPCINT:
	; SRCLR has been triggered. Let's trigger RCLK too.
	sbi	PORTB, RCLK
	cbi	PORTB, RCLK
	cbi	GPIOR0, 1	; 595 is now free
	reti

main:
        ldi     r16, low(RAMEND)
        out     SPL, r16
        ldi     r16, high(RAMEND)
        out     SPH, r16

	; Set clock prescaler to 1 (8MHz)
	ldi	r16, (1<<CLKPCE)
	out	CLKPR, r16
	clr	r16
	out	CLKPR, r16


	; init variables
	clr	r18
	out	GPIOR0, r18


	; Setup int0/PCINT
	; INT0, falling edge
	ldi	r16, (1<<ISC01)
	out	MCUCR, r16
	; Enable both INT0 and PCINT
	ldi	r16, (1<<INT0)|(1<<PCIE)
	out	GIMSK, r16
	; For PCINT, enable only PB4
	ldi	r16, (1<<PCINT4)
	out	PCMSK, r16

	; Setup buffer
	clr	YH
	ldi	YL, low(SRAM_START)
	clr	ZH
	ldi	ZL, low(SRAM_START)

	; Setup timer. We use the timer to clear up "processbit" registers after
	; 100us without a clock. This allows us to start the next frame in a
	; fresh state. at 8MHZ, setting the counter's prescaler to 8 gives us
	; a nice 1us for each TCNT0.
	ldi	r16, (1<<CS01)	; clk/8 prescaler
	out	TCCR0B, r16

	; init DDRB
	sbi	DDRB, SRCLK
	cbi	PORTB, RCLK	; RCLK is generally kept low
	sbi	DDRB, RCLK

	sei

loop:
	brts	processbit	; flag T set? we have a bit to process
	cp	YL, ZL		; if YL == ZL, buffer is empty
	brne	sendTo595	; YL != ZL? our buffer has data
	in	r16, TIFR
	sbrc	r16, TOV0
	rjmp	processbitReset	; Timer0 overflow? reset processbit
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

; send next scan code in buffer to 595, MSB.
sendTo595:
	sbic	GPIOR0, 1
	rjmp	loop		; flag 1 set? 595 is "busy". Don't send.
	; We disable any interrupt handling during this routine. Whatever it
	; is, it has no meaning to us at this point in time and processing it
	; might mess things up.
	cli
	sbi	DDRB, DATA

	ld	r20, Z+
	rcall	checkBoundsZ
	ldi	r16, 8

sendTo595Loop:
	cbi	PORTB, DATA
	sbrc	r20, 7		; if leftmost bit isn't cleared, set DATA high
	sbi	PORTB, DATA
	; toggle SRCLK
	cbi	PORTB, SRCLK
	lsl	r20
	sbi	PORTB, SRCLK
	dec	r16
	brne	sendTo595Loop	; not zero yet? loop

	; We're finished sending our data to the 595 and we're ready to go back
	; to business as usual. However, timing is important here. The z80 is
	; very fast and constantly hammers our 595 with polls. While this
	; routine was running, it was getting zeroes, which is fine, but as soon
	; as we trigger RCLK, the z80 is going to fetch that value. What we want
	; to do is to enable back the interrupts as soon as RCLK is triggered
	; so that the z80 doesn't have enough time to poll twice. If it did, we
	; would return a double character. This is why RCLK triggering is the
	; last operation.

	; release PS/2
	cbi	DDRB, DATA

	; Set GPIOR0/1 to "595 is busy"
	sbi	GPIOR0, 1

	; toggle RCLK
	sbi	PORTB, RCLK
	cbi	PORTB, RCLK
	sei

	rjmp	loop

resetTimer:
	ldi	r16, TIMER_INITVAL
	out	TCNT0, r16
	ldi	r16, (1<<TOV0)
	out	TIFR, r16
	ret

; Send the value of r19 to the PS/2 keyboard
sendToPS2:
	; We don't use the general INT0 mechanism here. However, we still want
	; to listen to PCINT, so we don't disable interrupts entirely, just
	; INT0.
	ldi	r16, (1<<PCIE)
	out	GIMSK, r16

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
	ldi	r16, (1<<INT0)|(1<<PCIE)
	out	GIMSK, r16
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

