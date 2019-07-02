; pad - read input from MD controller
;
; Conveniently expose an API to read the status of a MD pad A. Moreover,
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

.equ	PAD_UP		0
.equ	PAD_DOWN	1
.equ	PAD_LEFT	2
.equ	PAD_RIGHT	3
.equ	PAD_BUTB	4
.equ	PAD_BUTC	5
.equ	PAD_BUTA	6
.equ	PAD_START	7

; *** Variables ***
;
; Button status of last padUpdateSel call. Used for debouncing.
.equ	PAD_SELSTAT	PAD_RAMSTART
; Button status of last padGetC call.
.equ	PAD_GETCSTAT	PAD_SELSTAT+1
; Current selection "class". 0 = lowcase, 1 = upcase, 2 = num, 3 = symbols
.equ	PAD_SELCLASS	PAD_GETCSTAT+1
; Current selected character
.equ	PAD_SELCHR	PAD_SELCLASS+1
; Whether current sel is "new", that is, that its value has never been fetched
; though padUpdateSel. This flag is set when "avancing" in GetC and also on
; module init.
.equ	PAD_SELNEW	PAD_SELCHR+1
.equ	PAD_RAMEND	PAD_SELNEW+1

; *** Code ***

padInit:
	ld	a, 0xff
	ld	(PAD_SELSTAT), a
	ld	(PAD_GETCSTAT), a
	ld	(PAD_SELNEW), a
	xor	a
	ld	(PAD_SELCLASS), a
	ld	a, 'a'
	ld	(PAD_SELCHR), a
	ret

; Put status for port A in register A. Bits, from MSB to LSB:
; Start - A - C - B - Right - Left - Down - Up
; Each bit is high when button is unpressed and low if button is pressed. For
; example, when no button is pressed, 0xff is returned.
padStatus:
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
	pop	bc
	ret

; From a pad status in A, update current char selection and return it.
; Returns the same Z as padStatus: set if unchanged, unset if changed
padUpdateSel:
	; special case: when selnew is set, always return current sel and
	; disable selnew
	ld	a, (PAD_SELNEW)
	or	a
	jr	z, .notnew
	; selection is new, return it
	xor	a
	ld	(PAD_SELNEW), a
	ld	a, (PAD_SELCHR)
	jp	unsetZ
.notnew:
	call	padStatus
	push	hl
	ld	hl, PAD_SELSTAT
	cp	(hl)
	ld	(hl), a
	pop	hl
	jr	z, .nothing	; nothing changed
	bit	PAD_UP, a
	jr	z, .up
	bit	PAD_DOWN, a
	jr	z, .down
	bit	PAD_LEFT, a
	jr	z, .left
	bit	PAD_RIGHT, a
	jr	z, .right
	jr	.nothing
.up:
	ld	a, (PAD_SELCHR)
	inc	a
	jr	.setchr
.down:
	ld	a, (PAD_SELCHR)
	dec	a
	jr	.setchr
.left:
	ld	a, (PAD_SELCHR)
	dec	a \ dec a \ dec a \ dec a \ dec a
	jr	.setchr
.right:
	ld	a, (PAD_SELCHR)
	inc	a \ inc a \ inc a \ inc a \ inc a
	jr	.setchr
.setchr:
	ld	(PAD_SELCHR), a
	jp	unsetZ
.nothing:
	cp	a		; ensure Z
	ld	a, (PAD_SELCHR)
	ret

padGetC:
	call	padStatus
	push	hl
	ld	hl, PAD_GETCSTAT
	cp	(hl)
	ld	(hl), a
	pop	hl
	jp	z, unsetZ	; nothing changed
	bit	PAD_BUTC, a
	jr	z, .advance
	bit	PAD_BUTA, a
	jr	z, .backspace
	bit	PAD_START, a
	jr	z, .return
	jp	unsetZ
.advance:
	ld	a, 1
	ld	(PAD_SELNEW), a
	ld	a, (PAD_SELCHR)
	cp	a
	ret
.backspace:
	ld	a, ASCII_BS
	cp	a
	ret
.return:
	ld	a, ASCII_LF
	cp	a
	ret
