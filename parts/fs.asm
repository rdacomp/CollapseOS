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
; "bsel" foesn't affect the currently mounted fs, which can still be interacted
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
FS_MAX_NAME_SIZE	.equ	0x1a
FS_BLOCKSIZE		.equ	0x100

FS_META_ALLOC_OFFSET	.equ	3
FS_META_FSIZE_OFFSET	.equ	4
FS_META_FNAME_OFFSET	.equ	6
; Size in bytes of a FS handle:
; * 2 bytes for starting offset
; * 2 bytes for file size (we could fetch it from metadata all the time, but it
;   could be time consuming depending on the underlying device).
; * 2 bytes for current position.
; Starting offset is the *metadata* offset. We need, when we write to a handle,
; to change the size of the file.
FS_HANDLE_SIZE		.equ	6
FS_ERR_NO_FS		.equ	0x5
FS_ERR_NOT_FOUND	.equ	0x6

; *** VARIABLES ***
; A copy of BLOCKDEV_SEL when the FS was mounted. 0 if no FS is mounted.
FS_BLKSEL	.equ	FS_RAMSTART
; Offset at which our FS start on mounted device
FS_START	.equ	FS_BLKSEL+2
; Offset at which we are currently pointing to with regards to our routines
; below, which all assume this offset as a context. This offset is not relative
; to FS_START. It can be used directly with blkSeek.
FS_PTR		.equ	FS_START+2
; This variable below contain the metadata of the last block FS_PTR was moved
; to. We read this data in memory to avoid constant seek+read operations.
FS_META		.equ	FS_PTR+2
FS_HANDLES	.equ	FS_META+0x20
FS_RAMEND	.equ	FS_HANDLES+(FS_HANDLE_COUNT*FS_HANDLE_SIZE)

; *** DATA ***
P_FS_MAGIC:
	.db	"CFS", 0

; *** CODE ***

fsInit:
	xor	a
	ld	hl, FS_BLKSEL
	ld	b, FS_RAMEND-FS_BLKSEL
	call	fill
	ret

; *** Navigation ***

; Resets FS_PTR to the beginning. Errors out if no FS is mounted.
; Sets Z if success, unset if error
fsBegin:
	push	hl
	ld	hl, (FS_START)
	ld	(FS_PTR), hl
	pop	hl
	call	fsReadMeta
	call	fsIsValid	; sets Z
	ret

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
	ld	a, BLOCKDEV_SEEK_FORWARD
	ld	hl, FS_BLOCKSIZE
.loop:
	call	blkSeek
	djnz	.loop
	; Good, were here. We're going to read meta from our current position.
	call	blkTell	; --> HL
	ld	(FS_PTR), hl
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
; Returns Z according to whether the blkRead operation succeeded.
fsReadMeta:
	call	fsPlace
	push	bc
	push	hl
	ld	b, 0x20
	ld	hl, FS_META
	call	blkRead		; Sets Z
	pop	hl
	pop	bc
	ret

; Writes metadata in FS_META at current FS_PTR.
; Returns Z according to whether the blkWrite operation succeeded.
fsWriteMeta:
	call	fsPlace
	push	bc
	push	hl
	ld	b, 0x20
	ld	hl, FS_META
	call	blkWrite	; Sets Z
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
	ld	b, 0x20-3
	call	fill
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

; Make sure that our underlying blockdev is correcly placed.
fsPlace:
	push	af
	push	hl
	xor	a
	ld	hl, (FS_PTR)
	call	blkSeek
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
	call	blkTell
	ld	(FS_PTR), hl
	; Ok, now we can write our metadata
	call	fsWriteMeta
.end:
	pop	de
	pop	bc
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

; *** Handling ***

; Open file at current position into handle at (HL)
fsOpen:
	ret

; Ensures that file size in metadata corresponds to file size in handle as (HL).
fsCommit:
	ret

; Read a byte in handle at (HL), put it into A and advance the handle's
; position.
; Z is set on success, unset if handle is at the end of the file.
fsRead:
	ret

; Write byte A in handle at (HL) and advance the handle's position.
; Z is set on success, unset if handle is at the end of the allocated space.
fsWrite:
	ret

; Sets position of handle (HL) to DE. This position does *not* include metadata.
; It is an offset that starts at actual data.
; Sets Z if offset is within bounds, unsets Z if it isn't.
fsSeek:
	ret

; *** SHELL COMMANDS ***
; Mount the fs subsystem upon the currently selected blockdev at current offset.
; Verify is block is valid and error out if its not, mounting nothing.
; Upon mounting, copy currently selected device in FS_BLKSEL.
fsOnCmd:
	.db	"fson", 0, 0, 0
	push	hl
	call	blkTell
	ld	(FS_PTR), hl
	call	fsReadMeta
	jr	nz, .error
	call	fsIsValid
	jr	nz, .error
	; success
	ld	(FS_START), hl
	xor	a
	jr	.end
.error:
	ld	a, FS_ERR_NO_FS
.end:
	pop	hl
	ret

; Lists filenames in currently active FS
flsCmd:
	.db	"fls", 0, 0, 0, 0
	call	fsBegin
	jr	nz, .error
.loop:
	call	fsIsDeleted
	jr	z, .skip
	ld	hl, FS_META+FS_META_FNAME_OFFSET
	call	printstr
	call	printcrlf
.skip:
	call	fsNext
	jr	z, .loop	; Z set? fsNext was successfull
	xor	a
	jr	.end
.error:
	ld	a, FS_ERR_NO_FS
.end:
	ret

; Takes one byte block number to allocate as well we one string arg filename
; and allocates a new file in the current fs.
fnewCmd:
	.db	"fnew", 0b001, 0b1001, 0b001
	push	hl
	ld	a, (hl)
	inc	hl
	call	intoHL
	call	fsAlloc
	pop	hl
	xor	a
	ret

; Deletes filename with specified name
fdelCmd:
	.db	"fdel", 0b1001, 0b001, 0
	push	hl
	push	de
	ex	hl, de
	call	intoDE		; DE now holds the string we look for
	call	fsBegin
	jr	nz, .notfound
	ld	a, FS_MAX_NAME_SIZE
.loop:
	ld	hl, FS_META+FS_META_FNAME_OFFSET
	call	strncmp
	jr	z, .found
	call	fsNext
	jr	z, .loop
	; End of chain, not found
	jr	.notfound
.found:
	xor	a
	; Set filename to zero to flag it as deleted
	ld	(FS_META+FS_META_FNAME_OFFSET), a
	call	fsWriteMeta
	; a already to 0, our result.
	jr	.end
.notfound:
	ld	a, FS_ERR_NOT_FOUND
.end:
	pop	de
	pop	hl
	ret
