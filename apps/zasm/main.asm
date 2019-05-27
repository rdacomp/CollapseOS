; *** Variables ***

; A bool flag indicating that we're on first pass. When we are, we don't care
; about actual output, but only about the length of each upcode. This means
; that when we parse instructions and directive that error out because of a
; missing symbol, we don't error out and just write down a dummy value.
.equ	ZASM_FIRST_PASS		ZASM_RAMSTART
; whether we're in "local pass", that is, in local label scanning mode. During
; this special pass, ZASM_FIRST_PASS will also be set so that the rest of the
; code behaves as is we were in the first pass.
.equ	ZASM_LOCAL_PASS		ZASM_FIRST_PASS+1
; What IO_PC was when we started our context
.equ	ZASM_CTX_PC		ZASM_LOCAL_PASS+1
; current ".org" offset, that is, what we must offset all our label by.
.equ	ZASM_ORG		ZASM_CTX_PC+2
.equ	ZASM_RAMEND		ZASM_ORG+2

; Read file through blockdev ID in H and outputs its upcodes through blockdev
; ID in L.
zasmMain:
	; Init I/O
	ld	a, h
	ld	de, IO_IN_GETC
	call	blkSel
	ld	a, l
	ld	de, IO_OUT_GETC
	call	blkSel

	; Init modules
	xor	a
	ld	(ZASM_LOCAL_PASS), a
	ld	(ZASM_ORG), a
	ld	(ZASM_ORG+1), a
	call	ioInit
	call	symInit

	; First pass
	ld	a, 1
	ld	(ZASM_FIRST_PASS), a
	call	zasmParseFile
	ret	nz
	; Second pass
	call	ioRewind
	xor	a
	ld	(ZASM_FIRST_PASS), a
	call	zasmParseFile
	ret

; Sets Z according to whether we're in first pass.
zasmIsFirstPass:
	ld	a, (ZASM_FIRST_PASS)
	cp	1
	ret

; Sets Z according to whether we're in local pass.
zasmIsLocalPass:
	ld	a, (ZASM_LOCAL_PASS)
	cp	1
	ret

; Set ZASM_ORG to specified number in HL
zasmSetOrg:
	ld	(ZASM_ORG), hl
	ret

; Return current PC (properly .org offsetted) in HL
zasmGetPC:
	push	de
	ld	hl, (ZASM_ORG)
	ld	de, (IO_PC)
	add	hl, de
	pop	de
	ret

; Repeatedly reads lines from IO, assemble them and spit the binary code in
; IO. Z is set on success, unset on error. DE contains the last line number to
; be read (first line is 1).
zasmParseFile:
	call	ioResetPC
.loop:
	call	parseLine
	ret	nz		; error
	ld	a, b		; TOK_*
	cp	TOK_EOF
	jr	z, .eof
	jr	.loop
.eof:
	call	zasmIsLocalPass
	jr	nz, .end	; EOF and not local pass
	; we're in local pass and EOF. Unwind this
	call	_endLocalPass
	jr	.loop
.end:
	cp	a		; ensure Z
	ret

; Parse next token and accompanying args (when relevant) in I/O, write the
; resulting opcode(s) through ioPutC and increases (IO_PC) by the number of
; bytes written. BC is set to the result of the call to tokenize.
; Sets Z if parse was successful, unset if there was an error. EOF is not an
; error. If there is an error, A is set to the corresponding error code (ERR_*).
parseLine:
	call	tokenize
	ld	a, b		; TOK_*
	cp	TOK_INSTR
	jp	z, _parseInstr
	cp	TOK_DIRECTIVE
	jp	z, _parseDirec
	cp	TOK_LABEL
	jr	z, _parseLabel
	cp	TOK_EOF
	ret	z		; We're finished, no error.
	; Bad token
	ld	a, ERR_UNKNOWN
	jp	unsetZ		; return with Z unset

_parseInstr:
	ld	a, c		; I_*
	jp	parseInstruction

_parseDirec:
	ld	a, c		; D_*
	call	parseDirective
	ret

_parseLabel:
	; The string in (scratchpad) is a label with its trailing ':' removed.
	ld	hl, scratchpad

	call	zasmIsLocalPass
	jr	z, .processLocalPass

	; Is this a local label? If yes, we don't process it in the context of
	; parseLine, whether it's first or second pass. Local labels are only
	; parsed during the Local Pass
	call	symIsLabelLocal
	jr	z, .success		; local? don't do anything.

	call	zasmIsFirstPass
	jr	z, .registerLabel	; When we encounter a label in the first
					; pass, we register it in the symbol
					; list
	; At this point, we're in second pass, we've encountered a global label
	; and we'll soon continue processing our file. However, before we do
	; that, we should process our local labels.
	call	_beginLocalPass
	jr	.success
.processLocalPass:
	call	symIsLabelLocal
	jr	z, .registerLabel	; local label? all good, register it
					; normally
	; not a local label? Then we need to end local pass
	call	_endLocalPass
	jr	.success
.registerLabel:
	push	hl
	call	zasmGetPC
	ex	de, hl
	pop	hl
	call	symRegister
	jr	nz, .error
	; continue to .success
.success:
	xor	a		; ensure Z
	ret
.error:
	call	unsetZ
	ret

_beginLocalPass:
	; remember were I/O was
	call	ioSavePos
	; Remember where PC was
	ld	hl, (IO_PC)
	ld	(ZASM_CTX_PC), hl
	; Fake first pass
	ld	a, 1
	ld	(ZASM_FIRST_PASS), a
	; Set local pass
	ld	(ZASM_LOCAL_PASS), a
	; Empty local label registry
	xor	a
	ld	(SYM_LOC_NAMES), a
	call	symSelectLocalRegistry
	ret


_endLocalPass:
	call	symSelectGlobalRegistry
	; recall I/O pos
	call	ioRecallPos
	; recall PC
	ld	hl, (ZASM_CTX_PC)
	ld	(IO_PC), hl
	; unfake first pass
	xor	a
	ld	(ZASM_FIRST_PASS), a
	; Unset local pass
	ld	(ZASM_LOCAL_PASS), a
	cp	a		; ensure Z
	ret
