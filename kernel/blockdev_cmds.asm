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
	ld	de, 0	; DE is used for seek > 64K which we don't support
	call	blkSeek
	call	blkTell
	ld	a, h
	call	printHex
	ld	a, l
	call	printHex
	call	printcrlf
	xor	a
	ret

; Load the specified number of bytes (max 0xff) from IO and write them in the
; current memory pointer (which doesn't change). This gets chars from
; blkGetCW.
; Control is returned to the shell only after all bytes are read.
;
; Example: load 42
blkLoadCmd:
	.db	"load", 0b001, 0, 0
blkLoad:
	push	bc
	push	hl

	ld	a, (hl)
	ld	b, a
	ld	hl, (SHELL_MEM_PTR)
.loop:  call	blkGetCW
	jr	nz, .ioError
	ld	(hl), a
	inc	hl
	djnz	.loop
	; success
	xor	a
	jr	.end
.ioError:
	ld	a, SHELL_ERR_IO_ERROR
.end:
	pop	hl
	pop	bc
	ret

; Load the specified number of bytes (max 0xff) from the current memory pointer
; and write them to I/O. Memory pointer doesn't move. This puts chars to
; blkPutC.
; Control is returned to the shell only after all bytes are written.
;
; Example: save 42
blkSaveCmd:
	.db	"save", 0b001, 0, 0
blkSave:
	push	bc
	push	hl

	ld	a, (hl)
	ld	b, a
	ld	hl, (SHELL_MEM_PTR)
.loop:
	ld	a, (hl)
	inc	hl
	call	blkPutC
	djnz	.loop

.end:
	pop	hl
	pop	bc
	xor	a
	ret

