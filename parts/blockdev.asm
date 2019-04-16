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
; Pointer to the selected block device. A block device is a 6 bytes block of
; memory with pointers to GetC, PutC and Seek routines, in that order. 0 means
; unsupported.
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
	ld	a, 6
	call	addHL
	djnz	.loop
	pop	bc
.afterloop:
	ld	(BLOCKDEV_SEL), hl
	pop	Hl
	pop	af
	ret

blkBselCmd:
	.db	"bsel", 0b001, 0, 0
	ld	a, (hl)	; argument supplied
	cp	BLOCKDEV_COUNT
	jr	nc, .error	; if selection >= device count, error
	call	blkSel
	xor	a
	ret
.error:
	ld	a, BLOCKDEV_ERR_OUT_OF_BOUNDS
	ret


; In those routines below, IY is destroyed (we don't push it to the stack). We
; seldom use it anyways...

; call routine in BLOCKDEV_SEL with offset IYL.
_blkCall:
	push	ix
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
	; Before we call... is it zero? We don't want to call a zero.
	push	af
	ld	a, ixh
	add	a, ixl
	jr	c, .ok		; if there's a carry, it isn't zero
	cp	0
	jr	z, .error	; if no carry and zero, then both numbers are
				; zero
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

; Reads one character from selected device and returns its value in A. Always
; returns a character and waits until read if it has to.
blkGetC:
	ld	iyl, 0
	jr	_blkCall

; Writes character in A in current position in the selected device
blkPutC:
	ld	iyl, 2
	jr	_blkCall

blkSeekCmd:
	.db	"seek", 0b011, 0b001, 0
	; HL points to two bytes that contain out address. Seek expects HL
	; to directly contain that address.
	ld	a, (hl)
	ex	af, af'
	inc	hl
	ld	a, (hl)
	ld	l, a
	ex	af, af'
	ld	h, a
	xor	a
; Set position of selected device to the value specified in HL
blkSeek:
	ld	iyl, 4
	jr	_blkCall

; This label is at the end of the file on purpose: the glue file should include
; a list of device routine table entries just after the include. Each line
; has 3 word addresses: GetC, PutC and Seek. An entry could look like:
; .dw     mmapGetC, mmapPutC, mmapSeek
blkDevTbl:
