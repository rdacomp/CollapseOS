#include "jumptable.inc"
.org	0x9000

	call	JUMP_SDCINITALIZE
	or	a
	jp	nz, .error

	ld	hl, sOk
	call	JUMP_PRINTSTR

	call	JUMP_SDCSETBLKSIZE
	or	a
	jp	nz, .error

	ld	hl, sOk
	call	JUMP_PRINTSTR

	; read sector 0
	xor	a
	call	JUMP_SDCREAD
	or	a
	jp	nz, .error

	push	hl
	ld	hl, sOk
	call	JUMP_PRINTSTR
	pop	hl
	; SDC buffer address is in HL
	; YOLO! print it!
	call	JUMP_PRINTSTR

	ret
.error:
	call	JUMP_PRINTHEX
	ld	hl, sErr
	call	JUMP_PRINTSTR
	ret

sOk:
	.db "Ok", 0xa, 0xd, 0
sErr:
	.db "Err", 0xa, 0xd, 0
