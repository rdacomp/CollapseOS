; shell
;
; Runs a shell over an asynchronous communication interface adapter (ACIA).
; for now, this unit is tightly coupled to acia.asm, but it will eventually be
; more general than that.

; Status: incomplete. As it is now, it spits a welcome prompt, wait for input
; and compare the first 4 chars of the input with a command table and call the
; appropriate routine if it's found, an error if it's not.
;
; Commands, for now, are dummy.
;
; See constants below for error codes.

; *** CONSTS ***

; number of entries in shellCmdTbl
SHELL_CMD_COUNT	.equ	2

; The command that was type isn't known to the shell
SHELL_ERR_UNKNOWN_CMD	.equ	0x01

; Arguments for the command weren't properly formatted
SHELL_ERR_BAD_ARGS	.equ	0x02

; *** VARIABLES ***
; Memory address that the shell is currently "pointing at" for peek and deek
; operations. Set with seek.
SHELL_MEM_PTR	.equ	SHELL_RAMSTART
; Used to store formatted hex values just before printing it.
SHELL_HEX_FMT	.equ	SHELL_MEM_PTR+2
SHELL_RAMEND	.equ	SHELL_HEX_FMT+2

; *** CODE ***
shellInit:
	xor	a
	ld	(SHELL_MEM_PTR), a

	; print prompt
	ld	hl, .prompt
	call	printstr
	call	printcrlf
	ret

.prompt:
	.db	"Collapse OS", 0

shellLoop:
	call	chkbuf
	jr	shellLoop


printcrlf:
	ld	a, ASCII_CR
	call	aciaPutC
	ld	a, ASCII_LF
	call	aciaPutC
	ret

; check if the input buffer is full or ends in CR or LF. If it does, prints it
; back and empty it.
chkbuf:
	call	aciaBufPtr
	cp	0
	ret	z		; BUFIDX is zero? nothing to check.

	cp	ACIA_BUFSIZE
	jr	z, .do		; if BUFIDX == BUFSIZE? do!

	; our previous char is in BUFIDX - 1. Fetch this
	dec	hl
	ld	a, (hl)		; now, that's our char we have in A
	inc	hl		; put HL back where it was

	cp	ASCII_CR
	jr	z, .do		; char is CR? do!
	cp	ASCII_LF
	jr	z, .do		; char is LF? do!

	; nothing matched? don't do anything
	ret

.do:
	; terminate our string with 0
	xor	a
	ld	(hl), a
	; reset buffer index
	ld	(ACIA_BUFIDX), a

	; alright, let's go!
	ld	hl, ACIA_BUF
	call	shellParse
	ret

; Parse command (null terminated) at HL and calls it
shellParse:
	push	af
	push	bc
	push	de
	push	hl

	ld	de, shellCmdTbl
	ld	a, SHELL_CMD_COUNT
	ld	b, a

.loop:
	ld	a, 4		; 4 chars to compare
	call	strncmp
	jr	z, .found
	ld	a, 6
	call	addDE
	djnz	.loop

	; exhausted loop? not found
	ld	a, SHELL_ERR_UNKNOWN_CMD
	call	shellPrintErr
	jr	.end

.found:
	; all right, we're almost ready to call the cmd. Let's just have DE
	; point to the cmd jump line.
	ld	a, 4
	call	addDE
	; Now, let's swap HL and DE because, welll because that's how we're set.
	ex	hl, de	; HL = jump line, DE = cmd str pointer

	; Before we call our command, we want to set up the pointer to the arg
	; list. Normally, it's DE+5 (DE+4 is the space) unless DE+4 is null,
	; which means no arg.
	ld	a, 4
	call	addDE
	ld	a, (DE)
	cp	0
	jr	z, .noarg	; char is null? we have no arg
	inc	de
.noarg:
	; DE points to args, HL points to jump line. Ready to roll!
	call	jumpHL

.end:
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

; Print the error code set in A (in hex)
shellPrintErr:
	push	af
	push	hl

	ld	hl, .str
	call	printstr

	ld	hl, SHELL_HEX_FMT
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	call	printcrlf

	pop	hl
	pop	af
	ret

.str:
	.db	"ERR ", 0

; *** COMMANDS ***
; When these commands are called, DE points to the first character of the
; command args.

; Set memory pointer to the specified address.
; Example: seek 01fe

shellSeek:
	push	de
	push	hl

	ex	de, hl
	call	parseHexPair
	jr	c, .error
	ld	(SHELL_MEM_PTR), a
	inc	hl
	inc	hl
	call	parseHexPair
	jr	c, .error
	ld	(SHELL_MEM_PTR+1), a
	jr	.success

.error:
	ld	a, SHELL_ERR_BAD_ARGS
	call	shellPrintErr
	jr	.end

.success:
	ld	a, (SHELL_MEM_PTR)
	ld	hl, SHELL_HEX_FMT
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	ld	a, (SHELL_MEM_PTR+1)
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	call	printcrlf

.end:
	pop	hl
	pop	de
	ret


; peek byte where memory pointer points to aby display its value
shellPeek:
	push	af
	push	hl

	ld	hl, (SHELL_MEM_PTR)
	ld	a, (hl)
	ld	hl, SHELL_HEX_FMT
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	call	printcrlf

	pop	hl
	pop	af
	ret

; Format: 4 bytes name followed by 2 bytes jump. fill names with zeroes
shellCmdTbl:
	.db	"seek"
	jr	shellSeek
	.db	"peek"
	jr	shellPeek

