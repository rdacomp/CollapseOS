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

; *** VARIABLES ***
; A memory pointer to a device table. A device table is a list of addresses
; pointing to GetC, PutC and Seek routines.
BLOCKDEV_TBL		.equ	BLOCKDEV_RAMSTART
; Pointer to the selected block device. A block device is a 6 bytes block of
; memory with pointers to GetC, PutC and Seek routines, in that order. 0 means
; unsupported.
BLOCKDEV_SEL		.equ	BLOCKDEV_TBL+(BLOCKDEV_COUNT*2)
BLOCKDEV_RAMEND		.equ	BLOCKDEV_SEL+2

; *** CODE ***
; set DE to point to the table entry at index A.
blkFind:
	ld	de, BLOCKDEV_TBL
	cp	0
	ret	z	; index is zero? don't loop
	push	bc
	ld	b, a
.loop:
	inc	de
	inc	de
	djnz	.loop
	pop	bc
	ret

; Set the pointer of device id A to the value in HL
blkSet:
	call	blkFind
	call	writeHLinDE
	ret

; Select block index specified in A
blkSel:
	push	de
	push	hl
	call	blkFind
	ld	hl, BLOCKDEV_SEL
	ex	hl, de
	ldi
	pop	hl
	pop	de
	ret

blkBselCmd:
	.db	"bsel", 0b001, 0, 0
blkBsel:
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
	call	callIX
	pop	ix
	ret

; Reads one character from blockdev ID specified at A and returns its value
; in A. Always returns a character and waits until read if it has to.
blkGetC:
	ld	iyl, 0
	jr	_blkCall

blkPutC:
	ld	iyl, 2
	jr	_blkCall

blkSeek:
	ld	iyl, 4
	jr	_blkCall

