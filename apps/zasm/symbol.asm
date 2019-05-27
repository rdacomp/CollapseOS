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
; Maximum number of symbols we can have in the global registry
.equ	SYM_MAXCOUNT		0x200
; Maximum number of symbols we can have in the local registry
.equ	SYM_LOC_MAXCOUNT	0x40

; Size of the symbol name buffer size. This is a pool. There is no maximum name
; length for a single symbol, just a maximum size for the whole pool.
.equ	SYM_BUFSIZE		0x2000

; Size of the names buffer for the local context registry
.equ	SYM_LOC_BUFSIZE		0x200

; *** Variables ***
; Each symbol is mapped to a word value saved here.
.equ	SYM_VALUES		SYM_RAMSTART

; A list of symbol names separated by null characters. When we encounter a
; symbol name and want to get its value, we search the name here, retrieve the
; index of the name, then go get the value at that index in SYM_VALUES.
.equ	SYM_NAMES		SYM_VALUES+SYM_MAXCOUNT*2

; Registry for local labels. Wiped out after each context change.
.equ	SYM_LOC_VALUES		SYM_NAMES+SYM_BUFSIZE
.equ	SYM_LOC_NAMES		SYM_LOC_VALUES+SYM_LOC_MAXCOUNT*2

; Pointer to the currently selected registry
.equ	SYM_CTX_NAMES		SYM_LOC_NAMES+SYM_LOC_BUFSIZE
.equ	SYM_CTX_NAMESEND	SYM_CTX_NAMES+2
.equ	SYM_CTX_VALUES		SYM_CTX_NAMESEND+2
; Pointer, in (SYM_CTX_VALUES), to the result of the last symFind
.equ	SYM_CTX_PTR		SYM_CTX_VALUES+2

.equ	SYM_RAMEND		SYM_CTX_PTR+2

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

; Place HL at the end of (SYM_CTX_NAMES) end (that is, at the point where we
; have two consecutive null chars and DE at the corresponding position in
; SYM_CTX_VALUES).
; If we're within bounds, Z is set, otherwise unset.
symNamesEnd:
	push	ix
	push	bc

	ld	ix, (SYM_CTX_VALUES)
	ld	hl, (SYM_CTX_NAMES)
	ld	de, (SYM_CTX_NAMESEND)
.loop:
	call	_symNext
	jr	nz, .success	; We've reached the end of the chain.
	inc	ix
	inc	ix
	; Are we out of bounds name-wise?
	call	cpHLDE
	jr	nc, .outOfBounds	; HL >= DE
	; are we out of bounds value-wise? check if IX == (SYM_CTX_NAMES)
	; Is is assumed that values are placed right before names
	push	hl
	push	ix \ pop bc
	ld	hl, (SYM_CTX_NAMES)
	sbc	hl, bc
	pop	hl
	jr	z, .outOfBounds		; IX == (SYM_CTX_NAMES)
	jr	.loop
.outOfBounds:
	call	unsetZ
	jr	.end
.success:
	push	ix \ pop de	; our values pos goes in DE
	cp	a		; ensure Z
.end:
	pop	bc
	pop	ix
	ret

; Register label in (HL) (minus the ending ":") into the symbol registry and
; set its value in that registry to DE.
; If successful, Z is set and A is the symbol index. Otherwise, Z is unset and
; A is an error code (ERR_*).
symRegister:
	call	symFind
	jr	z, .alreadyThere

	push	hl	; will be used during processing. it's the symbol to add
	push	de	; will be used during processing. it's our value.


	; First, let's get our strlen
	call	strlen
	ld	c, a		; save that strlen for later

	call	symNamesEnd
	jr	nz, .outOfMemory

	; Is our new name going to make us go out of bounds?
	push	hl
	push	de
		ld	de, (SYM_CTX_NAMESEND)
		ld	a, c
		call	addHL
		call	cpHLDE
	pop	de
	pop	hl
	jr	nc, .outOfMemory	; HL >= DE

	; Success. At this point, we have:
	; HL -> where we want to add the string
	; DE -> where the value goes
	; SP -> value to register
	; SP+2 -> string to register

	; Let's start with the value.
	push	hl \ pop ix	; save HL for later
	pop	hl		; value to register
	call	writeHLinDE	; write value where it goes.

	; Good! now, the string.
	pop	hl		; string to register
	push	ix \ pop de	; string destination
	; Copy HL into DE until we reach null char
	call	strcpyM

	; We need to add a second null char to indicate the end of the name
	; list. DE is already correctly placed, A is already zero
	ld	(de), a

	cp	a		; ensure Z
	; Nothing to pop. We've already popped our stack in the lines above.
	ret

.outOfMemory:
	ld	a, ERR_OOM
	call	unsetZ
	pop	de
	pop	hl
	ret

.alreadyThere:
	; We are in a tricky situation with regards to our handling of the
	; duplicate symbol error. Normally, it should be straightforward: We
	; only register labels during first pass and evaluate constants during
	; the second. Easy.
	; We can *almost* do that... but we have ".org". .org affects label
	; values and supports expressions, which means that we have to evaluate
	; constants during first pass. But because we can possibly have forward
	; references in ".equ", some constants are going to have a bad value.
	; Therefore, we really can't evaluate all constants during the first
	; pass.
	; With this situation, how do you manage detection of duplicate symbols?
	; By limiting the "duplicate error" condition to the first pass. During,
	; first pass, sure, we don't have our proper values, but we have all our
	; symbol names. So, if we end up in .alreadyThere during first pass,
	; then it's an error condition. If it's not first pass, then we need
	; to update our value.
	call	zasmIsFirstPass
	jr	z, .duplicateError
	; Second pass. Don't error out, just update value
	push	hl
	ld	hl, (SYM_CTX_PTR)
	ex	de, hl
	call	writeHLinDE
	pop	hl
	cp	a		; ensure Z
	ret
.duplicateError:
	ld	a, ERR_DUPSYM
	jp	unsetZ		; return

; Select global or local registry according to label name in (HL)
symSelect:
	call	symIsLabelLocal
	jp	z, symSelectLocalRegistry
	jp	symSelectGlobalRegistry

; Find name (HL) in (SYM_CTX_NAMES) and make (SYM_CTX_PTR) point to the
; corresponding entry in (SYM_CTX_VALUES).
; If we find something, Z is set, otherwise unset.
symFind:
	push	ix
	push	hl
	push	de

	ex	de, hl		; it's easier if HL is haystack and DE is
				; needle.
	ld	ix, (SYM_CTX_VALUES)
	ld	hl, (SYM_CTX_NAMES)
.loop:
	call	strcmp
	jr	z, .match
	; ok, next!
	call	_symNext
	jr	nz, .nomatch	; end of the chain, nothing found
	inc	ix
	inc	ix
	jr	.loop
.nomatch:
	call	unsetZ
	jr	.end
.match:
	ld	(SYM_CTX_PTR), ix
	cp	a		; ensure Z
.end:
	pop	de
	pop	hl
	pop	ix
	ret

; Return value that (SYM_CTX_PTR) is pointing at in DE.
symGetVal:
	ld	de, (SYM_CTX_PTR)
	jp	intoDE
