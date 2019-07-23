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
.equ	SYM_MAXCOUNT		0xff
; Maximum number of symbols we can have in the local registry
.equ	SYM_LOC_MAXCOUNT	0x40
; Size of each record in registry
.equ	SYM_RECSIZE		3

; Size of the symbol name buffer size. This is a pool. There is no maximum name
; length for a single symbol, just a maximum size for the whole pool.
; Global labels and consts have the same buf size
.equ	SYM_BUFSIZE		0x1000
.equ	SYM_REGSIZE		SYM_BUFSIZE+1+SYM_MAXCOUNT*SYM_RECSIZE

; Size of the names buffer for the local context registry
.equ	SYM_LOC_BUFSIZE		0x200
.equ	SYM_LOC_REGSIZE		SYM_LOC_BUFSIZE+1+SYM_LOC_MAXCOUNT*SYM_RECSIZE

; *** Variables ***
; A registry has three parts: record count (byte) record list and names pool.
; A record is a 3 bytes structure:
; 1b - name length
; 2b - value associated to symbol
;
; We know we're at the end of the record list when we hit a 0-length one.
;
; The names pool is a list of strings, not null-terminated, associated with
; the value.
;
; It is assumed that the registry is aligned in memory in that order:
; names pool, rec count, reclist

; Global labels registry
.equ	SYM_GLOB_REG		SYM_RAMSTART
.equ	SYM_LOC_REG		SYM_GLOB_REG+SYM_REGSIZE
.equ	SYM_CONST_REG		SYM_LOC_REG+SYM_LOC_REGSIZE
.equ	SYM_RAMEND		SYM_CONST_REG+SYM_REGSIZE

; *** Registries ***
; A symbol registry is a 5 bytes record with points to the name pool then the
; records list of the register and then the max record count.

SYM_GLOBAL_REGISTRY:
	.dw	SYM_GLOB_REG, SYM_GLOB_REG+SYM_BUFSIZE
	.db	SYM_MAXCOUNT

SYM_LOCAL_REGISTRY:
	.dw	SYM_LOC_REG, SYM_LOC_REG+SYM_LOC_BUFSIZE
	.db	SYM_LOC_MAXCOUNT

SYM_CONST_REGISTRY:
	.dw	SYM_CONST_REG, SYM_CONST_REG+SYM_BUFSIZE
	.db	SYM_MAXCOUNT

; *** Code ***

symInit:
	ld	ix, SYM_GLOBAL_REGISTRY
	call	symClear
	ld	ix, SYM_LOCAL_REGISTRY
	call	symClear
	ld	ix, SYM_CONST_REGISTRY
	jp	symClear

; Sets Z according to whether label in (HL) is local (starts with a dot)
symIsLabelLocal:
	ld	a, '.'
	cp	(hl)
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

; Register label in (HL) (minus the ending ":") into the symbol registry in IX
; and set its value in that registry to the value specified in DE.
; If successful, Z is set. Otherwise, Z is unset and A is an error code (ERR_*).
symRegister:
	push	hl	; --> lvl 1. it's the symbol to add

	call	_symIsFull
	jr	z, .outOfMemory

	; First, let's get our strlen
	call	strlen
	ld	c, a		; save that strlen for later

	call	_symFind
	jr	z, .duplicateError

	; Is our new name going to make us go out of bounds?
	push	hl		; --> lvl 2
	push	de		; --> lvl 3
	ld	e, (ix+2)	; DE --> pointer to record list, which is also
	ld	d, (ix+3)	; the end of names pool
	; DE --> names end
	ld	a, c
	call	addHL
	call	cpHLDE
	pop	de		; <-- lvl 3
	pop	hl		; <-- lvl 2
	jr	nc, .outOfMemory	; HL >= DE

	; Success. At this point, we have:
	; HL -> where we want to add the string
	; IY -> target record where the value goes
	; DE -> value to register
	; SP -> string to register

	; Let's start with the record
	ld	(iy), c		; strlen
	ld	(iy+1), e
	ld	(iy+2), d

	; Good! now, the string. Destination is in HL, source is in SP
	ex	de, hl		; dest is in DE
	pop	hl		; <-- lvl 1. string to register
	; Copy HL into DE until we reach null char
	call	strcpyM

	; Last thing: increase record count
	ld	l, (ix+2)
	ld	h, (ix+3)
	inc	(hl)
	xor	a		; sets Z
	ret

.outOfMemory:
	pop	hl		; <-- lvl 1
	ld	a, ERR_OOM
	jp	unsetZ

.duplicateError:
	pop	hl		; <-- lvl 1
	ld	a, ERR_DUPSYM
	jp	unsetZ		; return

; Assuming that IX points to a registry, find name HL in its names and make IY
; point to the corresponding record. If it doesn't find anything, IY will
; conveniently point to the next record after the last, and HL to the next
; name insertion point.
; If we find something, Z is set, otherwise unset.
_symFind:
	push	de
	push	bc

	call	strlen
	ld	c, a		; save strlen

	ex	de, hl		; easier if needle is in DE

	; IY --> records
	ld	l, (ix+2)
	ld	h, (ix+3)
	; first byte is count
	ld	b, (hl)
	inc	hl		; first record
	push	hl \ pop iy
	; HL --> names
	ld	l, (ix)
	ld	h, (ix+1)
	; do we have an empty reclist?
	xor	a
	cp	b
	jr	z, .nothing	; zero count? nothing
.loop:
	ld	a, (iy)		; name len
	cp	c
	jr	nz, .skip	; different strlen, can't possibly match. skip
	call	strncmp
	jr	z, .end		; match! Z already set, IY and HL placed.
.skip:
	; ok, next!
	ld	a, (iy)		; name len again
	call	addHL		; advance HL by A chars
	inc	iy \ inc iy \ inc iy
	djnz	.loop
	; end of the chain, nothing found
.nothing:
	call	unsetZ
.end:
	pop	bc
	pop	de
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
	push	hl		; --> lvl 1. we'll need it again if not found.
	ld	ix, SYM_GLOBAL_REGISTRY
	call	_symFind
	pop	hl		; <-- lvl 1
	jr	z, .found
	ld	ix, SYM_CONST_REGISTRY
	call	_symFind
	jr	nz, .end
.found:
	; Found! let's fetch value
	ld	e, (iy+1)
	ld	d, (iy+2)
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
	ld	l, (ix+2)
	ld	h, (ix+3)
	; HL --> reclist count
	xor	a
	ld	(hl), a
	pop	hl
	pop	af
	ret

; Returns whether register in IX has reached its capacity.
; Sets Z if full, unset if not.
_symIsFull:
	push	hl
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	l, (hl)		; record count
	ld	a, (ix+4)	; max record count
	cp	l
	pop	hl
	ret

