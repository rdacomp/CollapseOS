; *** Consts ***
; Memory address where the AT28 is configured to start
.equ	AT28W_MEMSTART		0x2000

; Value mismatch during validation
.equ	AT28W_ERR_MISMATCH	0x10

; *** Variables ***
.equ	AT28W_MAXBYTES	AT28W_RAMSTART
.equ	AT28W_RAMEND	AT28W_MAXBYTES+2
; *** Code ***

at28wMain:
	ld	de, .argspecs
	ld	ix, AT28W_MAXBYTES
	call	parseArgs
	jr	z, at28wInner
	; bad args
	ld	a, SHELL_ERR_BAD_ARGS
	ret
.argspecs:
	.db	0b111, 0b101, 0

at28wInner:
	; Reminder: words in parseArgs aren't little endian. High byte is first.
	ld	a, (AT28W_MAXBYTES)
	ld	b, a
	ld	a, (AT28W_MAXBYTES+1)
	ld	c, a
	ld	hl, AT28W_MEMSTART
	call	at28wBCZero
	jr	nz, .loop
	; BC is zero, default to 0x2000 (8k, the size of the AT28)
	ld	bc, 0x2000
.loop:
	call	blkGetC
	jr	nz, .loopend
	ld	(hl), a
	ld	e, a		; save expected data for verification
	; initiate polling
	ld	a, (hl)
	ld	d, a
.wait:
	; as long as writing operation is running, IO/6 will toggle at each
	; read attempt. We know that write is finished when we read the same
	; value twice.
	ld	a, (hl)
	cp	d
	jr	z, .waitend
	ld	d, a
	jr	.wait
.waitend:

	; same value was read twice. A contains our final value for this memory
	; address. Let's compare with what we're written.
	cp	e
	jr	nz, .mismatch
	inc	hl
	dec	bc
	call	at28wBCZero
	jr	nz, .loop

.loopend:
	; We're finished. Success!
	xor	a
	ret

.mismatch:
	ld	a, AT28W_ERR_MISMATCH
	ret

at28wBCZero:
	xor	a
	cp	b
	ret	nz
	cp	c
	ret

