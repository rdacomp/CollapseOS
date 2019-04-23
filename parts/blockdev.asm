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

; *** VARIABLES ***
; Pointer to the selected block device. A block device is a 8 bytes block of
; memory with pointers to GetC, PutC, Seek and Tell routines, in that order.
; 0 means unsupported.
BLOCKDEV_SEL		.equ	BLOCKDEV_RAMSTART
BLOCKDEV_RAMEND		.equ	BLOCKDEV_SEL+2

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
	ld	(BLOCKDEV_SEL), hl
	pop	hl
	pop	af
	ret

; In those routines below, IY is destroyed (we don't push it to the stack). We
; seldom use it anyways...

; set IX to the address of the routine in BLOCKDEV_SEL with offset IYL.
_blkCallAddr:
	push	de
	ld	de, (BLOCKDEV_SEL)
	; DE now points to the *address table*, not the routine addresses
	; themselves. One layer of indirection left.
	; slide by offset
	push	af
	ld	a, iyl
	call	addDE	; slide by offset
	pop	af
	call	intoDE
	; Alright, now de points to what we want to call
	ld	ixh, d
	ld	ixl, e
	pop	de
	ret

; call routine in BLOCKDEV_SEL with offset IYL.
_blkCall:
	push	ix
	call	_blkCallAddr
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
	jr	.end
.error:
	pop	af
	ld	a, BLOCKDEV_ERR_UNSUPPORTED
.end:
	pop	ix
	ret

; Reads one character from selected device and returns its value in A.
; Sets Z according to whether read was successful: Set if successful, unset
; if not.
blkGetC:
	ld	iyl, 0
	jr	_blkCall

; Repeatedly call blkGetC until the call is a success.
blkGetCW:
	ld	iyl, 0
	call	_blkCallAddr
.loop:
	call	callIX
	jr	nz, .loop
	ret

; Reads B chars from blkGetC and copy them in (HL).
; Sets Z if successful, unset Z if there was an error.
blkRead:
	push	hl
.loop:
	call	blkGetC
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
	ld	iyl, 2
	jr	_blkCall

; Seeks the block device in one of 5 modes, which is the A argument:
; 0 : Move exactly to X, X being the HL argument.
; 1 : Move forward by X bytes, X being the HL argument
; 2 : Move backwards by X bytes, X being the HL argument
; 3 : Move to the end
; 4 : Move to the beginning
; Set position of selected device to the value specified in HL
blkSeek:
	push	de
	cp	1
	jr	z, .forward
	cp	2
	jr	z, .backward
	cp	3
	jr	z, .beginning
	cp	4
	jr	z, .end
	; all other modes are considered absolute
	jr	.seek		; for absolute mode, HL is already correct
.forward:
	ex	hl, de		; DE has our offset
	call	blkTell		; HL has our curpos
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
	ld	iyl, 4
	jr	_blkCall

; Returns the current position of the selected device in HL.
blkTell:
	ld	iyl, 6
	jr	_blkCall

; This label is at the end of the file on purpose: the glue file should include
; a list of device routine table entries just after the include. Each line
; has 4 word addresses: GetC, PutC and Seek, Tell. An entry could look like:
; .dw     mmapGetC, mmapPutC, mmapSeek, mmapTell
blkDevTbl:
