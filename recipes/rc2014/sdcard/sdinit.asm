.equ	JUMP_PRINTSTR		0x03
.equ	JUMP_PRINTHEX		0x06
.equ	JUMP_SDCINITALIZE	0x09
.equ	JUMP_SDCSENDRECV	0x0c
.equ	JUMP_SDCWAITRESP	0x0f
.equ	JUMP_SDCCMD		0x12
.equ	JUMP_SDCCMDR1		0x15
.equ	JUMP_SDCCMDR7		0x18
.equ	JUMP_SDCREAD		0x1b
.equ	JUMP_SDCSETBLKSIZE	0x1e
.org	0x9000

	call	JUMP_SDCINITALIZE
	or	a
	jp	nz, error

	ld	hl, sOk
	call	JUMP_PRINTSTR

	call	JUMP_SDCSETBLKSIZE
	or	a
	jp	nz, error

	ld	hl, sOk
	call	JUMP_PRINTSTR

	; read sector 0
	xor	a
	call	JUMP_SDCREAD
	or	a
	jp	nz, error

	push	hl
	ld	hl, sOk
	call	JUMP_PRINTSTR
	pop	hl
	; SDC buffer address is in HL
	; YOLO! print it!
	call	JUMP_PRINTSTR

	ret

error:
	call	JUMP_PRINTHEX
	ld	hl, sErr
	call	JUMP_PRINTSTR
	ret

sOk:
	.db "Ok", 0xa, 0xd, 0
sErr:
	.db "Err", 0xa, 0xd, 0
