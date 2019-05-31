; fs
;
; Collapse OS filesystem (CFS) is not made to be convenient, but to be simple.
; This is little more than "named storage blocks". Characteristics:
;
; * a filesystem sits upon a blockdev. It needs GetC, PutC, Seek.
; * No directory. Use filename prefix to group.
; * First block of each file has metadata. Others are raw data.
; * No FAT. Files are a chain of blocks of a predefined size. To enumerate
;   files, you go through metadata blocks.
; * Fixed allocation. File size is determined at allocation time and cannot be
;   grown, only shrunk.
; * New allocations try to find spots to fit in, but go at the end if no spot is
;   large enough.
; * Block size is 0x100, max block count per file is 8bit, that means that max
;   file size: 64k - metadata overhead.
;
; *** Selecting a "source" blockdev
;
; This unit exposes "fson" shell command to "mount" CFS upon the currently
; selected device, at the point where its seekptr currently sits. This checks
; if we have a valid first block and spits an error otherwise.
;
; "fson" takes an optional argument which is a number. If non-zero, we don't
; error out if there's no metadata: we create a new CFS fs with an empty block.
;
; The can only be one "mounted" fs at once. Selecting another blockdev through
; "bsel" doesn't affect the currently mounted fs, which can still be interacted
; with (which is important if we want to move data around).
;
; *** Block metadata
;
; At the beginning of the first block of each file, there is this data
; structure:
;
; 3b: Magic number "CFS"
; 1b: Allocated block count, including the first one. Except for the "ending"
;     block, this is never zero.
; 2b: Size of file in bytes (actually written). Little endian.
; 26b: file name, null terminated. last byte must be null.
;
; That gives us 32 bytes of metadata for first first block, leaving a maximum
; file size of 0xffe0.
;
; *** Last block of the chain
;
; The last block of the chain is either a block that has no valid block next to
; it or a block that reports a 0 allocated block count.
;
; However, to simplify processing, whenever fsNext encounter a chain end of the
; first type (a valid block with > 0 allocated blocks), it places an empty block
; at the end of the chain. This makes the whole "end of chain" processing much
; easier: we assume that we always have a 0 block at the end.
;
; *** Deleted files
;
; When a file is deleted, its name is set to null. This indicates that the
; allocated space is up for grabs.
;
; *** File "handles"
;
; Programs will not typically open files themselves. How it works with CFS is
; that it exposes an API to plug target files in a blockdev ID. This all
; depends on how you glue parts together, but ideally, you'll have two
; fs-related blockdev IDs: one for reading, one for writing.
;
; Being plugged into the blockdev system, programs will access the files as they
; would with any other block device.
;
; *** Creating a new FS
;
; A valid Collapse OS filesystem is nothing more than the 3 bytes 'C', 'F', 'S'
; next to each other. Placing them at the right place is all you have to do to
; create your FS.

; *** DEFINES ***
; Number of handles we want to support
; FS_HANDLE_COUNT
; *** CONSTS ***
.equ	FS_MAX_NAME_SIZE	0x1a
.equ	FS_BLOCKSIZE		0x100
.equ	FS_METASIZE		0x20

.equ	FS_META_ALLOC_OFFSET	3
.equ	FS_META_FSIZE_OFFSET	4
.equ	FS_META_FNAME_OFFSET	6
; Size in bytes of a FS handle:
; * 4 bytes for starting offset of the FS block
; * 2 bytes for current position relative to block's position
; * 2 bytes for file size
.equ	FS_HANDLE_SIZE		8
.equ	FS_ERR_NO_FS		0x5
.equ	FS_ERR_NOT_FOUND	0x6

; *** VARIABLES ***
; A copy of BLOCKDEV routines when the FS was mounted. 0 if no FS is mounted.
.equ	FS_GETC		FS_RAMSTART
.equ	FS_PUTC		FS_GETC+2
.equ	FS_SEEK		FS_PUTC+2
.equ	FS_TELL		FS_SEEK+2
; Offset at which our FS start on mounted device
; This pointer is 32 bits. 32 bits pointers are a bit awkward: first two bytes
; are high bytes *low byte first*, and then the low two bytes, same order.
; When loaded in HL/DE, the four bytes are loaded in this order: E, D, L, H
.equ	FS_START	FS_TELL+2
; Offset at which we are currently pointing to with regards to our routines
; below, which all assume this offset as a context. This offset is not relative
; to FS_START. It can be used directly with fsblkSeek. 32 bits.
.equ	FS_PTR		FS_START+4
; This variable below contain the metadata of the last block FS_PTR was moved
; to. We read this data in memory to avoid constant seek+read operations.
.equ	FS_META		FS_PTR+4
.equ	FS_HANDLES	FS_META+FS_METASIZE
.equ	FS_RAMEND	FS_HANDLES+FS_HANDLE_COUNT*FS_HANDLE_SIZE

; *** DATA ***
P_FS_MAGIC:
	.db	"CFS", 0

; *** CODE ***

fsInit:
	xor	a
	ld	hl, FS_GETC
	ld	b, FS_RAMEND-FS_GETC
	call	fill
	ret

; *** Navigation ***

; Resets FS_PTR to the beginning. Errors out if no FS is mounted.
; Sets Z if success, unset if error
fsBegin:
	push	hl
	ld	hl, (FS_START)
	ld	(FS_PTR), hl
	ld	hl, (FS_START+2)
	ld	(FS_PTR+2), hl
	pop	hl
	call	fsReadMeta
	jp	fsIsValid	; sets Z, returns

; Change current position to the next block with metadata. If it can't (if this
; is the last valid block), doesn't move.
; Sets Z according to whether we moved.
fsNext:
	push	bc
	push	hl
	ld	a, (FS_META+FS_META_ALLOC_OFFSET)
	cp	0
	jr	z, .error	; if our block allocates 0 blocks, this is the
				; end of the line.
	call	fsPlace
	ld	b, a		; we will seek A times
.loop:
	ld	a, BLOCKDEV_SEEK_FORWARD
	ld	hl, FS_BLOCKSIZE
	call	fsblkSeek
	djnz	.loop
	; Good, were here. We're going to read meta from our current position.
	call	fsblkTell	; --> HL, --> DE
	ld	(FS_PTR), de
	ld	(FS_PTR+2), hl
	call	fsReadMeta
	jr	nz, .createChainEnd
	call	fsIsValid
	jr	nz, .createChainEnd
	; We're good! We have a valid FS block and FS_PTR is already updated.
	; Meta is already read. Nothing to do!
	cp	a	; ensure Z
	jr	.end
.createChainEnd:
	; We are on an invalid block where a valid block should be. This is
	; the end of the line, but we should mark it a bit more explicitly.
	; Let's initialize an empty block
	call	fsInitMeta
	call	fsWriteMeta
	; continue out to error condition: we're still at the end of the line.
.error:
	call	unsetZ
.end:
	pop	hl
	pop	bc
	ret

; Reads metadata at current FS_PTR and place it in FS_META.
; Returns Z according to whether the fsblkRead operation succeeded.
fsReadMeta:
	call	fsPlace
	push	bc
	push	hl
	ld	b, FS_METASIZE
	ld	hl, FS_META
	call	fsblkRead	; Sets Z
	pop	hl
	pop	bc
	ret

; Writes metadata in FS_META at current FS_PTR.
; Returns Z according to whether the fsblkWrite operation succeeded.
fsWriteMeta:
	call	fsPlace
	push	bc
	push	hl
	ld	b, FS_METASIZE
	ld	hl, FS_META
	call	fsblkWrite	; Sets Z
	pop	hl
	pop	bc
	ret

; Initializes FS_META with "CFS" followed by zeroes
fsInitMeta:
	push	af
	push	bc
	push	de
	push	hl
	ld	hl, P_FS_MAGIC
	ld	de, FS_META
	ld	bc, 3
	ldir
	xor	a
	ld	hl, FS_META+3
	ld	b, FS_METASIZE-3
	call	fill
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

; Make sure that our underlying blockdev is correctly placed.
fsPlace:
	push	af
	push	hl
	push	de
	xor	a
	ld	de, (FS_PTR)
	ld	hl, (FS_PTR+2)
	call	fsblkSeek
	pop	de
	pop	hl
	pop	af
	ret

; Create a new file with A blocks allocated to it and with its new name at
; (HL).
; Before doing so, enumerate all blocks in search of a deleted file with
; allocated space big enough. If it does, it will either take the whole space
; if the allocated space asked is exactly the same, or of it isn't, split the
; free space in 2 and create a new deleted metadata block next to the newly
; created block.
; Places FS_PTR to the newly allocated block. You have to write the new
; filename yourself.
fsAlloc:
	push	bc
	push	de
	ld	c, a		; Let's store our A arg somewhere...
	call	fsBegin
	jr	nz, .end	; not a valid block? hum, something's wrong
	; First step: find last block
	push	hl		; keep HL for later
.loop1:
	call	fsNext
	jr	nz, .found	; end of the line
	call	fsIsDeleted
	jr	nz, .loop1	; not deleted? loop
	; This is a deleted block. Maybe it fits...
	ld	a, (FS_META+FS_META_ALLOC_OFFSET)
	cp	c		; Same as asked size?
	jr	z, .found	; yes? great!
	; TODO: handle case where C < A (block splitting)
	jr	.loop1
.found:
	call	fsPlace		; Make sure that our block device points to
				; the beginning of our FS block
	; We've reached last block. Two situations are possible at this point:
	; 1 - the block is the "end of line" block
	; 2 - the block is a deleted block that we we're re-using.
	; In both case, the processing is the same: write new metadata.
	; At this point, the blockdev is placed right where we want to allocate
	; But first, let's prepare the FS_META we're going to write
	call	fsInitMeta
	ld	a, c		; C == the number of blocks user asked for
	ld	(FS_META+FS_META_ALLOC_OFFSET), a
	pop	hl		; now we want our HL arg
	ld	de, FS_META+FS_META_FNAME_OFFSET
	ld	bc, FS_MAX_NAME_SIZE
	ldir
	; Good, FS_META ready. Now, let's update FS_PTR because it hasn't been
	; changed yet.
	call	fsblkTell
	ld	(FS_PTR), de
	ld	(FS_PTR+2), hl
	; Ok, now we can write our metadata
	call	fsWriteMeta
.end:
	pop	de
	pop	bc
	ret

; Place FS_PTR to the filename with the name in (HL).
; Sets Z on success, unset when not found.
fsFindFN:
	push	de
	call	fsBegin
	jr	nz, .end	; nothing to find, Z is unset
	ld	a, FS_MAX_NAME_SIZE
.loop:
	ld	de, FS_META+FS_META_FNAME_OFFSET
	call	strncmp
	jr	z, .end		; Z is set
	call	fsNext
	jr	z, .loop
	; End of the chain, not found
	call	unsetZ
.end:
	pop	de
	ret

; *** Metadata ***

; Sets Z according to whether the current block in FS_META is valid.
; Don't call other FS routines without checking block validity first: other
; routines don't do checks.
fsIsValid:
	push	hl
	push	de
	ld	a, 3
	ld	hl, FS_META
	ld	de, P_FS_MAGIC
	call	strncmp
	; The result of Z is our result.
	pop	de
	pop	hl
	ret

; Returns wheter current block is deleted in Z flag.
fsIsDeleted:
	ld	a, (FS_META+FS_META_FNAME_OFFSET)
	cp	0	; Z flag is our answer
	ret

; *** blkdev methods ***
; When "mounting" a FS, we copy the current blkdev's routine privately so that
; we can still access the FS even if blkdev selection changes. These routines
; below mimic blkdev's methods, but for our private mount.

fsblkGetC:
	ld	ix, (FS_GETC)
	jp	_blkCall

fsblkRead:
	ld	ix, (FS_GETC)
	jp	_blkRead

fsblkPutC:
	ld	ix, (FS_PUTC)
	jp	_blkCall

fsblkWrite:
	ld	ix, (FS_PUTC)
	jp	_blkWrite

fsblkSeek:
	ld	ix, (FS_SEEK)
	ld	iy, (FS_TELL)
	jp	_blkSeek

fsblkTell:
	ld	de, 0
	ld	ix, (FS_TELL)
	jp	_blkCall

; *** Handling ***

; Open file at current position into handle at (HL)
fsOpen:
	push	bc
	push	hl
	push	de
	push	af
	ex	de, hl
	; Starting pos
	ld	hl, FS_PTR
	ld	bc, 4
	ldir
	; Current pos
	ld	hl, FS_METASIZE
	call	writeHLinDE
	inc	de
	inc	de
	; file size
	ld      hl, (FS_META+FS_META_FSIZE_OFFSET)
	call	writeHLinDE
	pop	af
	pop	de
	pop	hl
	pop	bc
	ret

; Place FS blockdev at proper position for file handle in (DE).
fsPlaceH:
	push	af
	push	bc
	push	hl
	push	de
	pop	ix
	push	ix
	ld	e, (ix)
	ld	d, (ix+1)
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	c, (ix+4)
	ld	b, (ix+5)
	add	hl, bc
	jr	nc, .nocarry
	inc	de
.nocarry:
	ld	a, BLOCKDEV_SEEK_ABSOLUTE
	call	fsblkSeek
	pop	ix
	pop	hl
	pop	bc
	pop	af
	ret

; Advance file handle in (IX) by one byte
fsAdvanceH:
	push	af
	inc	(ix+4)
	jr	nz, .end
	inc	(ix+5)
.end:
	pop	af
	ret

; Sets Z according to whether file handle at (DE) is within bounds, that is, if
; current position is smaller than file size.
fsHandleWithinBounds:
	push	hl
	; current pos in HL, adjusted to remove FS_METASIZE
	call	fsTell
	push	de
	push	de \ pop ix
	; file size
	ld	e, (ix+6)
	ld	d, (ix+7)
	call	cpHLDE
	pop	de
	pop	hl
	jr	nc, .outOfBounds	; HL >= DE
	cp	a			; ensure Z
	ret
.outOfBounds:
	jp	unsetZ			; returns

; Read a byte in handle at (DE), put it into A and advance the handle's
; position.
; Z is set on success, unset if handle is at the end of the file.
fsGetC:
	call	fsHandleWithinBounds
	jr	z, .proceed
	; We want to unset Z, but also return 0 to ensure that a GetC that
	; doesn't check Z doesn't end up with false data.
	xor	a
	jp	unsetZ		; returns
.proceed:
	push	ix
	call	fsPlaceH
	push	ix		; Save handle in IX for fsAdvanceH
	call	fsblkGetC
	; increase current pos
	pop	ix		; recall handle in IX
	jr	nz, .end	; error, don't advance
	call	fsAdvanceH
.end:
	pop	ix
	ret

; Write byte A in handle (DE) and advance the handle's position.
; Z is set on success, unset if handle is at the end of the file.
; TODO: detect end of block alloc
fsPutC:
	call	fsPlaceH
	push	ix
	call	fsblkPutC
	; increase current pos
	pop	ix	; recall
	call	fsAdvanceH
	ret

; Sets position of handle (DE) to HL. This position does *not* include metadata.
; It is an offset that starts at actual data.
; Sets Z if offset is within bounds, unsets Z if it isn't.
fsSeek:
	push	de \ pop ix
	ld	a, FS_METASIZE
	call	addHL
	ld	(ix+4), l
	ld	(ix+5), h
	ret

fsTell:
	push	de \ pop ix
	ld	l, (ix+4)
	ld	h, (ix+5)
	ld	a, FS_METASIZE
	jp	subHL		; returns

; Mount the fs subsystem upon the currently selected blockdev at current offset.
; Verify is block is valid and error out if its not, mounting nothing.
; Upon mounting, copy currently selected device in FS_GETC/PUTC/SEEK/TELL.
fsOn:
	push	hl
	push	de
	push	bc
	; We have to set blkdev routines early before knowing whether the
	; mounting succeeds because methods like fsReadMeta uses fsblk* methods.
	ld	hl, BLOCKDEV_GETC
	ld	de, FS_GETC
	ld	bc, 8		; we have 8 bytes to copy
	ldir			; copy!
	call	fsblkTell
	ld	(FS_START), de
	ld	(FS_START+2), hl
	ld	(FS_PTR), de
	ld	(FS_PTR+2), hl
	call	fsReadMeta
	jr	nz, .error
	call	fsIsValid
	jr	nz, .error
	; success
	xor	a
	jr	.end
.error:
	; couldn't mount. Let's reset our variables.
	xor	a
	ld	b, FS_META-FS_GETC	; reset routine pointers and FS ptrs
	ld	hl, FS_GETC
	call	fill

	ld	a, FS_ERR_NO_FS
.end:
	pop	bc
	pop	de
	pop	hl
	ret

; Sets Z according to whether we have a filesystem mounted.
fsIsOn:
	; check whether (FS_GETC) is zero
	push	hl
	push	de
	ld	hl, (FS_GETC)
	ld	de, 0
	call	cpHLDE
	jr	nz, .mounted
	; if equal, it means our FS is not mounted
	call	unsetZ
	jr	.end
.mounted:
	cp	a	; ensure Z
.end:
	pop	de
	pop	hl
	ret
