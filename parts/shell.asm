; shell
;
; Runs a shell over a block device interface.

; Status: incomplete. As it is now, it spits a welcome prompt, wait for input
; and compare the first 4 chars of the input with a command table and call the
; appropriate routine if it's found, an error if it's not.
;
; Commands, for now, are partially implemented.
;
; See constants below for error codes.
;
; All numerical values in the Collapse OS shell are represented and parsed in
; hexadecimal form, without prefix or suffix.

; *** DEFINES ***
; SHELL_GETC: Macro that calls a GetC routine
; SHELL_PUTC: Macro that calls a PutC routine
; SHELL_RAMSTART

; *** CONSTS ***

; number of entries in shellCmdTbl
SHELL_CMD_COUNT	.equ	4

; The command that was type isn't known to the shell
SHELL_ERR_UNKNOWN_CMD	.equ	0x01

; Arguments for the command weren't properly formatted
SHELL_ERR_BAD_ARGS	.equ	0x02

; Size of the shell command buffer. If a typed command reaches this size, the
; command is flushed immediately (same as pressing return).
SHELL_BUFSIZE		.equ	0x20

; *** VARIABLES ***
; Memory address that the shell is currently "pointing at" for peek and deek
; operations. Set with seek.
SHELL_MEM_PTR	.equ	SHELL_RAMSTART
; Used to store formatted hex values just before printing it.
SHELL_HEX_FMT	.equ	SHELL_MEM_PTR+2

; Command buffer. We read types chars into this buffer until return is pressed
; This buffer is null-terminated and we don't keep an index around: we look
; for the null-termination every time we write to it. Simpler that way.
SHELL_BUF	.equ	SHELL_HEX_FMT+2

SHELL_RAMEND	.equ	SHELL_BUF+SHELL_BUFSIZE

; *** CODE ***
shellInit:
	xor	a
	ld	(SHELL_MEM_PTR), a
	ld	(SHELL_BUF), a

	; print welcome
	ld	hl, .welcome
	call	printstr
	ret

.welcome:
	.db	"Collapse OS", ASCII_CR, ASCII_LF, "> ", 0

shellLoop:
	; First, let's wait until something is typed.
	SHELL_GETC
	; got it. Now, is it a CR or LF?
	cp	ASCII_CR
	jr	z, .do		; char is CR? do!
	cp	ASCII_LF
	jr	z, .do		; char is LF? do!

	; Echo the received character right away so that we see what we type
	SHELL_PUTC

	; Ok, gotta add it do the buffer
	; save char for later
	ex	af, af'
	ld	hl, SHELL_BUF
	call	findnull	; HL points to where we need to write
				; A is the number of chars in the buf
	cp	SHELL_BUFSIZE
	jr	z, .do		; A == bufsize? then our buffer is full. do!

	; bring the char back in A
	ex	af, af'
	; Buffer not full, not CR or LF. Let's put that char in our buffer and
	; read again.
	ld	(hl), a
	; Now, write a zero to the next byte to properly terminate our string.
	inc	hl
	xor	a
	ld	(hl), a

	jr	shellLoop

.do:
	call	printcrlf
	ld	hl, SHELL_BUF
	call	shellParse
	; empty our buffer by writing a zero to its first char
	xor	a
	ld	(hl), a

	ld	hl, .prompt
	call	printstr
	jr	shellLoop

.prompt:
	.db	"> ", 0

printcrlf:
	ld	a, ASCII_CR
	SHELL_PUTC
	ld	a, ASCII_LF
	SHELL_PUTC
	ret

; Parse command (null terminated) at HL and calls it
shellParse:
	push	af
	push	bc
	push	de
	push	hl
	push	ix

	ld	de, shellCmdTbl
	ld	a, SHELL_CMD_COUNT
	ld	b, a

.loop:
	ld	a, 4		; 4 chars to compare
	call	strncmp
	jr	z, .found
	ld	a, 7
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
	ld	ixh, d
	ld	ixl, e
	; Now, let's swap HL and DE because, well because that's how we're set.
	ex	hl, de	; DE = cmd str pointer

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
	; DE points to args, IX points to jump line. Ready to roll!
	call	callIX

.end:
	pop	ix
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

; Set memory pointer to the specified address (word).
; Example: seek 01fe

shellSeek:
	push	af
	push	de
	push	hl

	ex	de, hl
	ld	de, SHELL_MEM_PTR
	ld	a, 2
	call	parseHexChain
	jr	c, .error
	; z80 is little endian. in a "ld hl, (nn)" op, L is loaded from the
	; first byte, H is loaded from the second. We have to swap our result.
	ld	hl, SHELL_MEM_PTR
	call	swapBytes
	jr	.success

.error:
	ld	a, SHELL_ERR_BAD_ARGS
	call	shellPrintErr
	jr	.end

.success:
	ld	a, (SHELL_MEM_PTR+1)
	ld	hl, SHELL_HEX_FMT
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	ld	a, (SHELL_MEM_PTR)
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	call	printcrlf

.end:
	pop	hl
	pop	de
	pop	af
	ret


; peek byte where memory pointer points to any display its value. If the
; optional numerical byte arg is supplied, this number of bytes will be printed
;
; Example: peek 2 (will print 2 bytes)
shellPeek:
	push	af
	push	bc
	push	de
	push	hl

	ld	b, 1		; by default, we run the loop once
	ld	a, (de)
	cp	0
	jr	z, .success	; no arg? don't try to parse

	ex	de, hl
	call	parseHexPair
	jr	c, .error
	cp	0
	jr	z, .error	; zero isn't a good arg, error
	ld	b, a		; loop the number of times specified in arg
	jr	.success

.error:
	ld	a, SHELL_ERR_BAD_ARGS
	call	shellPrintErr
	jr	.end

.success:
	ld	hl, (SHELL_MEM_PTR)
.loop:	ld	a, (hl)
	ex	hl, de
	ld	hl, SHELL_HEX_FMT
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	ex	hl, de
	inc	hl
	djnz	.loop
	call	printcrlf

.end:
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

; Load the specified number of bytes (max 0xff) from IO and write them in the
; current memory pointer (which doesn't change). For now, we can only load from
; SHELL_GETC, but a method of selecting IO sources is coming, making this
; command much more useful.
; Control is returned to the shell only after all bytes are read.
;
; Example: load 42
shellLoad:
	push	af
	push	bc
	push	hl

	ld	a, (de)
	call	parseHex
	jr	c, .error
	jr	.success

.error:
	ld	a, SHELL_ERR_BAD_ARGS
	call	shellPrintErr
	jr	.end

.success:
	ld	b, a
	ld	hl, (SHELL_MEM_PTR)
.loop:  SHELL_GETC
	ld	(hl), a
	inc	hl
	djnz	.loop

.end:
	pop	hl
	pop	bc
	pop	af
	ret

; Calls the routine where the memory pointer currently points. This can take two
; parameters, A and HL. The first one is a byte, the second, a word. These are
; the values that A and HL are going to be set to just before calling.
; Example: run 42 cafe
shellCall:
	push	af
	push	de
	push	hl

	ld	a, (de)
	cp	0
	jr	z, .defA	; no arg? don't try to parse
	call	parseHex
	jr	c, .error
	; We have a proper A arg, in A. We push it for later use, just before
	; the actual call.
	push	af

	; Let's try DE parsing now
	inc	de
	inc	de
	ld	a, (de)
	cp	0
	jr	z, .defDE	; no arg? don't try to parse
	inc	de		; we're on a space (maybe...) we parse the
				; next char
	ex	hl, de		; we need HL to point to our hex str for
				; parseHexChain
	; We need a tmp 2 bytes space for our result. Let's use SHELL_HEX_FMT.
	ld	de, SHELL_HEX_FMT
	ld	a, 2
	call	parseHexChain
	jr	c, .error
	ex	hl, de		; result is in DE, we need it in HL
	call	swapBytes
	; Alright, we have a proper address in (SHELL_HEX_FMT), let's push it
	; to the stack
	ld	hl, (SHELL_HEX_FMT)
	push	hl
	jr	.success

.error:
	ld	a, SHELL_ERR_BAD_ARGS
	call	shellPrintErr
	jr	.end

.defA:
	xor	a
	push	af
.defDE:
	ld	hl, 0
	push	hl
.success:
	; Let's recap here. At this point, we have:
	; 1. The address we want to execute in (SHELL_MEM_PTR)
	; 2. our HL arg on top of the stack
	; 3. our A arg underneath.
	; Ready, set, go!
	ld	a, (SHELL_MEM_PTR)
	ld	ixl, a
	ld	a, (SHELL_MEM_PTR+1)
	ld	ixh, a
	pop	hl
	pop	af
	call	callIX

.end:
	pop	hl
	pop	de
	pop	af
	ret

; Format: 4 bytes name followed by 3 bytes jump. fill names with zeroes
shellCmdTbl:
	.db	"seek"
	jp	shellSeek
	.db	"peek"
	jp	shellPeek
	.db	"load"
	jp	shellLoad
	.db	"call"
	jp	shellCall

