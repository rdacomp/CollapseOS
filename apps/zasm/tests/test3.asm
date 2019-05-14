; test local labels
addDE:
	push	af
	add	a, e
	jr	nc, .end	; no carry? skip inc
	inc	d
.end:	ld	e, a
	pop	af
	ret

addHL:
	push	af
	add	a, l
	jr	nc, .end	; no carry? skip inc
	inc	h
.end:
	ld	l, a
	pop	af
	ret
