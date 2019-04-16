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
; pointing to GetC and PutC routines.
BLOCKDEV_TBL		.equ	BLOCKDEV_RAMSTART
; Index of the current blockdev selection
BLOCKDEV_SELIDX		.equ	BLOCKDEV_TBL+(BLOCKDEV_COUNT*4)
; Address of the current GetC routine
BLOCKDEV_GETC		.equ	BLOCKDEV_SELIDX+1
; Address of the current PutC routine
BLOCKDEV_PUTC		.equ	BLOCKDEV_GETC+2
BLOCKDEV_RAMEND		.equ	BLOCKDEV_PUTC+2

; *** CODE ***
; set DE to point to the table entry at index A.
blkFind:
	ld	de, BLOCKDEV_TBL
	cp	0
	ret	z	; index is zero? don't loop
	push	bc
	ld	b, a
	push	af
	ld	a, 4
.loop:
	call	addDE
	djnz	.loop
	pop	af
	pop	bc
	ret

; Set the GetC pointer of device id A to the value in HL
blkSetGetC:
	call	blkFind
	call	writeHLinDE
	ret

; Set the GetC pointer of device id A to the value in HL
blkSetPutC:
	call	blkFind
	inc	de
	inc	de
	call	writeHLinDE
	ret

; Select block index specified in A
blkSel:
	call	blkFind
	ld	(BLOCKDEV_SELIDX), a
	ex	hl, de
	; now, HL points to the table entry
	ld	de, BLOCKDEV_GETC
	ldi	; copy (HL) into (BLOCKDEV_GETC)
	ldi	; .. and into +1
	ld	de, BLOCKDEV_PUTC
	ldi	; same thing for (BLOCKDEV_PUTC)
	ldi
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

; Reads one character from blockdev ID specified at A and returns its value
; in A. Always returns a character and waits until read if it has to.
blkGetC:
	push	ix
	push	de
	ld	de, (BLOCKDEV_GETC)
	ld	ixh, d
	ld	ixl, e
	pop	de
	call	callIX
	pop	ix
	ret

blkPutC:
	push	ix
	push	de
	ld	de, (BLOCKDEV_PUTC)
	ld	ixh, d
	ld	ixl, e
	pop	de
	call	callIX
	pop	ix
	ret
