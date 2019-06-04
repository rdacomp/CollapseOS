; mmap
;
; Block device that maps to memory.
;
; *** DEFINES ***
; MMAP_START: Memory address where the mmap begins

; Returns absolute addr of memory pointer in HL.
_mmapAddr:
	push	de
	ld	de, MMAP_START
	add	hl, de
	jr	nc, .end
	; we have carry? out of bounds, set to maximum
	ld	hl, 0xffff
.end:
	pop	de
	ret

; if out of bounds, will continually return the last char
; TODO: add bounds check and return Z accordingly.
mmapGetC:
	push	hl
	call	_mmapAddr
	ld	a, (hl)
	cp	a	; ensure Z
	pop	hl
	ret

mmapPutC:
	push	hl
	call	_mmapAddr
	ld	(hl), a
	cp	a	; ensure Z
	pop	hl
	ret
