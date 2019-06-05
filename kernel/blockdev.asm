; blockdev
;
; A block device is an abstraction over something we can read from, write to.
;
; A device that fits this abstraction puts the properly hook into itself, and
; then the glue code assigns a blockdev ID to that device. It then becomes easy
; to access arbitrary devices in a convenient manner.
;
; This module exposes a seek/tell/getc/putc API that is then re-routed to
; underlying drivers. There will eventually be more than one driver type, but
; for now we sit on only one type of driver: random access driver.
;
; *** Random access drivers ***
;
; Random access drivers are expected to supply two routines: GetC and PutC.
;
; GetC:
; Reads one character at address specified in DE/HL and returns its value in A.
; Sets Z according to whether read was successful: Set if successful, unset
; if not.
;
; Unsuccessful reads generally mean that requested addr is out of bounds (we
; reached EOF).
;
; PutC:
; Writes character in A at address specified in DE/HL. Sets Z according to
; whether the operation was successful.
;
; Unsuccessful writes generally mean that we're out of bounds for writing.
;
; All routines are expected to preserve unused registers.


; *** DEFINES ***
; BLOCKDEV_COUNT: The number of devices we manage.

; *** CONSTS ***
.equ	BLOCKDEV_SEEK_ABSOLUTE		0
.equ	BLOCKDEV_SEEK_FORWARD		1
.equ	BLOCKDEV_SEEK_BACKWARD		2
.equ	BLOCKDEV_SEEK_BEGINNING		3
.equ	BLOCKDEV_SEEK_END		4

.equ	BLOCKDEV_SIZE			8
; *** VARIABLES ***
; Pointer to the selected block device. A block device is a 8 bytes block of
; memory with pointers to GetC, PutC, and a 32-bit counter, in that order.
.equ	BLOCKDEV_SEL		BLOCKDEV_RAMSTART
.equ	BLOCKDEV_RAMEND		BLOCKDEV_SEL+BLOCKDEV_SIZE

; *** CODE ***
; Select block index specified in A and place them in routine pointers at (DE).
; For example, for a "regular" blkSel, you will want to set DE to BLOCKDEV_SEL.
blkSel:
	push	af
	push	de
	push	hl

	ld	hl, blkDevTbl
	or	a		; cp 0
	jr	z, .end		; index is zero? don't loop
	push	bc		; <|
	ld	b, a		;  |
.loop:				;  |
	ld	a, 4		;  |
	call	addHL		;  |
	djnz	.loop		;  |
	pop	bc		; <|
.end:
	call	blkSet
	pop	hl
	pop	de
	pop	af
	ret

; Setup blkdev handle in (DE) using routines at (HL).
blkSet:
	push	af
	push	de
	push	hl

	; Write GETC
	push	hl		; <|
	call	intoHL		;  |
	call	writeHLinDE	;  |
	inc	de		;  |
	inc	de		;  |
	pop	hl		; <|
	inc	hl
	inc	hl
	; Write PUTC
	call	intoHL
	call	writeHLinDE
	inc	de
	inc	de
	; Initialize pos
	xor	a
	ld	(de), a
	inc	de
	ld	(de), a
	inc	de
	ld	(de), a
	inc	de
	ld	(de), a

	pop	hl
	pop	de
	pop	af
	ret

_blkInc:
	ret	nz		; don't advance when in error condition
	push	af
	push	hl
	ld	a, BLOCKDEV_SEEK_FORWARD
	ld	hl, 1
	call	_blkSeek
	pop	hl
	pop	af
	ret

; Reads one character from selected device and returns its value in A.
; Sets Z according to whether read was successful: Set if successful, unset
; if not.
blkGetC:
	ld	ix, BLOCKDEV_SEL
_blkGetC:
	push	hl
	push	de
	call	_blkTell
	call	callIXI
	pop	de
	pop	hl
	jr	_blkInc		; advance and return

; Writes character in A in current position in the selected device. Sets Z
; according to whether the operation was successful.
blkPutC:
	ld	ix, BLOCKDEV_SEL
_blkPutC:
	push	ix
	push	hl
	push	de
	call	_blkTell
	inc	ix	; make IX point to PutC
	inc	ix
	call	callIXI
	pop	de
	pop	hl
	pop	ix
	jr	_blkInc		; advance and return

; Reads B chars from blkGetC and copy them in (HL).
; Sets Z if successful, unset Z if there was an error.
blkRead:
	ld	ix, BLOCKDEV_SEL
_blkRead:
	push	hl
	push	bc
.loop:
	call	_blkGetC
	jr	nz, .end	; Z already unset
	ld	(hl), a
	inc	hl
	djnz	.loop
	cp	a	; ensure Z
.end:
	pop	bc
	pop	hl
	ret

; Writes B chars to blkPutC from (HL).
; Sets Z if successful, unset Z if there was an error.
blkWrite:
	ld	ix, BLOCKDEV_SEL
_blkWrite:
	push	hl
	push	bc
.loop:
	ld	a, (hl)
	call	_blkPutC
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
	ld	ix, BLOCKDEV_SEL
_blkSeek:
	cp	BLOCKDEV_SEEK_FORWARD
	jr	z, .forward
	cp	BLOCKDEV_SEEK_BACKWARD
	jr	z, .backward
	cp	BLOCKDEV_SEEK_BEGINNING
	jr	z, .beginning
	cp	BLOCKDEV_SEEK_END
	jr	z, .end
	; all other modes are considered absolute
	ld	(ix+4), e
	ld	(ix+5), d
	ld	(ix+6), l
	ld	(ix+7), h
	ret
.forward:
	push	bc		; <-|
	push	hl		; <||
	ld	l, (ix+6)	;  || low byte
	ld	h, (ix+7)	;  ||
	pop	bc		; <||
	add	hl, bc		;   |
	pop	bc		; <-|
	ld	(ix+6), l
	ld	(ix+7), h
	ret	nc		; no carry? no need to adjust high byte
	; carry, adjust high byte
	inc	(ix+4)
	ret	nz
	inc	(ix+5)
	ret
.backward:
	and	a		; clear carry
	push	bc		; <-|
	push	hl		; <||
	ld	l, (ix+6)	;  || low byte
	ld	h, (ix+7)	;  ||
	pop	bc		; <||
	sbc	hl, bc		;   |
	pop	bc		; <-|
	ld	(ix+6), l
	ld	(ix+7), h
	ret	nc		; no carry? no need to adjust high byte
	ld	a, 0xff
	dec	(ix+4)
	cp	(ix+4)
	ret	nz
	; we decremented from 0
	dec	(ix+5)
	ret
.beginning:
	xor	a
	ld	(ix+4), a
	ld	(ix+5), a
	ld	(ix+6), a
	ld	(ix+7), a
	ret
.end:
	ld	a, 0xff
	ld	(ix+4), a
	ld	(ix+5), a
	ld	(ix+6), a
	ld	(ix+7), a
	ret

; Returns the current position of the selected device in HL (low) and DE (high).
blkTell:
	ld	ix, BLOCKDEV_SEL
_blkTell:
	ld	e, (ix+4)
	ld	d, (ix+5)
	ld	l, (ix+6)
	ld	h, (ix+7)
	ret

; This label is at the end of the file on purpose: the glue file should include
; a list of device routine table entries just after the include. Each line
; has 4 word addresses: GetC, PutC and Seek, Tell. An entry could look like:
; .dw     mmapGetC, mmapPutC, mmapSeek, mmapTell
blkDevTbl:
