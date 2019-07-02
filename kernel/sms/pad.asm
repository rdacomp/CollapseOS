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
; Current selected character
.equ	PAD_SELCHR	PAD_GETCSTAT+1
; When non-zero, will be the next char returned in GetC. So far, only used for
; LF that is feeded when Start is pressed.
.equ	PAD_NEXTCHR	PAD_SELCHR+1
.equ	PAD_RAMEND	PAD_NEXTCHR+1

; *** Code ***

padInit:
	ld	a, 0xff
	ld	(PAD_SELSTAT), a
	ld	(PAD_GETCSTAT), a
	xor	a
	ld	(PAD_NEXTCHR), a
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
	bit	PAD_BUTB, a
	jr	z, .nextclass
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
.nextclass:
	; Go to the beginning of the next "class" of characters
	push	bc
	ld	a, (PAD_SELCHR)
	ld	b, '0'
	cp	b
	jr	c, .setclass	; A < '0'
	ld	b, ':'
	cp	b
	jr	c, .setclass
	ld	b, 'A'
	cp	b
	jr	c, .setclass
	ld	b, '['
	cp	b
	jr	c, .setclass
	ld	b, 'a'
	cp	b
	jr	c, .setclass
	ld	b, ' '
	; continue to .setclass
.setclass:
	ld	a, b
	pop	bc
	; continue to .setchr
.setchr:
	; check range first
	cp	0x7f
	jr	nc, .tooHigh
	cp	0x20
	jr	nc, .setchrEnd	; not too low
	; too low, probably because we overdecreased. Let's roll over
	ld	a, '~'
	jr	.setchrEnd
.tooHigh:
	; too high, probably because we overincreased. Let's roll over
	ld	a, ' '
	; continue to .setchrEnd
.setchrEnd:
	ld	(PAD_SELCHR), a
	jp	unsetZ
.nothing:
	cp	a		; ensure Z
	ld	a, (PAD_SELCHR)
	ret

padGetC:
	ld	a, (PAD_NEXTCHR)
	or	a
	jr	nz, .nextchr
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
.return:
	ld	a, ASCII_LF
	ld	(PAD_NEXTCHR), a
	; continue to .advance
.advance:
	ld	a, (PAD_SELCHR)
	cp	a
	ret
.backspace:
	ld	a, ASCII_BS
	cp	a
	ret
.nextchr:
	; We have a "next char", return it and clear it.
	cp	a		; ensure Z
	push	af
	xor	a
	ld	(PAD_NEXTCHR), a
	pop	af
	ret
