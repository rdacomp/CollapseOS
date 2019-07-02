; pad - read input from MD controller
;
; Conveniently expose an API to read the status of a MD pad. Moreover,
; implement a mechanism to input arbitrary characters from it. It goes as
; follow:
;
; * Direction pad select characters. Up/Down move by one, Left/Right move by 5\
; * Start acts like Return
; * A acts like Backspace
; * B changes "character class": lowercase, uppercase, numbers, special chars.
;   The space character is the first among special chars.
; * C confirms letter selection
;
; *** Consts ***
;
.equ	PAD_CTLPORT	0x3f
.equ	PAD_D1PORT	0xdc

; *** Variables ***
;
; *** Code ***

; Put status for port A in register A. Bits, from MSB to LSB:
; Start - A - C - B - Right - Left - Down - Up
; Each bit is high when button is unpressed and low if button is pressed. For
; example, when no button is pressed, 0xff is returned.
padStatusA:
	; This logic below is for the Genesis controller, which is modal. TH is
	; an output pin that swiches the meaning of TL and TR. When TH is high
	; (unselected), TL = Button B and TR = Button C. When TH is low
	; (selected), TL = Button A and TR = Start.
	push	bc
	ld	a, 0b11111101	; TH output, unselected
	out	(PAD_CTLPORT), a
	in	a, (PAD_D1PORT)
	and	0x3f		; low 6 bits are good
	ld	b, a		; let's store them
	; Start and A are returned when TH is selected, in bits 5 and 4. Well
	; get them, left-shift them and integrate them to B.
	ld	a, 0b11011101	; TH output, selected
	out	(PAD_CTLPORT), a
	in	a, (PAD_D1PORT)
	and	0b00110000
	sla	a
	sla	a
	or	b
	; we're good now!
	pop	bc
	ret
