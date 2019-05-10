	; comment
	add	a, b	; comment
label1:
	inc	a	; comment
	; comment
	.db	42
label2:
	.dw	42
	.dw	3742
	ld	a, (label1)
	ld	hl, label2
