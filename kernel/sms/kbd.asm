; kbd - implement FetchKC for SMS PS/2 adapter
;
; Implements KBD_FETCHKC for the adapter described in recipe sms/kbd. It does
; so for both Port A and Port B (you hook whichever you prefer).

; FetchKC on Port A
smskbdFetchKCA:
	; Before reading a character, we must first verify that there is
	; something to read. When the adapter is finished filling its '164 up,
	; it resets the latch, which output's is connected to TL. When the '164
	; is full, TL is low.
	; Port A TL is bit 4
	in	a, (0xdc)
	and	0b00010000
	jr	nz, .nothing

	push	bc
	in	a, (0x3f)
	; Port A TH output, low
	ld	a, 0b11011101
	out	(0x3f), a
	nop
	nop
	in	a, (0xdc)
	; bit 3:0 are our dest bits 3:0. handy...
	and	0b00001111
	ld	b, a
	; Port A TH output, high
	ld	a, 0b11111101
	out	(0x3f), a
	nop
	nop
	in	a, (0xdc)
	; bit 3:0 are our dest bits 7:4
	rlca \ rlca \ rlca \ rlca
	and	0b11110000
	or	b
	ex	af, af'
	; Port A/B reset
	ld	a, 0xff
	out	(0x3f), a
	ex	af, af'
	pop	bc
	ret

.nothing:
	xor	a
	ret

; FetchKC on Port B
smskbdFetchKCB:
	; Port B TL is bit 2
	in	a, (0xdd)
	and	0b00000100
	jr	nz, .nothing

	push	bc
	in	a, (0x3f)
	; Port B TH output, low
	ld	a, 0b01110111
	out	(0x3f), a
	nop
	nop
	in	a, (0xdc)
	; bit 7:6 are our dest bits 1:0
	rlca \ rlca
	and	0b00000011
	ld	b, a
	in	a, (0xdd)
	; bit 1:0 are our dest bits 3:2
	rlca \ rlca
	and	0b00001100
	or	b
	ld	b, a
	; Port B TH output, high
	ld	a, 0b11110111
	out	(0x3f), a
	nop
	nop
	in	a, (0xdc)
	; bit 7:6 are our dest bits 5:4
	rrca \ rrca
	and	0b00110000
	or	b
	ld	b, a
	in	a, (0xdd)
	; bit 1:0 are our dest bits 7:6
	rrca \ rrca
	and	0b11000000
	or	b
	ex	af, af'
	; Port A/B reset
	ld	a, 0xff
	out	(0x3f), a
	ex	af, af'
	pop	bc
	ret

.nothing:
	xor	a
	ret

