#include "jumptable.inc"
.org	0x9000

	call	JUMP_SDCWAKEUP

	; We expect a 0x01 R1 response
	ld	hl, sCmd
	call	JUMP_PRINTSTR
	ld	a, 0b01000000	; CMD0
	ld	hl, 0
	ld	de, 0
	ld	c, 0x95
	call	JUMP_SDCCMDR1
	cp	0x01
	jp	nz, .error
	ld	hl, sOk
	call	JUMP_PRINTSTR

	; We expect a 0x01 R1 response followed by 0x0001aa R7 response
	ld	hl, sCmd
	call	JUMP_PRINTSTR
	ld	a, 0b01001000	; CMD8
	ld	hl, 0
	ld	de, 0x01aa
	ld	c, 0x87
	call	JUMP_SDCCMDR7
	ld	a, d
	cp	0x01
	jp	nz, .error
	ld	a, e
	cp	0xaa
	jr	nz, .error
	ld	hl, sOk
	call	JUMP_PRINTSTR

	; Now we need to repeatedly run CMD55+CMD41 (0x40000000) until we
	; the card goes out of idle mode, that is, when it stops sending us
	; 0x01 response and send us 0x00 instead. Any other response means that
	; initialization failed.
	ld	hl, sCmd
	call	JUMP_PRINTSTR
.loop1:
	ld	a, 0b01110111	; CMD55
	ld	hl, 0
	ld	de, 0
	call	JUMP_SDCCMDR1
	cp	0x01
	jr	nz, .error
	ld	a, 0b01101001	; CMD41 (0x40000000)
	ld	hl, 0x4000
	ld	de, 0x0000
	call	JUMP_SDCCMDR1
	cp	0x01
	jr	z, .loop1
	cp	0
	jr	nz, .error
	; Success! out of idle mode!
	ld	hl, sOk
	call	JUMP_PRINTSTR

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
.loop3:
	call	JUMP_SDCWAITRESP
	; 0xfe is the expected data token for CMD17
	cp	0xfe
	jr	z, .loop3end
	cp	0xff
	jr	nz, .error
	djnz	.loop3
	jr	.error

.loop3end:
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
