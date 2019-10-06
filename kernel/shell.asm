; shell
;
; Runs a shell over a block device interface.

; The shell spits a welcome prompt, wait for input and compare the first 4 chars
; of the input with a command table and call the appropriate routine if it's
; found, an error if it's not.
;
; To determine the correct routine to call we first go through cmds in
; shellCmdTbl. This means that we first go through internal cmds, then cmds
; "grafted" by glue code.
;
; If the command isn't found, SHELL_CMDHOOK is called, which should set A to
; zero if it executes something. Otherwise, SHELL_ERR_UNKNOWN_CMD will be
; returned.
;
; See constants below for error codes.
;
; All numerical values in the Collapse OS shell are represented and parsed in
; hexadecimal form, without prefix or suffix.

; *** REQUIREMENTS ***
; err
; core
; parse
; stdio

; *** DEFINES ***
; SHELL_EXTRA_CMD_COUNT: Number of extra cmds to be expected after the regular
;                        ones. See comment in COMMANDS section for details.
; SHELL_RAMSTART

; *** CONSTS ***

; number of entries in shellCmdTbl
.equ	SHELL_CMD_COUNT		6+SHELL_EXTRA_CMD_COUNT

; *** VARIABLES ***
; Memory address that the shell is currently "pointing at" for peek, load, call
; operations. Set with mptr.
.equ	SHELL_MEM_PTR	SHELL_RAMSTART

; Places where we store arguments specifiers and where resulting values are
; written to after parsing.
.equ	SHELL_CMD_ARGS	SHELL_MEM_PTR+2

; Pointer to a hook to call when a cmd name isn't found
.equ	SHELL_CMDHOOK	SHELL_CMD_ARGS+PARSE_ARG_MAXCOUNT

; Pointer to a routine to call at each shell loop interation
.equ	SHELL_LOOPHOOK	SHELL_CMDHOOK+2
.equ	SHELL_RAMEND	SHELL_LOOPHOOK+2

; *** CODE ***
shellInit:
	xor	a
	ld	(SHELL_MEM_PTR), a
	ld	(SHELL_MEM_PTR+1), a
	ld	hl, noop
	ld	(SHELL_CMDHOOK), hl
	ld	(SHELL_LOOPHOOK), hl

	; print welcome
	ld	hl, .welcome
	jp	printstr

.welcome:
	.db	"Collapse OS", ASCII_CR, ASCII_LF, "> ", 0

; Inifite loop that processes input. Because it's infinite, you should jump
; to it rather than call it. Saves two precious bytes in the stack.
shellLoop:
	; First, call the loop hook
	ld	ix, (SHELL_LOOPHOOK)
	call	callIX
	; Then, let's wait until something is typed.
	call	stdioReadC
	jr	nz, shellLoop	; not done? loop
	; We're done. Process line.
	call	printcrlf
	call	stdioGetLine
	call	shellParse
	ld	hl, .prompt
	call	printstr
	jr	shellLoop

.prompt:
	.db	"> ", 0

; Parse command (null terminated) at HL and calls it
shellParse:
	; first thing: is command empty?
	ld	a, (hl)
	or	a
	ret	z	; empty, nthing to do

	push	af
	push	bc
	push	de
	push	hl
	push	ix

	; Before looking for a suitable command, let's make the cmd line more
	; usable by replacing the first ' ' with a null char. This way, cmp is
	; easy to make.
	push	hl		; --> lvl 1
	ld	a, ' '
	call	findchar
	jr	z, .hasArgs
	; no arg, (HL) is zero to facilitate processing later, add a second
	; null next to that one to indicate unambiguously that we have no args.
	inc	hl
.hasArgs:
	xor	a
	ld	(hl), a
	pop	hl		; <-- lvl 1, beginning of cmd

	ld	de, shellCmdTbl
	ld	b, SHELL_CMD_COUNT

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
	; Before erroring out, let's try SHELL_HOOK.
	ld	ix, (SHELL_CMDHOOK)
	call	callIX
	jr	z, .end		; oh, not an error!
	; still an error. Might be different than SHELL_ERR_UNKNOWN_CMD though.
	; maybe a routine was called, but errored out.
	jr	.error

.found:
	; we found our command. DE points to its table entry. Now, let's parse
	; our args.
	call	intoDE		; Jump from the table entry to the cmd addr.

	; advance the HL pointer to the beginning of the args.
	xor	a
	call	findchar
	inc	hl		; beginning of args
	; Now, let's have DE point to the argspecs
	ld	a, 4
	call	addDE

	; We're ready to parse args
	ld	ix, SHELL_CMD_ARGS
	call	parseArgs
	or	a		; cp 0
	jr	nz, .parseerror

	; Args parsed, now we can load the routine address and call it.
	; let's have DE point to the jump line
	ld	hl, SHELL_CMD_ARGS
	ld	a, PARSE_ARG_MAXCOUNT
	call	addDE
	push	de \ pop ix
	; Ready to roll!
	call	callIX
	or	a		; cp 0
	jr	nz, .error	; if A is non-zero, we have an error
	jr	.end

.parseerror:
	ld	a, SHELL_ERR_BAD_ARGS
.error:
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
	call	printHex
	call	printcrlf

	pop	hl
	pop	af
	ret

.str:
	.db	"ERR ", 0

; *** COMMANDS ***
; A command is a 4 char names, followed by a PARSE_ARG_MAXCOUNT bytes of
; argument specs, followed by the routine. Then, a simple table of addresses
; is compiled in a block and this is what is iterated upon when we want all
; available commands.
;
; Format: 4 bytes name followed by PARSE_ARG_MAXCOUNT bytes specifiers,
;         followed by 3 bytes jump. fill names with zeroes
;
; When these commands are called, HL points to the first byte of the
; parsed command args.
;
; If the command is a success, it should set A to zero. If the command results
; in an error, it should set an error code in A.
;
; Extra commands: Other parts might define new commands. You can add these
;                 commands to your shell. First, set SHELL_EXTRA_CMD_COUNT to
;                 the number of extra commands to add, then add a ".dw"
;                 directive *just* after your '.inc "shell.asm"'. Voila!
;

; Set memory pointer to the specified address (word).
; Example: mptr 01fe
shellMptrCmd:
	.db	"mptr", 0b011, 0b001, 0
shellMptr:
	push	hl

	; reminder: z80 is little-endian
	ld	a, (hl)
	ld	(SHELL_MEM_PTR+1), a
	inc	hl
	ld	a, (hl)
	ld	(SHELL_MEM_PTR), a

	ld	hl, (SHELL_MEM_PTR)
	ld	a, h
	call	printHex
	ld	a, l
	call	printHex
	call	printcrlf

	pop	hl
	xor	a
	ret


; peek the number of bytes specified by argument where memory pointer points to
; and display their value. If 0 is specified, 0x100 bytes are peeked.
;
; Example: peek 2 (will print 2 bytes)
shellPeekCmd:
	.db	"peek", 0b001, 0, 0
shellPeek:
	push	bc
	push	hl

	ld	a, (hl)
	ld	b, a
	ld	hl, (SHELL_MEM_PTR)
.loop:	ld	a, (hl)
	call	printHex
	inc	hl
	djnz	.loop
	call	printcrlf

.end:
	pop	hl
	pop	bc
	xor	a
	ret

; poke specified number of bytes where memory pointer points and set them to
; bytes typed through stdioGetC. Blocks until all bytes have been fetched.
shellPokeCmd:
	.db	"poke", 0b001, 0, 0
shellPoke:
	push	bc
	push	hl

	ld	a, (hl)
	ld	b, a
	ld	hl, (SHELL_MEM_PTR)
.loop:	call	stdioGetC
	jr	nz, .loop	; nothing typed? loop
	ld	(hl), a
	inc	hl
	djnz	.loop

	pop	hl
	pop	bc
	xor	a
	ret

; Calls the routine where the memory pointer currently points. This can take two
; parameters, A and HL. The first one is a byte, the second, a word. These are
; the values that A and HL are going to be set to just before calling.
; Example: run 42 cafe
shellCallCmd:
	.db	"call", 0b101, 0b111, 0b001
shellCall:
	push	hl
	push	ix

	; Let's recap here. At this point, we have:
	; 1. The address we want to execute in (SHELL_MEM_PTR)
	; 2. our A arg as the first byte of (HL)
	; 2. our HL arg as (HL+1) and (HL+2)
	; Ready, set, go!
	ld	ix, (SHELL_MEM_PTR)
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
	xor	a
	ret

shellIORDCmd:
	.db	"iord", 0b001, 0, 0
	push	bc
	ld	a, (hl)
	ld	c, a
	in	a, (c)
	call	printHex
	xor	a
	pop	bc
	ret

shellIOWRCmd:
	.db	"iowr", 0b001, 0b001, 0
	push	bc
	ld	a, (hl)
	ld	c, a
	inc	hl
	ld	a, (hl)
	out	(c), a
	xor	a
	pop	bc
	ret

; This table is at the very end of the file on purpose. The idea is to be able
; to graft extra commands easily after an include in the glue file.
shellCmdTbl:
	.dw shellMptrCmd, shellPeekCmd, shellPokeCmd, shellCallCmd
	.dw shellIORDCmd, shellIOWRCmd

