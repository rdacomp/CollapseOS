	; comment
	add	a, b	; comment
label1:
	inc	a	; comment
	ld	hl, label2
	.dw	label2
	; comment
	.db	42, 54
label2: .dw	0x42
	.dw	3742, 0xffff
	.dw	0x3742
	ld	a, (label1)
	rla \ rla
.equ	foo	0x1234
.equ	bar	foo
	ld	hl, bar
	ld	ix, 1234
	ld	iy, 2345
