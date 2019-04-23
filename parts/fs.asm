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
; Size in bytes of a FS handle:
; * 2 bytes for starting offset
; * 2 bytes for file size (we could fetch it from metadata all the time, but it
;   could be time consuming depending on the underlying device).
; * 2 bytes for current position.
; Starting offset is the *metadata* offset. We need, when we write to a handle,
; to change the size of the file.
FS_HANDLE_SIZE		.equ	6
FS_ERR_NO_FS		.equ	0x5

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

; *** CODE ***

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
	call	unsetZ
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

; Create a new file with A blocks allocated to it.
; Before doing so, enumerate all blocks in search of a deleted file with
; allocated space big enough. If it does, it will either take the whole space
; if the allocated space asked is exactly the same, or of it isn't, split the
; free space in 2 and create a new deleted metadata block next to the newly
; created block.
; Places FS_PTR to the newly allocated block. You have to write the new
; filename yourself.
fsAlloc:
	push	hl
	push	af		; keep A for later
	call	fsPlace
	ld	a, BLOCKDEV_SEEK_FORWARD
	ld	hl, 3
	call	blkSeek
	pop	af		; now we want our A arg
	call	blkPutC
	pop	hl
	call	fsPlace
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
	ld	de, .magic
	call	strncmp
	; The result of Z is our result.
	pop	de
	pop	hl
	ret
.magic:
	.db "CFS"

; Return, in A, the number of allocated blocks at current position.
fsAllocatedBlocks:
	ld	a, (FS_META+3)
	ret

; Return, in HL, the file size at current position.
fsFileSize:
	ld	hl, (FS_META+4)
	ret

; Return HL, which points to a null-terminated string which contains the
; filename at current position.
fsFileName:
	ld	hl, FS_META+6
	ret

; Change name of current file to name in (HL)
fsRename:
	push	af
	push	hl	; save filename for later
	call	fsPlace
	ld	a, BLOCKDEV_SEEK_FORWARD
	ld	hl, 6
	call	blkSeek
	pop	hl	; now we need the filename
	push	hl	; ... but let's preserve it for the caller
.loop:
	ld	a, (hl)
	cp	0
	jr	z, .end
	call	blkPutC
	inc	hl
	jr	.loop
.end:
	pop	hl
	pop	af
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
	call	fsFileName
	call	printstr
	call	printcrlf
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
	push	de
	ld	a, (hl)
	ex	de, hl
	inc	de
	call	intoDE
	ex	de, hl
	call	fsAlloc
	call	fsRename
	pop	de
	pop	hl
	xor	a
	ret
