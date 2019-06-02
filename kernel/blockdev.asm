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
;
; *** Blockdev routines ***
;
; There are 4 blockdev routines that can be defined by would-be block devices
; and they follow these specifications:
;
; GetC:
; Reads one character from selected device and returns its value in A.
; Sets Z according to whether read was successful: Set if successful, unset
; if not.
;
; A successful GetC should advance the "pointer" of the device (if there is one)
; by one byte so that a subsequent GetC will read the next char. Unsuccessful
; reads generally mean that we reached EOF.
;
;
; PutC:
; Writes character in A in current position in the selected device. Sets Z
; according to whether the operation was successful.
;
; A successful PutC should advance the "pointer" of the device (if there is one)
; by one byte so that the next PutC places the next char next to this one.
; Unsuccessful writes generally mean that we reached EOF.
;
; Seek:
; Place device "pointer" at position dictated by HL (low 16 bits) and DE (high
; 16 bits).
;
; Tell:
; Return the position of the "pointer" in HL (low 16 bits) and DE (high 16
; bits).
;
; All routines are expected to preserve unused registers.


; *** DEFINES ***
; BLOCKDEV_COUNT: The number of devices we manage.

; *** CONSTS ***
.equ	BLOCKDEV_ERR_OUT_OF_BOUNDS	0x03
.equ	BLOCKDEV_ERR_UNSUPPORTED	0x04

.equ	BLOCKDEV_SEEK_ABSOLUTE		0
.equ	BLOCKDEV_SEEK_FORWARD		1
.equ	BLOCKDEV_SEEK_BACKWARD		2
.equ	BLOCKDEV_SEEK_BEGINNING		3
.equ	BLOCKDEV_SEEK_END		4

; *** VARIABLES ***
; Pointer to the selected block device. A block device is a 8 bytes block of
; memory with pointers to GetC, PutC, Seek and Tell routines, in that order.
; 0 means unsupported.
.equ	BLOCKDEV_GETC		BLOCKDEV_RAMSTART
.equ	BLOCKDEV_PUTC		BLOCKDEV_GETC+2
.equ	BLOCKDEV_SEEK		BLOCKDEV_PUTC+2
.equ	BLOCKDEV_TELL		BLOCKDEV_SEEK+2
.equ	BLOCKDEV_RAMEND		BLOCKDEV_TELL+2

; *** CODE ***
; Select block index specified in A and place them in routine pointers at (DE).
; For example, for a "regular" blkSel, you will want to set DE to BLOCKDEV_GETC.
blkSel:
	push	af
	push	de
	push	hl

	ld	hl, blkDevTbl
	or	a		; cp 0
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
		call	writeHLinDE
		inc	de
		inc	de
	pop	hl
	inc	hl
	inc	hl
	push	hl
		call	intoHL
		call	writeHLinDE
		inc	de
		inc	de
	pop	hl
	inc	hl
	inc	hl
	push	hl
		call	intoHL
		call	writeHLinDE
		inc	de
		inc	de
	pop	hl
	inc	hl
	inc	hl
	call	intoHL
	call	writeHLinDE

	pop	hl
	pop	de
	pop	af
	ret

; call IX unless it's zero
_blkCall:
	; Before we call... is IX zero? We don't want to call a zero.
	push	af
	xor	a
	push	hl
	push	ix \ pop hl
	cp	h
	jr	nz, .ok		; not zero, ok
	cp	l
	jr	z, .error	; zero, error
.ok:
	pop	hl
	pop	af
	call	callIX
	ret
.error:
	pop	hl
	pop	af
	ld	a, BLOCKDEV_ERR_UNSUPPORTED
	ret

; Reads one character from selected device and returns its value in A.
; Sets Z according to whether read was successful: Set if successful, unset
; if not.
blkGetC:
	ld	ix, (BLOCKDEV_GETC)
	jr	_blkCall

; Reads B chars from blkGetC and copy them in (HL).
; Sets Z if successful, unset Z if there was an error.
blkRead:
	ld	ix, (BLOCKDEV_GETC)
_blkRead:
	push	hl
	push	bc
.loop:
	call	_blkCall
	jr	nz, .end	; Z already unset
	ld	(hl), a
	inc	hl
	djnz	.loop
	cp	a	; ensure Z
.end:
	pop	bc
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
	push	bc
.loop:
	ld	a, (hl)
	call	_blkCall
	jr	nz, .end	; Z already unset
	inc	hl
	djnz	.loop
	cp	a	; ensure Z
.end:
	pop	bc
	pop	hl
	ret

; Seeks the block device in one of 5 modes, which is the A argument:
; 0 : Move exactly to X, X being the HL/DE argument.
; 1 : Move forward by X bytes, X being the HL argument (no DE)
; 2 : Move backwards by X bytes, X being the HL argument (no DE)
; 3 : Move to the end
; 4 : Move to the beginning

; Set position of selected device to the value specified in HL (low) and DE
; (high). DE is only used for mode 0.
;
; When seeking to an out-of-bounds position, the resulting position will be
; one position ahead of the last valid position. Therefore, GetC after a seek
; to end would always fail.
;
; If the device is "growable", it's possible that seeking to end when calling
; PutC doesn't necessarily result in a failure.
blkSeek:
	ld	ix, (BLOCKDEV_SEEK)
	ld	iy, (BLOCKDEV_TELL)
_blkSeek:
	; we preserve DE so that it's possible to call blkSeek in mode != 0
	; while not discarding our current DE value.
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
	jr	.seek		; for absolute mode, HL and DE are already
				; correct
.forward:
	push	bc
	push	hl
	; We want to be able to plug our own TELL function, which is why we
	; don't call blkTell directly here.
	; Calling TELL
	ld	de, 0	; in case out Tell routine doesn't return DE
	call	callIY	; HL/DE now have our curpos
	pop	bc	; pop HL into BC
	add	hl, bc
	pop	bc	; pop orig BC back
	jr	nc, .seek	; no carry? let's seek.
	; carry, adjust DE
	inc	de
	jr	.seek
.backward:
	; TODO - subtraction are more complicated...
	jr	.seek
.beginning:
	ld	hl, 0
	ld	de, 0
	jr	.seek
.end:
	ld	hl, 0xffff
	ld	de, 0xffff
.seek:
	call	_blkCall
	pop	de
	ret

; Returns the current position of the selected device in HL (low) and DE (high).
blkTell:
	ld	de, 0			; in case device ignores DE.
	ld	ix, (BLOCKDEV_TELL)
	jp	_blkCall

; This label is at the end of the file on purpose: the glue file should include
; a list of device routine table entries just after the include. Each line
; has 4 word addresses: GetC, PutC and Seek, Tell. An entry could look like:
; .dw     mmapGetC, mmapPutC, mmapSeek, mmapTell
blkDevTbl:
