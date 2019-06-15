sdctMain:
	ld	hl, .sWriting
	call	printstr
	ld	hl, 0
	ld	de, SDCT_RAMSTART
.wLoop:
	ld	a, (de)
	; To avoid overwriting important data and to test the 24-bit addressing,
	; we set DE to 12 instead of zero
	push	de		; <|
	ld	de, 12		;  |
	call	sdcPutC		;  |
	pop	de		; <|
	jr	nz, .error
	inc	hl
	inc	de
	; Stop looping if DE == 0
	xor	a
	cp	e
	jr	nz, .wLoop
	; print some kind of progress
	call	printHexPair
	cp	d
	jr	nz, .wLoop
	; Finished writing
	ld	hl, .sReading
	call	printstr
	ld	hl, 0
	ld	de, SDCT_RAMSTART
.rLoop:
	push	de		; <|
	ld	de, 12		;  |
	call	sdcGetC		;  |
	pop	de		; <|
	jr	nz, .error
	ex	de, hl
	cp	(hl)
	ex	de, hl
	jr	nz, .notMatching
	inc	hl
	inc	de
	; Stop looping if DE == 0
	xor	a
	cp	d
	jr	nz, .rLoop
	cp	e
	jr	nz, .rLoop
	; Finished checking
	xor	a
	ld	hl, .sOk
	jp	printstr	; returns
.notMatching:
	; error position is in HL, let's preserve it
	ex	de, hl
	ld	hl, .sNotMatching
	call	printstr
	ex	de, hl
	jp	printHexPair	; returns
.error:
	ld	hl, .sErr
	jp	printstr	; returns

.sWriting:
	.db	"Writing", 0xd, 0xa, 0
.sReading:
	.db	"Reading", 0xd, 0xa, 0
.sNotMatching:
	.db	"Not matching at pos ", 0xd, 0xa, 0
.sErr:
	.db	"Error", 0xd, 0xa, 0
.sOk:
	.db	"OK", 0xd, 0xa, 0
