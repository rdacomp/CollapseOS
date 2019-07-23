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
; Maximum number of symbols we can have in the global and consts registry
.equ	SYM_MAXCOUNT		0x100
; Maximum number of symbols we can have in the local registry
.equ	SYM_LOC_MAXCOUNT	0x40

; Size of the symbol name buffer size. This is a pool. There is no maximum name
; length for a single symbol, just a maximum size for the whole pool.
; Global labels and consts have the same buf size
.equ	SYM_BUFSIZE		0x1000

; Size of the names buffer for the local context registry
.equ	SYM_LOC_BUFSIZE		0x200

; *** Variables ***
; Global labels registry

; Each symbol is mapped to a word value saved here.
.equ	SYM_GLOB_VALUES		SYM_RAMSTART

; A list of symbol names separated by null characters. When we encounter a
; symbol name and want to get its value, we search the name here, retrieve the
; index of the name, then go get the value at that index in SYM_GLOB_VALUES.
.equ	SYM_GLOB_NAMES		SYM_GLOB_VALUES+SYM_MAXCOUNT*2

; Registry for local labels. Wiped out after each context change.
.equ	SYM_LOC_VALUES		SYM_GLOB_NAMES+SYM_BUFSIZE
.equ	SYM_LOC_NAMES		SYM_LOC_VALUES+SYM_LOC_MAXCOUNT*2

; Registry for constants
.equ	SYM_CONST_VALUES	SYM_LOC_NAMES+SYM_LOC_BUFSIZE
.equ	SYM_CONST_NAMES		SYM_CONST_VALUES+SYM_MAXCOUNT*2
.equ	SYM_RAMEND		SYM_CONST_NAMES+SYM_BUFSIZE

; *** Registries ***
; A symbol registry is a 6 bytes record with points to names and values of
; one of the register.
; It's 3 pointers: names, names end, values

SYM_GLOBAL_REGISTRY:
	.dw	SYM_GLOB_NAMES, SYM_GLOB_NAMES+SYM_BUFSIZE, SYM_GLOB_VALUES

SYM_LOCAL_REGISTRY:
	.dw	SYM_LOC_NAMES, SYM_LOC_NAMES+SYM_LOC_BUFSIZE, SYM_LOC_VALUES

SYM_CONST_REGISTRY:
	.dw	SYM_CONST_NAMES, SYM_CONST_NAMES+SYM_BUFSIZE, SYM_CONST_VALUES

; *** Code ***

; Assuming that HL points in to a symbol name list, advance HL to the beginning
; of the next symbol name except if (HL) is already zero, meaning we're at the
; end of the chain. In this case, do nothing.
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
	ld	(SYM_GLOB_NAMES), a
	ld	(SYM_LOC_NAMES), a
	ld	(SYM_CONST_NAMES), a
	; Continue to symSelectGlobalRegistry

; Sets Z according to whether label in (HL) is local (starts with a dot)
symIsLabelLocal:
	ld	a, '.'
	cp	(hl)
	ret

; Given a registry in (IX), place HL at the end of its names that is, at the
; point where we have two consecutive null chars and DE at the corresponding
; position in its values.
; If we're within bounds, Z is set, otherwise unset.
_symNamesEnd:
	push	iy
	push	bc

	; IY --> values
	ld	l, (ix+4)
	ld	h, (ix+5)
	push	hl \ pop iy
	; HL --> names
	ld	l, (ix)
	ld	h, (ix+1)
	; DE --> names end
	ld	e, (ix+2)
	ld	d, (ix+3)
.loop:
	call	_symNext
	jr	nz, .success	; We've reached the end of the chain.
	inc	iy
	inc	iy
	; Are we out of bounds name-wise?
	call	cpHLDE
	jr	nc, .outOfBounds	; HL >= DE
	; are we out of bounds value-wise? check if IY == (IX)'s names
	; Is is assumed that values are placed right before names
	push	hl
	push	iy \ pop bc
	ld	l, (ix)
	ld	h, (ix+1)
	sbc	hl, bc
	pop	hl
	jr	z, .outOfBounds		; IY == (IX)'s names
	jr	.loop
.outOfBounds:
	call	unsetZ
	jr	.end
.success:
	push	iy \ pop de	; our values pos goes in DE
	cp	a		; ensure Z
.end:
	pop	bc
	pop	iy
	ret

symRegisterGlobal:
	push	ix
	ld	ix, SYM_GLOBAL_REGISTRY
	call	symRegister
	pop	ix
	ret

symRegisterLocal:
	push	ix
	ld	ix, SYM_LOCAL_REGISTRY
	call	symRegister
	pop	ix
	ret

symRegisterConst:
	push	ix
	ld	ix, SYM_CONST_REGISTRY
	call	symRegister
	pop	ix
	ret

; Register label in (HL) (minus the ending ":") into the symbol registry and
; set its value in that registry to DE.
; If successful, Z is set and A is the symbol index. Otherwise, Z is unset and
; A is an error code (ERR_*).
symRegister:
	push	hl	; --> lvl 1. it's the symbol to add
	push	de	; --> lvl 2. it's our value.

	call	_symFind
	jr	z, .duplicateError


	; First, let's get our strlen
	call	strlen
	ld	c, a		; save that strlen for later

	call	_symNamesEnd
	jr	nz, .outOfMemory

	; Is our new name going to make us go out of bounds?
	push	hl		; --> lvl 3
	push	de		; --> lvl 4
	ld	e, (ix+2)
	ld	d, (ix+3)
	; DE --> names end
	ld	a, c
	call	addHL
	call	cpHLDE
	pop	de		; <-- lvl 4
	pop	hl		; <-- lvl 3
	jr	nc, .outOfMemory	; HL >= DE

	; Success. At this point, we have:
	; HL -> where we want to add the string
	; DE -> where the value goes
	; SP -> value to register
	; SP+2 -> string to register

	; Let's start with the value.
	push	hl \ pop ix	; save HL for later
	pop	hl		; <-- lvl 2. value to register
	call	writeHLinDE	; write value where it goes.

	; Good! now, the string.
	pop	hl		; <-- lvl 1. string to register
	push	ix \ pop de	; string destination
	; Copy HL into DE until we reach null char
	call	strcpyM

	; We need to add a second null char to indicate the end of the name
	; list. DE is already correctly placed, A is already zero
	ld	(de), a

	cp	a		; ensure Z
	ret

.outOfMemory:
	ld	a, ERR_OOM
	call	unsetZ
	pop	de		; <-- lvl 2
	pop	hl		; <-- lvl 1
	ret

.duplicateError:
	pop	de		; <-- lvl 2
	pop	hl		; <-- lvl 1
	ld	a, ERR_DUPSYM
	jp	unsetZ		; return

; Assuming that IX points to a registry, find name HL in its names and make DE
; point to the corresponding entry in its values.
; If we find something, Z is set, otherwise unset.
_symFind:
	push	iy
	push	hl

	ex	de, hl		; it's easier if HL is haystack and DE is
				; needle.
	; IY --> values
	ld	l, (ix+4)
	ld	h, (ix+5)
	push	hl \ pop iy
	; HL --> names
	ld	l, (ix)
	ld	h, (ix+1)
.loop:
	call	strcmp
	jr	z, .match
	; ok, next!
	call	_symNext
	jr	nz, .nomatch	; end of the chain, nothing found
	inc	iy
	inc	iy
	jr	.loop
.nomatch:
	call	unsetZ
	jr	.end
.match:
	push	iy \ pop de
	; DE has our result
	cp	a		; ensure Z
.end:
	pop	hl
	pop	iy
	ret

; For a given symbol name in (HL), find it in the appropriate symbol register
; and return its value in DE. If (HL) is a local label, the local register is
; searched. Otherwise, the global one. It is assumed that this routine is
; always called when the global registry is selected. Therefore, we always
; reselect it afterwards.
symFindVal:
	push	ix
	call	symIsLabelLocal
	jr	z, .local
	; global. Let's try labels first, then consts
	ld	ix, SYM_GLOBAL_REGISTRY
	call	_symFind
	jr	z, .found
	ld	ix, SYM_CONST_REGISTRY
	call	_symFind
	jr	nz, .end
.found:
	; Found! let's fetch value
	; DE is pointing to our result
	call	intoDE
	jr	.end
.local:
	ld	ix, SYM_LOCAL_REGISTRY
	call	_symFind
	jr	z, .found
	; continue to end
.end:
	pop	ix
	ret

; Clear registry at IX
symClear:
	push	af
	push	hl
	ld	l, (ix)
	ld	h, (ix+1)
	xor	a
	ld	(hl), a
	pop	hl
	pop	af
	ret
