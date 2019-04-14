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
CR	.equ	0x0d
LF	.equ	0x0a

; number of entries in shellCmdTbl
SHELL_CMD_COUNT	.equ	2

; The command that was type isn't known to the shell
SHELL_ERR_UNKNOWN_CMD	.equ	0x01

; Arguments for the command weren't properly formatted
SHELL_ERR_BAD_ARGS	.equ	0x02

; *** CODE ***
shellInit:
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

; print null-terminated string pointed to by HL
printstr:
	push	af
	push	hl

.loop:
	ld	a, (hl)		; load character to send
	or	a		; is it zero?
	jr	z, .end		; if yes, we're finished
	call	aciaPutC
	inc	hl
	jr	.loop

.end:
	pop	hl
	pop	af
	ret

printcrlf:
	ld	a, CR
	call	aciaPutC
	ld	a, LF
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

	cp	CR
	jr	z, .do		; char is CR? do!
	cp	LF
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

; Compares strings pointed to by HL and DE up to A count of characters. If
; equal, Z is set. If not equal, Z is reset.
strncmp:
	push	bc
	push	hl
	push	de

	ld	b, a
.loop:
	ld	a, (de)
	cp	(hl)
	jr	nz, .end	; not equal? break early
	inc	hl
	inc	de
	djnz	.loop

.end:
	pop	de
	pop	hl
	pop	bc
	; Because we don't call anything else than CP that modify the Z flag,
	; our Z value will be that of the last cp (reset if we broke the loop
	; early, set otherwise)
	ret

; add the value of A into DE
addDE:
	add	a, e
	jr	nc, .end	; no carry? skip inc
	inc	d
.end:
	ld	e, a
	ret

; jump to the location pointed to by HL. This allows us to call HL instead of
; just jumping it.
jumpHL:
	jp	hl
	ret

; Parse command (null terminated) at HL and calls it
shellParse:
	push	af
	push	bc
	push	de

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
	ld	a, 4
	call	addDE
	ex	hl, de
	call	jumpHL
	ex	hl, de

.end:
	pop	de
	pop	bc
	pop	af
	ret

; Print the error code set in A (doesn't work for codes > 9 yet...)
shellPrintErr:
	push	af
	push	hl

	ld	hl, .str
	call	printstr

	; ascii for '0' is 0x30
	add	a, 0x30
	call	aciaPutC
	call	printcrlf

	pop	hl
	pop	af
	ret

.str:
	.db	"ERR ", 0

; *** COMMANDS ***
shellSeek:
	ld	hl, .str
	call	printstr
	ret
.str:
	.db	"seek called", CR, LF, 0

shellPeek:
	ld	hl, .str
	call	printstr
	ret
.str:
	.db	"peek called", CR, LF, 0

; Format: 4 bytes name followed by 2 bytes jump. fill names with zeroes
shellCmdTbl:
	.db	"seek"
	jr	shellSeek
	.db	"peek"
	jr	shellPeek

