#include "jumptable.inc"
.org	0x9000

	call	JUMP_SDCINITALIZE
	or	a
	jp	nz, .error

	; Alright, normally we should configure block size and all, but this is
	; too exciting and we'll play it dirty: we'll read just enough bytes
	; to fetch our "Hello World!" and print it and we'll leave the SD card
	; hanging. Yeah, I know, not very polite.


	out	(5), a
	ld	hl, sCmd
	call	JUMP_PRINTSTR
	ld	a, 0b01010001	; CMD17
	ld	hl, 0		; read single block at addr 0
	ld	de, 0
	call	JUMP_SDCCMD
	cp	0
	jr	nz, .error

	ld	hl, sCmd
	call	JUMP_PRINTSTR
	; Command sent, no error, now let's wait for our data response.
	ld	b, 20
.loop1:
	call	JUMP_SDCWAITRESP
	; 0xfe is the expected data token for CMD17
	cp	0xfe
	jr	z, .loop1end
	cp	0xff
	jr	nz, .error
	djnz	.loop1
	jr	.error

.loop1end:
	ld	hl, sGettingData
	call	JUMP_PRINTSTR
	; Data packets follow immediately
	ld	b, 12		; size of "Hello World!"
	ld	hl, sDest	; sDest has null chars, we'll be alright
				; printing it.
.loop2:
	call	JUMP_SDCWAITRESP
	ld	(hl), a
	inc	hl
	djnz	.loop2
	out	(6), a
	ld	hl, sDest
	call	JUMP_PRINTSTR
	ret
.error:
	call	JUMP_PRINTHEX
	ld	hl, sErr
	call	JUMP_PRINTSTR
	ret

sCmd:
	.db "CMD", 0xa, 0xd, 0
sGettingData:
	.db "Data", 0xa, 0xd, 0
sOk:
	.db "Ok", 0xa, 0xd, 0
sErr:
	.db "Err", 0xa, 0xd, 0

sDest:
	.fill 0x10
