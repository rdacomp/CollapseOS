; *** Consts ***
TOK_INSTR	.equ	0x01
TOK_DIRECTIVE	.equ	0x02
TOK_LABEL	.equ	0x03
TOK_EOF		.equ	0xfe	; end of file
TOK_BAD		.equ	0xff

.equ	SCRATCHPAD_SIZE	0x40
; *** Variables ***
scratchpad:
	.fill	SCRATCHPAD_SIZE

; *** Code ***

; Sets Z is A is ';' or null.
isLineEndOrComment:
	cp	';'
	ret	z
	; continue to isLineEnd

; Sets Z is A is CR, LF, or null.
isLineEnd:
	or	a	; same as cp 0
	ret	z
	cp	0x0d
	ret	z
	cp	0x0a
	ret	z
	cp	'\'
	ret

; Sets Z is A is ' ' '\t' or ','
isSep:
	cp	' '
	ret	z
	cp	0x09
	ret

; Sets Z is A is ' ', ',', ';', CR, LF, or null.
isSepOrLineEnd:
	call	isSep
	ret	z
	jr	isLineEndOrComment

; Checks whether string at (HL) is a label, that is, whether it ends with a ":"
; Sets Z if yes, unset if no.
;
; If it's a label, we change the trailing ':' char with a null char. It's a bit
; dirty, but it's the easiest way to proceed.
isLabel:
	push	hl
	ld	a, ':'
	call	findchar
	ld	a, (hl)
	cp	':'
	jr	nz, .nomatch
	; We also have to check that it's our last char.
	inc	hl
	ld	a, (hl)
	or	a		; cp 0
	jr	nz, .nomatch	; not a null char following the :. no match.
	; We have a match!
	; Remove trailing ':'
	xor	a		; Z is set
	dec	hl
	ld	(hl), a
	jr	.end
.nomatch:
	call	unsetZ
.end:
	pop	hl
	ret

; Read ioGetC until a word starts, then read ioGetC as long as there is no
; separator and put that contents in (scratchpad), null terminated, for a
; maximum of SCRATCHPAD_SIZE-1 characters.
; If EOL (\n, \r or comment) or EOF is hit before we could read a word, we stop
; right there. If scratchpad is not big enough, we stop right there and error.
; HL points to scratchpad
; Sets Z if a word could be read, unsets if not.
readWord:
	push	bc
	; Get to word
.loop1:
	call	ioGetC
	call	isLineEndOrComment
	jr	z, .error
	call	isSep
	jr	nz, .read
	jr	.loop1
.read:
	ld	hl, scratchpad
	ld	b, SCRATCHPAD_SIZE-1
	; A contains the first letter to read
	; Let's first check if we open with a quote. If we do, let's have the
	; special quote treatment.
	cp	'"'
	jr	z, .insideQuote
.loop2:
	ld	(hl), a
	inc	hl
	call	ioGetC
	call	isSepOrLineEnd
	jr	z, .success
	cp	','
	jr	z, .success
	djnz	.loop2
	; out of space. error.
.error:
	; We need to put the last char we've read back so that gotoNextLine
	; behaves properly.
	call	ioPutBack
	call	unsetZ
	jr	.end
.success:
	call	ioPutBack
	; null-terminate scratchpad
	xor	a
	ld	(hl), a
	ld	hl, scratchpad
.end:
	pop	bc
	ret
.insideQuote:
	; inside quotes, we accept literal whitespaces, but not line ends.
	ld	(hl), a
	inc	hl
	call	ioGetC
	cp	'"'
	jr	z, .loop2	; ending the quote ends the word
	call	isLineEnd
	jr	z, .error	; ending the line without closing the quote,
				; nope.
	djnz	.insideQuote
	; out of space. error.
	jr	.error

; Reads the next char in I/O. If it's a comma, Set Z and return. If it's not,
; Put the read char back in I/O and unset Z.
readComma:
	call	ioGetC
	cp	','
	ret	z
	call	ioPutBack
	call	unsetZ
	ret

; Read ioGetC until we reach the beginning of next line, skipping comments if
; necessary. This skips all whitespace, \n, \r, comments until we reach the
; first non-comment character. Then, we put it back (ioPutBack) and return.
;
; If gotoNextLine encounters anything else than whitespace, comment or line
; separator, we error out (no putback)

; Sets Z if we reached a new line. Unset if EOF or error.
gotoNextLine:
.loop1:
	; first loop is "strict", that is: we error out on non-whitespace.
	call	ioGetC
	call	isSepOrLineEnd
	ret	nz		; error
	or	a		; cp 0
	jr	z, .eof
	call	isLineEnd
	jr	z, .loop3	; good!
	cp	';'
	jr	z, .loop2	; comment starting, go to "fast lane"
	jr	.loop1
.loop2:
	; second loop is the "comment loop": anything is valid and we just run
	; until EOL.
	call	ioGetC
	or	a		; cp 0
	jr	z, .eof
	cp	'\'		; special case: '\' doesn't count as a line end
				; in a comment.
	jr	z, .loop2
	call	isLineEnd
	jr	z, .loop3
	jr	.loop2
.loop3:
	; Loop 3 happens after we reach our first line sep. This means that we
	; wade through whitespace until we reach a non-whitespace character.
	call	ioGetC
	or	a		; cp 0
	jr	z, .eof
	cp	';'
	jr	z, .loop2	; oh, another comment! go back to loop2!
	call	isSepOrLineEnd
	jr	z, .loop3
	; Non-whitespace. That's our goal! Put it back
	call	ioPutBack
.eof:
	cp	a		; ensure Z
	ret

; Parse line in (HL) and read the next token in BC. The token is written on
; two bytes (B and C). B is a token type (TOK_* constants) and C is an ID
; specific to that token type.
; Advance HL to after the read word.
; If no token matches, TOK_BAD is written to B
tokenize:
	call	readWord
	jr	z, .process	; read successful, process into token.
	; Error. It could be EOL, EOF or scraptchpad size problem
	; Whatever it is, calling gotoNextLine is appropriate. If it's EOL
	; that's obviously what we want to do. If it's EOF, we can check
	; it after. If it's a scratchpad overrun, gotoNextLine handles it.
	call	gotoNextLine
	jr	nz, .error
	or	a		; Are we EOF?
	jr	nz, tokenize	; not EOF? then continue!
	; We're EOF
	ld	b, TOK_EOF
	ret
.process:
	call	isLabel
	jr	z, .label
	call	getInstID
	jr	z, .instr
	call	getDirectiveID
	jr	z, .direc
.error:
	; no match
	ld	b, TOK_BAD
	jr	.end
.instr:
	ld	b, TOK_INSTR
	jr	.end
.direc:
	ld	b, TOK_DIRECTIVE
	jr	.end
.label:
	ld	b, TOK_LABEL
.end:
	ld	c, a
	ret
