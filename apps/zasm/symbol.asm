; Manages both constants and labels within a same namespace and registry.
;
; About local labels: They are treated as regular labels except they start with
; a dot (example: ".foo"). Because labels are registered in order and because
; constants are registered in the second pass, they end up at the end of the
; symbol list and don't mix with labels. Therefore, we easily iterate through
; local labels of a context by starting from that context's index and iterating
; as long as symbol name start with a '.'

; *** Constants ***
; Duplicate symbol in registry
.equ	SYM_ERR_DUPLICATE	0x01
; Symbol registry buffer is full
.equ	SYM_ERR_FULLBUF		0x02

; Maximum number of symbols we can have in the registry
.equ	SYM_MAXCOUNT	0x100

; Size of the symbol name buffer size. This is a pool. There is no maximum name
; length for a single symbol, just a maximum size for the whole pool.
.equ	SYM_BUFSIZE	0x1000

; *** Variables ***
; Each symbol is mapped to a word value saved here.
.equ	SYM_VALUES	SYM_RAMSTART

; A list of symbol names separated by null characters. When we encounter a
; symbol name and want to get its value, we search the name here, retrieve the
; index of the name, then go get the value at that index in SYM_VALUES.
.equ	SYM_NAMES	SYM_VALUES+(SYM_MAXCOUNT*2)

.equ	SYM_RAMEND	SYM_NAMES+SYM_BUFSIZE

; *** Code ***

; Place HL at the end of SYM_NAMES end (that is, at the point where we have two
; consecutive null chars. We return the index of that new name in A.
; If we're within bounds, Z is set, otherwise unset.
symNamesEnd:
	push	bc
	push	de

	ld	b, 0
	ld	hl, SYM_NAMES
	ld	de, SYM_NAMES+SYM_BUFSIZE
.loop:
	ld	a, (hl)
	or	a		; cp 0
	jr	z, .success	; We've reached the end, Z is set, all good
	xor	a
	call	JUMP_FINDCHAR	; find next null char
	; go to the char after it.
	inc	hl
	; Are we out of bounds?
	call	cpHLDE
	jr	nc, .outOfBounds	; HL >= DE
	djnz	.loop
	; exhausted djnz? out of bounds
.outOfBounds:
	call	JUMP_UNSETZ
	jr	.end
.success:
	; Our index is 0 - B (if B is, for example 0xfd, A is 0x3)
	xor	a
	sub	b
	cp	a		; ensure Z
.end:
	pop	de
	pop	bc
	ret

; Register label in (HL) (minus the ending ":") into the symbol registry and
; set its value in that registry to DE.
; If successful, Z is set and A is the symbol index. Otherwise, Z is unset and
; A is an error code (SYM_ERR_*).
symRegister:
	push	hl
	push	bc
	push	de

	; First, let's get our strlen
	call	strlen
	ld	c, a		; save that strlen for later

	ex	hl, de		; symbol to add is now in DE
	call	symNamesEnd
	jr	nz, .error
	; A is our index. Save it
	ex	af, af'
	; Is our new name going to make us go out of bounds?
	push	hl
	push	de
		ld	de, SYM_NAMES+SYM_BUFSIZE
		ld	a, c
		call	JUMP_ADDHL
		call	cpHLDE
	pop	de
	pop	hl
	jr	nc, .error	; HL >= DE

	; HL point to where we want to add the string
	ex	hl, de		; symbol to add in HL, dest in DE
	; Copy HL into DE until we reach null char
	; C already have our strlen (minus null char). Let's prepare BC for
	; a LDIR.
	inc	c	; include null char
	ld	b, 0
	ldir		; copy C chars from HL to DE

	; I'd say we're pretty good just about now. What we need to do is to
	; save the value in our original DE that is just on top of the stack
	; into the proper index in SYM_VALUES. Our index, remember, is
	; currently in A'.
	ex	af, af'
	pop	de
	push	de	; push it right back to avoid stack imbalance
	ld	hl, SYM_VALUES
	call	JUMP_ADDHL
	call	JUMP_ADDHL	; twice because our values are words

	; Everything is set! DE is our value HL points to the proper index in
	; SYM_VALUES. Let's just write it (little endian).
	ld	(hl), e
	inc	hl
	ld	(hl), d
.error:
	; Z already unset
	pop	de
	pop	bc
	pop	hl
	ret

; Find name (HL) in SYM_NAMES and returns matching index in A.
; If we find something, Z is set, otherwise unset.
symFind:
	push	hl
	push	bc
	push	de

	; First, what's our strlen?
	call	strlen
	ld	c, a		; let's save that

	ex	hl, de		; it's easier if HL is haystack and DE is
				; needle.
	ld	b, 0
	ld	hl, SYM_NAMES
.loop:
	ld	a, (hl)
	or	a		; cp 0
	jr	z, .nomatch
	ld	a, c
	call	JUMP_STRNCMP
	jr	z, .match
	; ok, next!
	xor	a
	call	JUMP_FINDCHAR	; find next null char
	; go to the char after it.
	inc	hl
	djnz	.loop
	; exhausted djnz? no match
.nomatch:
	call	JUMP_UNSETZ
	jr	.end
.match:
	; Our index is 0 - B (if B is, for example 0xfd, A is 0x3)
	xor	a
	sub	b
	cp	a		; ensure Z
.end:
	pop	de
	pop	bc
	pop	hl
	ret

; Return value associated with symbol index A into DE
; Sets Z on success, unset on error.
symGetVal:
	; our index is in A. Let's fetch the proper value
	push	hl
	ld	hl, SYM_VALUES
	call	JUMP_ADDHL
	call	JUMP_ADDHL	; twice because our values are words
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	pop	hl
	cp	a		; ensure Z
	ret
