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
; SHELL_GETC: Macro that calls a GetC routine for tty interface
; SHELL_PUTC: Macro that calls a PutC routine for tty interface
; SHELL_IO_GETC: Macro that calls a GetC routine for I/O ("load" cmd)
; SHELL_EXTRA_CMD_COUNT: Number of extra cmds to be expected after the regular
;                        ones. See comment in COMMANDS section for details.
; SHELL_RAMSTART

; *** CONSTS ***

; number of entries in shellCmdTbl
SHELL_CMD_COUNT	.equ	4+SHELL_EXTRA_CMD_COUNT

; maximum number of bytes to receive as args in all commands. Determines the
; size of the args variable.
SHELL_CMD_ARGS_MAXSIZE	.equ	3

; The command that was type isn't known to the shell
SHELL_ERR_UNKNOWN_CMD	.equ	0x01

; Arguments for the command weren't properly formatted
SHELL_ERR_BAD_ARGS	.equ	0x02

; Size of the shell command buffer. If a typed command reaches this size, the
; command is flushed immediately (same as pressing return).
SHELL_BUFSIZE		.equ	0x20

; *** VARIABLES ***
; Memory address that the shell is currently "pointing at" for peek, load, call
; operations. Set with seek.
SHELL_MEM_PTR	.equ	SHELL_RAMSTART
; Used to store formatted hex values just before printing it.
SHELL_HEX_FMT	.equ	SHELL_MEM_PTR+2

; Places where we store arguments specifiers and where resulting values are
; written to after parsing.
SHELL_CMD_ARGS	.equ	SHELL_HEX_FMT+2

; Command buffer. We read types chars into this buffer until return is pressed
; This buffer is null-terminated and we don't keep an index around: we look
; for the null-termination every time we write to it. Simpler that way.
SHELL_BUF	.equ	SHELL_CMD_ARGS+SHELL_CMD_ARGS_MAXSIZE

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
	push	de		; we need to keep that table entry around...
	call	intoDE		; Jump from the table entry to the cmd addr.
	ld	a, 4		; 4 chars to compare
	call	strncmp
	pop	de
	jr	z, .found
	inc	de
	inc	de
	djnz	.loop

	; exhausted loop? not found
	ld	a, SHELL_ERR_UNKNOWN_CMD
	call	shellPrintErr
	jr	.end

.found:
	; we found our command. DE points to its table entry. Now, let's parse
	; our args.
	call	intoDE		; Jump from the table entry to the cmd addr.

	; advance the HL pointer to the beginning of the args.
	ld	a, 4
	call	addHL

	; Now, let's have DE point to the argspecs
	ld	a, 4
	call	addDE

	; We're ready to parse args
	call	shellParseArgs
	cp	0
	jr	nz, .parseerror

	ld	hl, SHELL_CMD_ARGS
	; Args parsed, now we can load the routine address and call it.
	; let's have DE point to the jump line
	ld	a, SHELL_CMD_ARGS_MAXSIZE
	call	addDE
	ld	ixh, d
	ld	ixl, e
	; Ready to roll!
	call	callIX
	jr	.end

.parseerror:
	ld	a, SHELL_ERR_BAD_ARGS
	call	shellPrintErr
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

; Parse arguments at (HL) with specifiers at (DE) into (SHELL_CMD_ARGS).
; (HL) should point to the character *just* after the name of the command
; because we verify, in the case that we have args, that we have a space there.
;
; Args specifiers are a series of flag for each arg:
; Bit 0 - arg present: if unset, we stop parsing there
; Bit 1 - is word: this arg is a word rather than a byte. Because our
;                  destination are bytes anyway, this doesn't change much except
;                  for whether we expect a space between the hex pairs. If set,
;                  you still need to have a specifier for the second part of
;                  the multibyte.
; Bit 2 - optional: If set and not present during parsing, we don't error out
;		    and write zero
;
; Sets A to nonzero if there was an error during parsing, zero otherwise.
; If there was an error during parsing, carry is set.
shellParseArgs:
	push	bc
	push	de
	push	hl
	push	ix

	ld	ix, SHELL_CMD_ARGS
	ld	a, SHELL_CMD_ARGS_MAXSIZE
	ld	b, a
	xor	c
.loop:
	; init the arg value to a default 0
	xor	a
	ld	(ix), a

	ld	a, (hl)
	; is this the end of the line?
	cp	0
	jr	z, .endofargs

	; do we have a proper space char?
	cp	' '
	jr	z, .hasspace	; We're fine

	; is our previous arg a multibyte? (argspec still in C)
	bit	1, c
	jr	z, .error	; bit not set? error
	dec	hl		; offset the "inc hl" below

.hasspace:
	; Get the specs
	ld	a, (de)
	bit	0, a		; do we have an arg?
	jr	z, .error	; not set? then we have too many args
	ld	c, a		; save the specs for the next loop
	inc	hl		; (hl) points to a space, go next
	call	parseHexPair
	jr	c, .error
	; we have a good arg and we need to write A in (IX).
	ld	(ix), a

	; Good! increase counters
	inc	de
	inc	ix
	inc	hl		; get to following char (generally a space)
	djnz	.loop
	; If we get here, it means that our next char *has* to be a null char
	ld	a, (hl)
	cp	0
	jr	z, .success	; zero? great!
	jr	.error

.endofargs:
	; We encountered our null char. Let's verify that we either have no
	; more args or that they are optional
	ld	a, (de)
	cp	0
	jr	z, .success	; no arg? success
	bit	2, a
	jr	nz, .success	; if set, arg is optional. success
	jr	.error

.success:
	xor	a
	jr	.end
.error:
	inc	a
.end:
	pop	ix
	pop	hl
	pop	de
	pop	bc
	ret

; *** COMMANDS ***
; A command is a 4 char names, followed by a SHELL_CMD_ARGS_MAXSIZE bytes of
; argument specs, followed by the routine. Then, a simple table of addresses
; is compiled in a block and this is what is iterated upon when we want all
; available commands.
;
; Format: 4 bytes name followed by SHELL_CMD_ARGS_MAXSIZE bytes specifiers,
;         followed by 3 bytes jump. fill names with zeroes
;
; When these commands are called, HL points to the first byte of the
; parsed command args.
;
; Extra commands: Other parts might define new commands. You can add these
;                 commands to your shell. First, set SHELL_EXTRA_CMD_COUNT to
;                 the number of extra commands to add, then add a ".dw"
;                 directive *just* after your '#include "shell.asm"'. Voila!
;

; Set memory pointer to the specified address (word).
; Example: seek 01fe
shellSeekCmd:
	.db	"seek", 0b011, 0b001, 0
shellSeek:
	push	af
	push	de
	push	hl

	; z80 is little endian. in a "ld hl, (nn)" op, L is loaded from the
	; first byte, H is loaded from the second.
	ld	a, (hl)
	ld	(SHELL_MEM_PTR+1), a
	inc	hl
	ld	a, (hl)
	ld	(SHELL_MEM_PTR), a

	ld	de, (SHELL_MEM_PTR)
	ld	hl, SHELL_HEX_FMT
	ld	a, d
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	ld	a, e
	call	fmtHexPair
	ld	a, 2
	call	printnstr
	call	printcrlf

	pop	hl
	pop	de
	pop	af
	ret


; peek byte where memory pointer points to any display its value. If the
; optional numerical byte arg is supplied, this number of bytes will be printed
;
; Example: peek 2 (will print 2 bytes)
shellPeekCmd:
	.db	"peek", 0b101, 0, 0
shellPeek:
	push	af
	push	bc
	push	de
	push	hl

	ld	a, (hl)
	cp	0
	jr	nz, .arg1isset	; if arg1 is set, no need for a default
	ld	a, 1		; default for arg1
.arg1isset:
	ld	b, a
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
; current memory pointer (which doesn't change). This gets chars from
; SHELL_IO_GETC, which can be different from SHELL_GETC. Coupled with the
; "blockdev" part, this allows you to dynamically select your IO source.
; Control is returned to the shell only after all bytes are read.
;
; Example: load 42
shellLoadCmd:
	.db	"load", 0b001, 0, 0
shellLoad:
	push	af
	push	bc
	push	hl

	ld	a, (hl)
	ld	b, a
	ld	hl, (SHELL_MEM_PTR)
.loop:  SHELL_IO_GETC
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
shellCallCmd:
	.db	"call", 0b101, 0b111, 0b001
shellCall:
	push	af
	push	hl
	push	ix

	; Let's recap here. At this point, we have:
	; 1. The address we want to execute in (SHELL_MEM_PTR)
	; 2. our A arg as the first byte of (HL)
	; 2. our HL arg as (HL+1) and (HL+2)
	; Ready, set, go!
	ld	a, (SHELL_MEM_PTR)
	ld	ixl, a
	ld	a, (SHELL_MEM_PTR+1)
	ld	ixh, a
	ld	a, (hl)
	ex	af, af'
	inc	hl
	ld	a, (hl)
	exx
	ld	h, a
	exx
	inc	hl
	ld	a, (hl)
	exx
	ld	l, a
	ex	af, af'
	call	callIX

.end:
	pop	ix
	pop	hl
	pop	af
	ret

; This table is at the very end of the file on purpose. The idea is to be able
; to graft extra commands easily after an include in the glue file.
shellCmdTbl:
	.dw shellSeekCmd, shellPeekCmd, shellLoadCmd, shellCallCmd

