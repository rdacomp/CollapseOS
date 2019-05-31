; prints "Hello!" on screen
.equ	printstr	0x03

.org	0x9000

	ld	hl, sHello
	call	printstr
	xor	a		; success
	ret

sHello:
	.db	"Hello!", 0x0d, 0x0a, 0
