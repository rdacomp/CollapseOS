#include "jumptable.inc"
.org	0x9000

	call	JUMP_SDCWAKEUP

	; We expect a 0x01 R1 response
	ld	hl, sCmd0
	call	JUMP_PRINTSTR
	ld	a, 0b01000000	; CMD0
	ld	hl, 0
	ld	de, 0
	ld	c, 0x95
	call	JUMP_SDCCMDR1
	cp	0x01
	jr	nz, .error
	ld	hl, sOk
	call	JUMP_PRINTSTR

	; We expect a 0x01 R1 response followed by 0x0001aa R7 response
	ld	hl, sCmd8
	call	JUMP_PRINTSTR
	ld	a, 0b01001000	; CMD8
	ld	hl, 0
	ld	de, 0x01aa
	ld	c, 0x87
	call	JUMP_SDCCMDR7
	ld	a, h
	cp	0
	jr	nz, .error
	ld	a, l
	cp	0
	jr	nz, .error
	ld	a, d
	cp	0x01
	jr	nz, .error
	ld	a, e
	cp	0xaa
	jr	nz, .error
	ld	hl, sOk
	call	JUMP_PRINTSTR
	ret
.error:
	ld	hl, sErr
	call	JUMP_PRINTSTR
	ret

sCmd0:
	.db "Sending CMD0", 0xa, 0xd, 0
sCmd8:
	.db "Sending CMD8", 0xa, 0xd, 0
sOk:
	.db "Ok", 0xa, 0xd, 0
sErr:
	.db "Err", 0xa, 0xd, 0
