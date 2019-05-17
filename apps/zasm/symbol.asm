; Manages both constants and labels within a same namespace and registry.
;
; Local Labels
;
; Local labels during the "official" first pass are ignored. To register them
; in the global registry during that pass would be wasteful in terms of memory.
;
; What we don instead is set up a separate register for them and have a "second
; first pass" whenever we encounter a new context. That is, we wipe the local
; registry, parse the code until the next global symbol (or EOF), then rewind
; and continue second pass as usual.

; *** Constants ***
; Duplicate symbol in registry
.equ	SYM_ERR_DUPLICATE	0x01
; Symbol registry buffer is full
.equ	SYM_ERR_FULLBUF		0x02

; Maximum number of symbols we can have in the registry
.equ	SYM_MAXCOUNT		0x100

; Size of the symbol name buffer size. This is a pool. There is no maximum name
; length for a single symbol, just a maximum size for the whole pool.
.equ	SYM_BUFSIZE		0x1000

; Size of the names buffer for the local context registry
.equ	SYM_LOC_BUFSIZE		0x200

; *** Variables ***
; Each symbol is mapped to a word value saved here.
.equ	SYM_VALUES		SYM_RAMSTART

; A list of symbol names separated by null characters. When we encounter a
; symbol name and want to get its value, we search the name here, retrieve the
; index of the name, then go get the value at that index in SYM_VALUES.
.equ	SYM_NAMES		SYM_VALUES+(SYM_MAXCOUNT*2)

; Registry for local labels. Wiped out after each context change.
.equ	SYM_LOC_VALUES		SYM_NAMES+SYM_BUFSIZE
.equ	SYM_LOC_NAMES		SYM_LOC_VALUES+(SYM_MAXCOUNT*2)

; Pointer to the currently selected registry
.equ	SYM_CTX_NAMES		SYM_LOC_NAMES+SYM_LOC_BUFSIZE
.equ	SYM_CTX_NAMESEND	SYM_CTX_NAMES+2
.equ	SYM_CTX_VALUES		SYM_CTX_NAMESEND+2

.equ	SYM_RAMEND		SYM_CTX_VALUES+2

; *** Code ***

; Advance HL to the beginning of the next symbol name in SYM_NAMES except if
; (HL) is already zero, meaning we're at the end of the chain. In this case,
; do nothing.
; Sets Z if it succeeded, unset it if there is no next.
_symNext:
	xor	a
	cp	(hl)
	jr	nz, .do		; (HL) is not zero? we can advance.
	; (HL) is zero? we're at the end of the chain.
	call	unsetZ
	ret
.do:
	; A is already 0
	call	findchar	; find next null char
	; go to the char after it.
	inc	hl
	cp	a		; ensure Z
	ret

symInit:
	xor	a
	ld	(SYM_NAMES), a
	ld	(SYM_LOC_NAMES), a
	; Continue to symSelectGlobalRegistry

symSelectGlobalRegistry:
	push	af
	push	hl
	ld	hl, SYM_NAMES
	ld	(SYM_CTX_NAMES), hl
	ld	hl, SYM_NAMES+SYM_BUFSIZE
	ld	(SYM_CTX_NAMESEND), hl
	ld	hl, SYM_VALUES
	ld	(SYM_CTX_VALUES), hl
	pop	hl
	pop	af
	ret

symSelectLocalRegistry:
	push	af
	push	hl
	ld	hl, SYM_LOC_NAMES
	ld	(SYM_CTX_NAMES), hl
	ld	hl, SYM_LOC_NAMES+SYM_LOC_BUFSIZE
	ld	(SYM_CTX_NAMESEND), hl
	ld	hl, SYM_LOC_VALUES
	ld	(SYM_CTX_VALUES), hl
	ld	a, h
	ld	a, l
	pop	hl
	pop	af
	ret

; Sets Z according to whether label in (HL) is local (starts with a dot)
symIsLabelLocal:
	ld	a, '.'
	cp	(hl)
	ret

; Place HL at the end of (SYM_CTX_NAMES) end (that is, at the point where we have two
; consecutive null chars. We return the index of that new name in A.
; If we're within bounds, Z is set, otherwise unset.
symNamesEnd:
	push	bc
	push	de

	ld	b, 0
	ld	hl, (SYM_CTX_NAMES)
	ld	de, (SYM_CTX_NAMESEND)
.loop:
	call	_symNext
	jr	nz, .success	; We've reached the end of the chain.
	; Are we out of bounds?
	call	cpHLDE
	jr	nc, .outOfBounds	; HL >= DE
	djnz	.loop
	; exhausted djnz? out of bounds
.outOfBounds:
	call	unsetZ
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
		ld	de, (SYM_CTX_NAMESEND)
		ld	a, c
		call	addHL
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

	; We need to add a second null char to indicate the end of the name
	; list. DE is already correctly placed.
	xor	a
	ld	(de), a

	; I'd say we're pretty good just about now. What we need to do is to
	; save the value in our original DE that is just on top of the stack
	; into the proper index in (SYM_CTX_VALUES). Our index, remember, is
	; currently in A'.
	ex	af, af'
	pop	de
	push	de	; push it right back to avoid stack imbalance
	ld	hl, (SYM_CTX_VALUES)
	call	addHL
	call	addHL	; twice because our values are words

	; Everything is set! DE is our value HL points to the proper index in
	; (SYM_CTX_VALUES). Let's just write it (little endian).
	ld	(hl), e
	inc	hl
	ld	(hl), d
.error:
	; Z already unset
	pop	de
	pop	bc
	pop	hl
	ret

; Select global or local registry according to label name in (HL)
symSelect:
	call	symIsLabelLocal
	jp	z, symSelectLocalRegistry
	jp	symSelectGlobalRegistry

; Find name (HL) in (SYM_CTX_NAMES) and returns matching index in A.
; If we find something, Z is set, otherwise unset.
symFind:
	push	hl
	push	bc
	push	de

	ex	hl, de		; it's easier if HL is haystack and DE is
				; needle.
	ld	b, 0
	ld	hl, (SYM_CTX_NAMES)
.loop:
	call	strcmp
	jr	z, .match
	; ok, next!
	call	_symNext
	jr	nz, .nomatch	; end of the chain, nothing found
	djnz	.loop
	; exhausted djnz? no match
.nomatch:
	call	unsetZ
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
symGetVal:
	; our index is in A. Let's fetch the proper value
	push	hl
	ld	hl, (SYM_CTX_VALUES)
	call	addHL
	call	addHL	; twice because our values are words
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	pop	hl
	ret
