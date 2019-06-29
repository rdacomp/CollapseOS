; kbd - implement GetC for PS/2 keyboard
;
; Status: Work in progress. See recipes/rc2014/ps2
;
; *** Defines ***
; The port of the device where we read scan codes. See recipe rc2014/ps2.
; KBD_PORT

; *** Variables ***
.equ	KBD_SKIP_NEXT	KBD_RAMSTART
.equ	KBD_RAMEND	KBD_SKIP_NEXT+1

kbdInit:
	xor	a
	ld	(KBD_SKIP_NEXT), a
	ret

kbdGetC:
	in	a, (KBD_PORT)
	or	a		; cp 0
	ret	z
	; scan code not zero, maybe we have something.
	; Do we need to skip it?
	push	af		;  <|
	ld	a, (KBD_SKIP_NEXT) ;|
	or	a		;   |
	jr	nz, .skip	;   |
	pop	af		;  <|
	cp	0x80
	jr	nc, .outOfBounds
	; No need to skip, code within bounds, we have something! Let's see if
	; there's a ASCII code associated to it.
	push	hl		; <|
	ld	hl, kbdScanCodes ; |
	call	addHL		;  |
	ld	a, (hl)		;  |
	pop	hl		; <|
	or	a		; cp 0
	jp	z, unsetZ	; no code. Keep A at 0, but unset Z
	; We have something!
	cp	a		; ensure Z
	ret
.outOfBounds:
	; A scan code over 0x80 is out of bounds. Ignore.
	; If F0 (break code) or E0 (extended code), we also skip the next code
	cp	0xf0
	jr	z, .skipNext
	cp	0xe0
	jr	z, .skipNext
	xor	a
	jp	unsetZ
.skipNext:
	ld	(KBD_SKIP_NEXT), a
	xor	a
	jp	unsetZ
.skip:
	pop	af		; equilibrate stack
	xor	a
	ld	(KBD_SKIP_NEXT), a
	jp	unsetZ

; A list of the value associated with the 0x80 possible scan codes of the set
; 2 of the PS/2 keyboard specs. 0 means no value. That value is a character than
; can be read in a GetC routine. No make code in the PS/2 set 2 reaches 0x80.
kbdScanCodes:
; 0x00    1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
.db   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  9,'`',  0
; 0x10 9 = TAB
.db   0,  0,  0,  0,  0,'Q','1',  0,  0,  0,'Z','S','A','W','2',  0
; 0x20 32 = SPACE
.db   0,'C','X','D','E','4','3',  0,  0, 32,'V','F','T','R','5',  0
; 0x30
.db   0,'N','B','H','G','Y','6',  0,  0,  0,'M','J','U','7','8',  0
; 0x40 59 = ;
.db   0,',','K','I','O','0','9',  0,  0,'.','/','L', 59,'P','-',  0
; 0x50 13 = RETURN 39 = '
.db   0,  0, 39,  0,'[','=',  0,  0,  0,  0,  13,']',  0,'\',  0,  0
; 0x60 8 = BKSP
.db   0,  0,  0,  0,  0,  0,  8,  0,  0,  0,  0,  0,  0,  0,  0,  0
; 0x70 27 = ESC
.db   0,  0,  0,  0,  0,  0, 27,  0,  0,  0,  0,  0,  0,  0,  0,  0
