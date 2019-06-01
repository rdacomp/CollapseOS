; sdc
;
; Manages the initialization of a SD card and implement a block device to read
; and write from/to it, in SPI mode.
;
; Note that SPI can't really be used directly from the z80, so this part
; assumes that you have a device that handles SPI communication on behalf of
; the z80. This device is assumed to work in a particular way. See the
; "rc2014/sdcard" recipe for details.
;
; That device has 3 ports. One write-only port to make CS high, one to make CS
; low (data sent is irrelevant), and one read/write port to send and receive
; bytes with the card through the SPI protocol. The device acts as a SPI master
; and writing to that port initiates a byte exchange. Data from the slave is
; then placed on a buffer that can be read by reading the same port.
;
; It's through that kind of device that this code below is supposed to work.

; *** Defines ***
; SDC_PORT_CSHIGH: Port number to make CS high
; SDC_PORT_CSLOW: Port number to make CS low
; SDC_PORT_SPI: Port number to send/receive SPI data

; *** Consts ***
.equ	SDC_BLKSIZE	512

; *** Variables ***
; Where the block dev current points to. This is a byte index. Higher 7 bits
; indicate a sector number, lower 9 bits are an offset in the current SDC_BUF.
.equ	SDC_PTR		SDC_RAMSTART
; Whenever we read a sector, we read a whole block at once and we store it
; in memory. That's where it goes.
.equ	SDC_BUF		SDC_PTR+2
; Sector number currently in SDC_BUF. 0xff, it's initial value, means "no
; sector.
.equ	SDC_BUFSEC	SDC_BUF+SDC_BLKSIZE
; Whether the buffer has been written to. 0 means clean. 1 means dirty.
; (not used yet)
.equ	SDC_BUFDIRTY	SDC_BUFSEC+1
.equ	SDC_RAMEND	SDC_BUFDIRTY+1

; *** Code ***
; Wake the SD card up. After power up, a SD card has to receive at least 74
; dummy clocks with CS and DI high. We send 80.
sdcWakeUp:
	out	(SDC_PORT_CSHIGH), a
	ld	b, 10		; 10 * 8 == 80
	ld	a, 0xff
.loop:
	out	(SDC_PORT_SPI), a
	nop
	djnz	.loop
	ret

; Initiate SPI exchange with the SD card. A is the data to send. Received data
; is placed in A.
sdcSendRecv:
	out	(SDC_PORT_SPI), a
	nop
	nop
	in	a, (SDC_PORT_SPI)
	nop
	nop
	ret

sdcIdle:
	ld	a, 0xff
	jp	sdcSendRecv

; sdcSendRecv 0xff until the response is something else than 0xff for a maximum
; of 20 times. Returns 0xff if no response.
sdcWaitResp:
	push	bc
	ld	b, 20
.loop:
	call	sdcIdle
	inc	a		; if 0xff, it's going to become zero
	jr	nz, .end	; not zero? good, that's our command
	djnz	.loop
.end:
	; whether we had a success or failure, we return the result.
	; But first, let's bring it back to its original value.
	dec	a
	pop	bc
	ret

; Sends a command to the SD card, along with arguments and specified CRC fields.
; (CRC is only needed in initial commands though).
; A: Command to send
; H: Arg 1 (MSB)
; L: Arg 2
; D: Arg 3
; E: Arg 4 (LSB)
; C: CRC
;
; Returns R1 response in A.
;
; This does *not* handle CS. You have to select/deselect the card outside this
; routine.
sdcCmd:
	; Wait until ready to receive commands
	push	af
	call	sdcWaitResp
	pop	af

	call	sdcSendRecv
	; Arguments
	ld	a, h
	call	sdcSendRecv
	ld	a, l
	call	sdcSendRecv
	ld	a, d
	call	sdcSendRecv
	ld	a, e
	call	sdcSendRecv
	; send CRC
	ld	a, c
	call	sdcSendRecv

	; And now we just have to wait for a valid response...
	jp	sdcWaitResp		; return

; Send a command that expects a R1 response, handling CS.
sdcCmdR1:
	out	(SDC_PORT_CSLOW), a
	call	sdcCmd
	out	(SDC_PORT_CSHIGH), a
	ret

; Send a command that expects a R7 response, handling CS. A R7 is a R1 followed
; by 4 bytes. Those 4 bytes are returned in HL/DE in the same order as in
; sdcCmd.
sdcCmdR7:
	out	(SDC_PORT_CSLOW), a
	call	sdcCmd

	; We have our R1 response in A. Let's try reading the next 4 bytes in
	; case we have a R3.
	push	af
	ld	a, 0xff
	call	sdcSendRecv
	ld	h, a
	ld	a, 0xff
	call	sdcSendRecv
	ld	l, a
	ld	a, 0xff
	call	sdcSendRecv
	ld	d, a
	ld	a, 0xff
	call	sdcSendRecv
	ld	e, a
	pop	af

	out	(SDC_PORT_CSHIGH), a
	ret

; Initialize a SD card. This should be called at least 1ms after the powering
; up of the card. Sets result code in A. Zero means success, non-zero means
; error.
sdcInitialize:
	push	hl
	push	de
	push	bc
	call	sdcWakeUp

	; Call CMD0 and expect a 0x01 response (card idle)
	; This should be called multiple times. We're actually expected to.
	; Let's call this for a maximum of 10 times.
	ld	b, 10
.loop1:
	ld	a, 0b01000000	; CMD0
	ld	hl, 0
	ld	de, 0
	ld	c, 0x95
	call	sdcCmdR1
	cp	0x01
	jp	z, .cmd0ok
	djnz	.loop1
	; Nothing? error
	jr	.error
.cmd0ok:

	; Then comes the CMD8. We send it with a 0x01aa argument and expect
	; a 0x01aa argument back, along with a 0x01 R1 response.
	ld	a, 0b01001000	; CMD8
	ld	hl, 0
	ld	de, 0x01aa
	ld	c, 0x87
	call	sdcCmdR7
	cp	0x01
	jr	nz, .error
	xor	a
	cp	h	; H is zero
	jr	nz, .error
	cp	l	; L is zero
	jr	nz, .error
	ld	a, d
	cp	0x01
	jp	nz, .error
	ld	a, e
	cp	0xaa
	jr	nz, .error

	; Now we need to repeatedly run CMD55+CMD41 (0x40000000) until we
	; the card goes out of idle mode, that is, when it stops sending us
	; 0x01 response and send us 0x00 instead. Any other response means that
	; initialization failed.
.loop2:
	ld	a, 0b01110111	; CMD55
	ld	hl, 0
	ld	de, 0
	call	sdcCmdR1
	cp	0x01
	jr	nz, .error
	ld	a, 0b01101001	; CMD41 (0x40000000)
	ld	hl, 0x4000
	ld	de, 0x0000
	call	sdcCmdR1
	cp	0x01
	jr	z, .loop2
	or	a		; cp 0
	jr	nz, .error
	; Success! out of idle mode!
	; initialize variables
	ld	hl, 0
	ld	(SDC_PTR), hl
	ld	a, 0xff
	ld	(SDC_BUFSEC), a
	xor	a
	ld	(SDC_BUFDIRTY), a
	jr	.end

.error:
	ld	a, 0x01
.end:
	pop	bc
	pop	de
	pop	hl
	ret

; Send a command to set block size to SDC_BLKSIZE to the SD card.
; Returns zero in A if a success, non-zero otherwise
sdcSetBlkSize:
	push	hl
	push	de

	ld	a, 0b01010000	; CMD16
	ld	hl, 0
	ld	de, SDC_BLKSIZE
	call	sdcCmdR1
	; Since we're out of idle mode, we expect a 0 response
	; We need no further processing: A is already the correct value.
	pop	de
	pop	hl
	ret

; Read block index specified in A and place the contents in (SDC_BUF).
; Doesn't check CRC. If the operation is a success, updates (SDC_BUFSEC) to the
; value of A.
; Returns 0 in A if success, non-zero if error.
sdcReadBlk:
	push	bc
	push	hl

	out	(SDC_PORT_CSLOW), a
	ld	hl, 0		; read single block at addr A
	ld	d, 0
	ld	e, a		; E isn't touched in the rest of the routine
				; and holds onto our original A
	ld	a, 0b01010001	; CMD17
	call	sdcCmd
	or	a		; cp 0
	jr	nz, .error

	; Command sent, no error, now let's wait for our data response.
	ld	b, 20
.loop1:
	call	sdcWaitResp
	; 0xfe is the expected data token for CMD17
	cp	0xfe
	jr	z, .loop1end
	cp	0xff
	jr	nz, .error
	djnz	.loop1
	jr	.error		; timeout. error out
.loop1end:
	; We received our data token!
	; Data packets follow immediately, we have 512 of them to read
	ld	bc, SDC_BLKSIZE
	ld	hl, SDC_BUF
.loop2:
	call	sdcIdle
	ld	(hl), a
	cpi			; a trick to inc HL and dec BC at the same time.
				; P/V indicates whether BC reached 0
	jp	pe, .loop2	; BC is not zero, loop
	; Read our 2 CRC bytes
	call	sdcIdle
	call	sdcIdle
	; success! Let's recall our orginal A arg and put it in SDC_BUFSEC
	ld	a, e
	ld	(SDC_BUFSEC), a
	xor	a
	ld	(SDC_BUFDIRTY), a
	jr	.end
.error:
	; try to preserve error code
	or	a		; cp 0
	jr	nz, .end	; already non-zero
	inc	a		; zero, adjust
.end:
	out	(SDC_PORT_CSHIGH), a
	pop	hl
	pop	bc
	ret

; *** shell cmds ***

sdcInitializeCmd:
	.db	"sdci", 0, 0, 0
	call	sdcInitialize
	jp	sdcSetBlkSize		; return

; *** blkdev routines ***

sdcGetC:
	; SDC_PTR points to the character we're supposed to read right now, but
	; we first have to check whether we need to load a new sector in memory.
	; To do this, we compare the high 7 bits of (SDC_PTR) with (SDC_BUFSEC).
	; If they're different, we need to load a new block.
	push	hl
	ld	a, (SDC_BUFSEC)
	ld	h, a
	ld	a, (SDC_PTR+1)	; high byte has bufsec in its high 7 bits
	srl	a
	cp	h
	jr	z, .noload
	; not equal, we need to load a new sector. A already contains the
	; sector to load.
	call	sdcReadBlk
	jr	nz, .error
.noload:
	ld	a, (SDC_PTR+1)	; high byte
	and	0x01		; is first bit set?
	jr	nz, .highbuf	; first bit set? we're in the "highbuf" zone.
	; lowbuf zone
	; Read byte from memory at proper offset in lowbuf (first 0x100 bytes)
	ld	hl, SDC_BUF
	jr	.read
.highbuf:
	; Read byte from memory at proper offset in highbuf (0x100-0x1ff)
	ld	hl, SDC_BUF+0x100
.read:
	; HL is now placed either on the lower or higher half of SDC_BUF and
	; all we need is to increase HL by the number in SDC_PTR's LSB (little
	; endian, remember).
	ld	a, (SDC_PTR)	; LSB
	call	addHL

	; This is it!
	ld	a, (hl)

	; before we return A, we need to increase (SDC_PTR)
	ld	hl, (SDC_PTR)
	inc	hl
	ld	(SDC_PTR), hl

	cp	a		; ensure Z
	jr	.end

.error:
	call	unsetZ
.end:
	pop	hl
	ret

sdcSeek:
	ld	(SDC_PTR), hl
	ret

sdcTell:
	ld	hl, (SDC_PTR)
	ret

