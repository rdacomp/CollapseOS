; *** SHELL COMMANDS ***
fsOnCmd:
	.db	"fson", 0, 0, 0
	jp	fsOn

; Lists filenames in currently active FS
flsCmd:
	.db	"fls", 0, 0, 0, 0
	call	fsIsOn
	jr	nz, .error
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
	jr	z, .loop	; Z set? fsNext was successful
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
	call	intoHL		; HL now holds the string we look for
	call	fsFindFN
	jr	nz, .notfound
	; Found! delete
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


; Opens specified filename in specified file handle.
; First argument is file handle, second one is file name.
; Example: fopn 0 foo.txt
fopnCmd:
	.db	"fopn", 0b001, 0b1001, 0b001
	push	hl
	push	de
	ld	a, (hl)		; file handle index
	ld	de, FS_HANDLES
	or	a		; cp 0
	jr	z, .noInc	; DE already point to correct handle
	ld	b, a
.loop:
	ld	a, FS_HANDLE_SIZE
	call	addDE
	djnz	.loop
.noInc:
	; DE now stores pointer to file handle
	inc	hl
	call	intoHL		; HL now holds the string we look for
	call	fsFindFN
	jr	nz, .notfound
	; Found!
	; FS_PTR points to the file we want to open
	push	de \ pop ix	; IX now points to the file handle.
	call	fsOpen
	jr	.end
.notfound:
	ld	a, FS_ERR_NOT_FOUND
.end:
	pop	de
	pop	hl
	ret
