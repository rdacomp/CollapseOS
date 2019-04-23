; blockdev
;
; A block device is an abstraction over something we can read from, write to.
;
; A device that fits this abstraction puts the properly hook into itself, and
; then the glue code assigns a blockdev ID to that device. It then becomes easy
; to access arbitrary devices in a convenient manner.
;
; This part exposes a new "bsel" command to select the currently active block
; device.

; *** DEFINES ***
; BLOCKDEV_COUNT: The number of devices we manage.

; *** CONSTS ***
BLOCKDEV_ERR_OUT_OF_BOUNDS	.equ	0x03
BLOCKDEV_ERR_UNSUPPORTED	.equ	0x04

BLOCKDEV_SEEK_ABSOLUTE		.equ	0
BLOCKDEV_SEEK_FORWARD		.equ	1
BLOCKDEV_SEEK_BACKWARD		.equ	2
BLOCKDEV_SEEK_BEGINNING		.equ	3
BLOCKDEV_SEEK_END		.equ	4

; *** VARIABLES ***
; Pointer to the selected block device. A block device is a 8 bytes block of
; memory with pointers to GetC, PutC, Seek and Tell routines, in that order.
; 0 means unsupported.
BLOCKDEV_GETC		.equ	BLOCKDEV_RAMSTART
BLOCKDEV_PUTC		.equ	BLOCKDEV_GETC+2
BLOCKDEV_SEEK		.equ	BLOCKDEV_PUTC+2
BLOCKDEV_TELL		.equ	BLOCKDEV_SEEK+2
BLOCKDEV_RAMEND		.equ	BLOCKDEV_TELL+2

; *** CODE ***
; Select block index specified in A
blkSel:
	push	af
	push	hl
	ld	hl, blkDevTbl
	cp	0
	jr	z, .afterloop	; index is zero? don't loop
	push	bc
	ld	b, a
.loop:
	ld	a, 8
	call	addHL
	djnz	.loop
	pop	bc
.afterloop:
	push	hl
	call	intoHL
	ld	(BLOCKDEV_GETC), hl
	pop	hl
	inc	hl
	inc	hl
	push	hl
	call	intoHL
	ld	(BLOCKDEV_PUTC), hl
	pop	hl
	inc	hl
	inc	hl
	push	hl
	call	intoHL
	ld	(BLOCKDEV_SEEK), hl
	pop	hl
	inc	hl
	inc	hl
	call	intoHL
	ld	(BLOCKDEV_TELL), hl
	pop	hl
	pop	af
	ret

; call IX unless it's zero
_blkCall:
	; Before we call... is IX zero? We don't want to call a zero.
	push	af
	xor	a
	cp	ixh
	jr	nz, .ok		; not zero, ok
	cp	ixl
	jr	z, .error	; zero, error
.ok:
	pop	af
	call	callIX
	ret
.error:
	pop	af
	ld	a, BLOCKDEV_ERR_UNSUPPORTED
	ret

; Reads one character from selected device and returns its value in A.
; Sets Z according to whether read was successful: Set if successful, unset
; if not.
blkGetC:
	ld	ix, (BLOCKDEV_GETC)
	jr	_blkCall

; Repeatedly call blkGetC until the call is a success.
blkGetCW:
	ld	ix, (BLOCKDEV_GETC)
.loop:
	call	callIX
	jr	nz, .loop
	ret

; Reads B chars from blkGetC and copy them in (HL).
; Sets Z if successful, unset Z if there was an error.
blkRead:
	ld	ix, (BLOCKDEV_GETC)
_blkRead:
	push	hl
.loop:
	call	_blkCall
	jr	nz, .end	; Z already unset
	ld	(hl), a
	inc	hl
	djnz	.loop
	cp	a	; ensure Z
.end:
	pop	hl
	ret

; Writes character in A in current position in the selected device. Sets Z
; according to whether the operation was successful.
blkPutC:
	ld	ix, (BLOCKDEV_PUTC)
	jr	_blkCall

; Writes B chars to blkPutC from (HL).
; Sets Z if successful, unset Z if there was an error.
blkWrite:
	ld	ix, (BLOCKDEV_PUTC)
_blkWrite:
	push	hl
.loop:
	ld	a, (hl)
	call	_blkCall
	jr	nz, .end	; Z already unset
	inc	hl
	djnz	.loop
	cp	a	; ensure Z
.end:
	pop	hl
	ret

; Seeks the block device in one of 5 modes, which is the A argument:
; 0 : Move exactly to X, X being the HL argument.
; 1 : Move forward by X bytes, X being the HL argument
; 2 : Move backwards by X bytes, X being the HL argument
; 3 : Move to the end
; 4 : Move to the beginning
; Set position of selected device to the value specified in HL
blkSeek:
	ld	ix, (BLOCKDEV_SEEK)
	ld	iy, (BLOCKDEV_TELL)
_blkSeek:
	push	de
	cp	BLOCKDEV_SEEK_FORWARD
	jr	z, .forward
	cp	BLOCKDEV_SEEK_BACKWARD
	jr	z, .backward
	cp	BLOCKDEV_SEEK_BEGINNING
	jr	z, .beginning
	cp	BLOCKDEV_SEEK_END
	jr	z, .end
	; all other modes are considered absolute
	jr	.seek		; for absolute mode, HL is already correct
.forward:
	ex	hl, de		; DE has our offset
	; We want to be able to plug our own TELL function, which is why we
	; don't call blkTell directly here.
	; Calling TELL
	call	callIY	; HL has our curpos
	add	hl, de
	jr	nc, .seek	; no carry? alright!
	; we have carry? out of bounds, set to maximum
.backward:
	; TODO - subtraction are more complicated...
	jr	.seek
.beginning:
	ld	hl, 0
	jr	.seek
.end:
	ld	hl, 0xffff
.seek:
	pop	de
	jr	_blkCall

; Returns the current position of the selected device in HL.
blkTell:
	ld	ix, (BLOCKDEV_TELL)
	jr	_blkCall

; This label is at the end of the file on purpose: the glue file should include
; a list of device routine table entries just after the include. Each line
; has 4 word addresses: GetC, PutC and Seek, Tell. An entry could look like:
; .dw     mmapGetC, mmapPutC, mmapSeek, mmapTell
blkDevTbl:
