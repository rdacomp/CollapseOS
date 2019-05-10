; *** REQUIREMENTS ***
; blockdev
; stdio

blkBselCmd:
	.db	"bsel", 0b001, 0, 0
	ld	a, (hl)	; argument supplied
	cp	BLOCKDEV_COUNT
	jr	nc, .error	; if selection >= device count, error
	push	de
	ld	de, BLOCKDEV_GETC
	call	blkSel
	pop	de
	xor	a
	ret
.error:
	ld	a, BLOCKDEV_ERR_OUT_OF_BOUNDS
	ret

blkSeekCmd:
	.db	"seek", 0b001, 0b011, 0b001
	; First, the mode
	ld	a, (hl)
	inc	hl
	push	af	; save mode for later
	; HL points to two bytes that contain out address. Seek expects HL
	; to directly contain that address.
	ld	a, (hl)
	ex	af, af'
	inc	hl
	ld	a, (hl)
	ld	l, a
	ex	af, af'
	ld	h, a
	pop	af	; bring mode back
	call	blkSeek
	call	blkTell
	ld	a, h
	call	printHex
	ld	a, l
	call	printHex
	call	printcrlf
	xor	a
	ret

