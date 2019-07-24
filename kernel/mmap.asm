; mmap
;
; Block device that maps to memory.
;
; *** DEFINES ***
; MMAP_START: Memory address where the mmap begins
; Memory address where the mmap stops, exclusively (we aren't allowed to access
; that address).
.equ	MMAP_LEN	0xffff-MMAP_START

; Returns absolute addr of memory pointer in HL if HL is within bounds.
; Sets Z on success, unset when out of bounds.
_mmapAddr:
	push	de
	ld	de, MMAP_LEN
	call	cpHLDE
	jr	nc, .outOfBounds	; HL >= DE
	ld	de, MMAP_START
	add	hl, de
	cp	a	; ensure Z
	pop	de
	ret
.outOfBounds:
	pop	de
	jp	unsetZ

mmapGetC:
	push	hl
	call	_mmapAddr
	jr	nz, .end
	ld	a, (hl)
	; Z already set
.end:
	pop	hl
	ret


mmapPutC:
	push	hl
	call	_mmapAddr
	jr	nz, .end
	ld	(hl), a
	; Z already set
.end:
	pop	hl
	ret
