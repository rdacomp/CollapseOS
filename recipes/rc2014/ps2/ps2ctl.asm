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
; The whole SRAM (from SRAM_START to RAMEND) is used as a scan code buffer, with
; Z chasing Y. When Y == Z, the buffer is empty. When RAMEND is reached, we go
; back to SRAM_START.
;
; Whenever a new scan code is received, we place it in Y and increase it.
; Whenever we send a scan code to the 595 (which can't be done when Z == Y
; because Z points to an invalid value), we send the value of Z and increase.

; *** Sending to the 595 ***
;
; Whenever a scan code is read from the 595, CE goes low and triggers a PCINT
; on PB4. When we get it, we clear the R2 flag to indicate that we're ready to
; send a new scan code to the 595.
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
; R1: when set, indicates that value in R17 is valid
; R2: When set, indicate that the 595 holds a value that hasn't been read by the
;     z80 yet.
; R16: tmp stuff
; R17: recv buffer. Whenever we receive a bit, we push it in there.
; R18: recv step:
;      - 0: idle
;      - 1: receiving data
;      - 2: awaiting parity bit
;      - 3: awaiting stop bit
;      it reaches 11, we know we're finished with the frame.
; R19: when set, indicates that the DATA pin was high when we received a bit
;      through INT0. When we receive a bit, we set flag T to indicate it.
; R20: data being sent to the 595
; Y: pointer to the memory location where the next scan code from ps/2 will be
;    written.
; Z: pointer to last scan code pushed to the 595
;
; *** Constants ***
;
.equ	CLK = PINB2
.equ	DATA = PINB1
.equ	SRCLK = PINB3
.equ	CE = PINB4
.equ	RCLK = PINB0

	rjmp	main
	rjmp	hdlINT0
	rjmp	hdlPCINT

; Read DATA and set R19 if high. Then, set flag T.
; no SREG fiddling because no SREG-modifying instruction
hdlINT0:
	sbic	PINB, DATA	; DATA clear? skip next
	ser	r19
	set
	reti

; Only PB4 is hooked to PCINT and we don't bother checking the value of the PB4
; pin: things go too fast for this.
hdlPCINT:
	; SRCLR has been triggered. Let's trigger RCLK too.
	sbi	PORTB, RCLK
	cbi	PORTB, RCLK
	clr	r2		; 595 is now free

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
	clr	r1
	clr	r2
	clr	r19
	clr	r18

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

	; init DDRB
	sbi	DDRB, SRCLK
	cbi	PORTB, RCLK	; RCLK is generally kept low
	sbi	DDRB, RCLK

	sei

loop:
	brts	processbit	; flag T set? we have a bit to process
	tst	r1
	brne	sendTo595	; r1 is non-zero? char is ready to send
	rjmp	loop

; Process the data bit received in INT0 handler.
processbit:
	mov	r16, r19	; backup r19 before we reset T
	clr	r19
	clt			; ready to receive another bit

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
	tst	r16		; Was DATA set?
	breq	loop		; not set? error, don't inc R1
	inc	r1		; indicate that value in r17 is good
	rjmp	loop
processbits0:
	; step 0 - start bit
	; DATA has to be cleared
	tst	r16		; Was DATA set?
	brne	loop		; Set? error. no need to do anything. keep r18
				; as-is.
	; DATA is cleared. prepare r17 and r18 for step 1
	inc	r18
	ldi	r17, 0x80
	clr	r1
	rjmp	loop

processbits1:
	; step 1 - receive bit
	; We're about to rotate the carry flag into r17. Let's set it first
	; depending on whether DATA is set.
	clc
	sbrc	r16, 0		; skip if DATA cleared.
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
	; TODO: check parity
	inc	r18
	rjmp	loop

; send R17 to 595, MSB.
sendTo595:
	tst	r2
	brne	loop		; non-zero? 595 is "busy". Don't send.
				; TODO: implement buffering. At this moment, the
				; scan code is lost.
	; We disable any interrupt handling during this routine. Whatever it
	; is, it has no meaning to us at this point in time and processing it
	; might mess things up.
	cli
	sbi	DDRB, DATA

	mov	r20, r17
	clr	r1
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

	; toggle RCLK
	sbi	PORTB, RCLK
	cbi	PORTB, RCLK

	; release PS/2
	cbi	DDRB, DATA

	; Set R2 to "595 is busy"
	inc	r2
	sei
	rjmp	loop
