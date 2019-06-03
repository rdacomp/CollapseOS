.equ	printstr	0x3c

.org	0x9000

	ld	hl, sAwesome
	call	printstr
	xor	a		; success
	ret

sAwesome:
	.db	"Assembled from the shell", 0x0d, 0x0a, 0

