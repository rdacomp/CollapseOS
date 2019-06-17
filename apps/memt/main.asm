memtMain:
	ld	de, memtEnd
.loop:
	ld	b, 0
.iloop:
	ld	a, b
	ld	(de), a
	ld	a, (de)
	cp	b
	jr	nz, .notMatching
	djnz	.iloop
	inc	de
	xor	a
	cp	d
	jr	nz, .loop
	cp	e
	jr	nz, .loop
	; we rolled over 0xffff, stop
	ld	hl, .sOk
	xor	a
	jp	printstr	; returns
.notMatching:
	ld	hl, .sNotMatching
	call	printstr
	ex	de, hl
	ld	a, 1
	jp	printHexPair	; returns
.sNotMatching:
	.db	"Not matching at pos ", 0xd, 0xa, 0
.sOk:
	.db	"OK", 0xd, 0xa, 0
memtEnd:

