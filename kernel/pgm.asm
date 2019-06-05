; pgm - execute programs loaded from filesystem
;
; Implements a shell hook that searches the filesystem for a file with the same
; name as the cmd, loads that file in memory and executes it, sending the
; program a pointer to *unparsed* arguments in HL.
;
; We expect the loaded program to return a status code in A. 0 means success,
; non-zero means error. Programs should avoid having error code overlaps with
; the shell so that we know where the error comes from.
;
; *** Requirements ***
; fs
;
; *** Defines ***
; PGM_CODEADDR: Memory address where to place the code we load.
;
; *** Variables ***
.equ	PGM_HANDLE	PGM_RAMSTART
.equ	PGM_RAMEND	PGM_HANDLE+FS_HANDLE_SIZE

; Routine suitable to plug into SHELL_CMDHOOK. HL points to the full cmdline.
; We can mutate it because the shell doesn't do anything with it afterwards.
pgmShellHook:
	call	fsIsOn
	jr	nz, .noFile
	; first first space and replace it with zero so that we have something
	; suitable for fsFindFN.
	push	hl	; remember beginning
	ld	a, ' '
	call	findchar
	jr	nz, .noarg	; if we have no arg, we want DE to point to the
				; null char. Also, we have no replacement to
				; make
	; replace space with nullchar
	xor	a
	ld	(hl), a
	inc	hl		; make HL point to the beginning of args
.noarg:
	ex	de, hl	; DE now points to the beginning of args or to \0 if
			; no args
	pop	hl	; HL points to cmdname, properly null-terminated
	call	fsFindFN
	jr	nz, .noFile
	; We have a file! Load it and run it.
	ex	de, hl	; but first, make HL point to unparsed args.
	jp	pgmRun
.noFile:
	ld	a, SHELL_ERR_IO_ERROR
	ret

; Loads code in file that FS_PTR is currently pointing at and place it in
; PGM_CODEADDR. Then, jump to PGM_CODEADDR. We expect HL to point to unparsed
; arguments being given to the program.
pgmRun:
	call	fsIsValid
	jr	nz, .ioError
	push	hl		; unparsed args
	ld	ix, PGM_HANDLE
	call	fsOpen
	ld	hl, 0		; addr that we read in file handle
	ld	de, PGM_CODEADDR	; addr in mem we write to
.loop:
	call	fsGetC		; we use Z at end of loop
	ld	(de), a		; Z preserved
	inc	hl		; Z preserved in 16-bit
	inc	de		; Z preserved in 16-bit
	jr	z, .loop

	pop	hl		; recall args
	; ready to jump!
	jp	PGM_CODEADDR

.ioError:
	ld	a, SHELL_ERR_IO_ERROR
	ret
