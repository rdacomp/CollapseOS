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
;
; *** SDC buffers ***
;
; SD card's lowest common denominator in terms of block size is 512 bytes, so
; that's what we deal with. To avoid wastefully reading entire blocks from the
; card for one byte read ops, we buffer the last read block. If a GetC or PutC
; operation is within that buffer, then no interaction with the SD card is
; necessary.
;
; As soon as a GetC or PutC operation is made that is outside the current
; buffer, we load a new block.
;
; When we PutC, we flag the buffer as "dirty". On the next buffer change (during
; an out-of-buffer request or during an explicit "flush" operation), bytes
; currently in the buffer will be written to the SD card.
;
; We hold 2 buffers in memory, each targeting a different sector and with its
; own dirty flag. We do that to avoid wasteful block writing in the case where
; we read data from a file in the SD card, process it and write the result
; right away, in another file on the same card (zasm), on a different sector.
;
; If we only have one buffer in this scenario, we'll end up loading a new sector
; at each GetC/PutC operation and, more importantly, writing a whole block for
; a few bytes each time. This will wear the card prematurely (and be very slow).
;
; With 2 buffers, we solve the problem. Whenever GetC/PutC is called, we first
; look if one of the buffer holds our sector. If not, we see if one of the
; buffer is clean (not dirty). If yes, we use this one. If both are dirty or
; clean, we use any. This way, as long as writing isn't made to random
; addresses, we ensure that we don't write wastefully because read operations,
; even if random, will always use the one buffer that isn't dirty.

; *** Defines ***
; SDC_PORT_CSHIGH: Port number to make CS high
; SDC_PORT_CSLOW: Port number to make CS low
; SDC_PORT_SPI: Port number to send/receive SPI data

; *** Consts ***
.equ	SDC_BLKSIZE	512

; *** Variables ***
; This is a pointer to the currently selected buffer. This points to the BUFSEC
; part, that is, two bytes before actual content begins.
.equ	SDC_BUFPTR	SDC_RAMSTART
; Sector number currently in SDC_BUF1. Little endian like any other z80 word.
.equ	SDC_BUFSEC1	SDC_BUFPTR+2
; Whether the buffer has been written to. 0 means clean. 1 means dirty.
.equ	SDC_BUFDIRTY1	SDC_BUFSEC1+2
; The contents of the buffer.
.equ	SDC_BUF1	SDC_BUFDIRTY1+1

; second buffer has the same structure as the first.
.equ	SDC_BUFSEC2	SDC_BUF1+SDC_BLKSIZE
.equ	SDC_BUFDIRTY2	SDC_BUFSEC2+2
.equ	SDC_BUF2	SDC_BUFDIRTY2+1
.equ	SDC_RAMEND	SDC_BUF2+SDC_BLKSIZE

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

; The opposite of sdcWaitResp: we wait until response if 0xff. After a
; successful read or write operation, the card will be busy for a while. We need
; to give it time before interacting with it again. Technically, we could
; continue processing on our side while the card it busy, and maybe we will one
; day, but at the moment, I'm having random write errors if I don't do this
; right after a write, so I prefer to stay cautious for now.
; This has no error condition and preserves A
sdcWaitReady:
	push	af
	; for now, we have no timeout for waiting. It means that broken SD
	; cards can cause infinite loops.
.loop:
	call	sdcIdle
	inc	a		; if 0xff, it's going to become zero
	jr	nz, .loop	; not zero? still busy. loop
	pop	af
	ret

; Sends a command to the SD card, along with arguments and specified CRC fields.
; (CRC is only needed in initial commands though).
; A: Command to send
; H: Arg 1 (MSB)
; L: Arg 2
; D: Arg 3
; E: Arg 4 (LSB)
;
; Returns R1 response in A.
;
; This does *not* handle CS. You have to select/deselect the card outside this
; routine.
sdcCmd:
	push	bc

	; Wait until ready to receive commands
	push	af
	call	sdcWaitResp
	pop	af

	ld	c, 0		; init CRC
	call	.crc7
	call	sdcSendRecv
	; Arguments
	ld	a, h
	call	.crc7
	call	sdcSendRecv
	ld	a, l
	call	.crc7
	call	sdcSendRecv
	ld	a, d
	call	.crc7
	call	sdcSendRecv
	ld	a, e
	call	.crc7
	call	sdcSendRecv
	; send CRC
	ld	a, c
	or	0x01		; ensure stop bit is set
	call	sdcSendRecv

	; And now we just have to wait for a valid response...
	call	sdcWaitResp
	pop	bc
	ret

; push A into C and compute CRC7 with 0x09 polynomial
; Note that the result is "left aligned", that is, that 8th bit to the "right"
; is insignificant (will be stop bit).
.crc7:
	push	af
	xor	c
	ld	b, 8
.loop:
	sla	a
	jr	nc, .noCRC
	; msb was set, apply polynomial
	xor	0x12	; 0x09 << 1. We apply CRC on high 7 bits
.noCRC:
	djnz	.loop
	ld	c, a
	pop	af
	ret

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
	call	sdcIdle
	ld	h, a
	call	sdcIdle
	ld	l, a
	call	sdcIdle
	ld	d, a
	call	sdcIdle
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

; Read block index specified in DE and place the contents in buffer pointed to
; by (SDC_BUFPTR).
; Doesn't check CRC. If the operation is a success, updates buffer's sector to
; the value of DE.
; Returns 0 in A if success, non-zero if error.
sdcReadBlk:
	push	bc
	push	hl

	out	(SDC_PORT_CSLOW), a
	ld	hl, 0
	; DE already has the correct value
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
	ld	hl, (SDC_BUFPTR)	; HL --> active buffer's sector
	; It sounds a bit wrong to set bufsec and dirty flag before we get our
	; actual data, but at this point, we don't have any error conditions
	; left, success is guaranteed. To avoid needlesssly INCing hl, let's
	; set sector and dirty along the way
	ld	a, e			; sector number LSB
	ld	(hl), a
	inc	hl			; sector number MSB
	ld	a, d
	ld	(hl), a
	inc	hl			; dirty flag
	xor	a			; unset
	ld	(hl), a
	inc	hl			; actual contents
.loop2:
	call	sdcIdle
	ld	(hl), a
	cpi			; a trick to inc HL and dec BC at the same time.
				; P/V indicates whether BC reached 0
	jp	pe, .loop2	; BC is not zero, loop
	; Read our 2 CRC bytes
	call	sdcIdle
	call	sdcIdle
	; success! wait until card is ready
	call	sdcWaitReady
	xor	a		; success
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

; Write the contents of buffer where (SDC_BUFPTR) points to in sector associated
; to it. Unsets the the buffer's dirty flag on success.
; A returns 0 in A on success (with Z set), non-zero (with Z unset) on error.
sdcWriteBlk:
	push	hl
	ld	hl, (SDC_BUFPTR)	; HL points to sector LSB
	inc	hl			; sector MSB
	inc	hl			; now to dirty flag
	xor	a
	cp	(hl)
	jr	z, .dontWrite		; A is already 0

	; At this point, HL points to dirty flag of the proper buffer

	push	bc
	push	de

	out	(SDC_PORT_CSLOW), a
	dec	hl		; sector MSB
	ld	a, (hl)
	ld	d, a
	dec	hl		; sector LSB
	ld	a, (hl)
	ld	e, a
	ld	hl, 0		; high addr word always zero, DE already set
	ld	a, 0b01011000	; CMD24
	call	sdcCmd
	or	a		; cp 0
	jr	nz, .error

	; Before sending the data packet, we need to send at least one empty
	; byte.
	ld	a, 0xff
	call	sdcSendRecv

	; data packet token for CMD24
	ld	a, 0xfe
	call	sdcSendRecv

	; Sending our data token!
	ld	bc, SDC_BLKSIZE
	ld	hl, (SDC_BUFPTR)
	inc	hl		; sector MSB
	inc	hl		; dirty flag
	inc	hl		; beginning of contents

.loop:
	ld	a, (hl)
	call	sdcSendRecv
	cpi			; a trick to inc HL and dec BC at the same time.
				; P/V indicates whether BC reached 0
	jp	pe, .loop	; BC is not zero, loop
	; Send our 2 CRC bytes. They can be anything
	call	sdcIdle
	call	sdcIdle
	; Let's see what response we have
	call	sdcWaitResp
	and	0b00011111	; We ignore the first 3 bits of the response.
	cp	0b00000101	; A valid response is "010" in bits 3:1 flanked
				; by 0 on its left and 1 on its right.
	jr	nz, .error
	; good! Now, we need to let the card process this data. It will return
	; 0xff when it's not busy any more.
	call	sdcWaitResp
	; Success! Now let's unset the dirty flag
	ld	hl, (SDC_BUFPTR)
	inc	hl		; sector MSB
	inc	hl		; dirty flag
	xor	a
	ld	(hl), a

	; Before returning, wait until card is ready
	call	sdcWaitReady
	xor	a
	; A is already 0
	jr	.end
.error:
	; try to preserve error code
	or	a		; cp 0
	jr	nz, .end	; already non-zero
	inc	a		; zero, adjust
.end:
	out	(SDC_PORT_CSHIGH), a
	pop	de
	pop	bc
.dontWrite:
	pop	hl
	ret

; Considering the first 15 bits of EHL, select the most appropriate of our two
; buffers and, if necessary, sync that buffer with the SD card. If the selected
; buffer doesn't have the same sector as what EHL asks, load that buffer from
; the SD card.
; If the dirty flag is set, we write the content of the in-memory buffer to the
; SD card before we read a new sector.
; Returns Z on success, not-Z on error (with the error code from either
; sdcReadBlk or sdcWriteBlk)
sdcSync:
	push	de
	; Given a 24-bit address in EHL, extracts the 15-bit sector from it and
	; place it in DE.
	; We need to shift both E and H right by one bit
	srl	e	; sets Carry
	ld	d, e
	ld	a, h
	rra		; takes Carry
	ld	e, a

	; Let's first see if our first buffer has our sector
	ld	a, (SDC_BUFSEC1)	; sector LSB
	cp	e
	jr	nz, .notBuf1
	ld	a, (SDC_BUFSEC1+1)	; sector MSB
	cp	d
	jr	z, .buf1Ok

.notBuf1:
	; Ok, let's check for buf2 then
	ld	a, (SDC_BUFSEC2)	; sector LSB
	cp	e
	jr	nz, .notBuf2
	ld	a, (SDC_BUFSEC2+1)	; sector MSB
	cp	d
	jr	z, .buf2Ok

.notBuf2:
	; None of our two buffers have the sector we need, we'll need to load
	; a new one.

	; We select our buffer depending on which is dirty. If both are on the
	; same status of dirtiness, we pick any (the first in our case). If one
	; of them is dirty, we pick the clean one.
	push	de			; <|
	ld	de, SDC_BUFSEC1		;  |
	ld	a, (SDC_BUFDIRTY1)	;  |
	or	a			;  | is buf1 dirty?
	jr	z, .ready		;  | no? good, that's our buffer
	; yes? then buf2 is our buffer. ;  |
	ld	de, SDC_BUFSEC2		;  |
					;  |
.ready:					;  |
	; At this point, DE points to one o|f our two buffers, the good one.
	; Let's save it to SDC_BUFPTR      |
	ld	(SDC_BUFPTR), de	;  |
					;  |
	pop	de			; <|

	; We have to read a new sector, but first, let's write the current one
	; if needed.
	call	sdcWriteBlk
	jr	nz, .end	; error
	; Let's read our new sector in DE
	call	sdcReadBlk
	jr	.end

.buf1Ok:
	ld	de, SDC_BUFSEC1
	ld	(SDC_BUFPTR), de
	; Z already set
	jr	.end

.buf2Ok:
	ld	de, SDC_BUFSEC2
	ld	(SDC_BUFPTR), de
	; Z already set
	; to .end
.end:
	pop	de
	ret

; *** shell cmds ***

sdcInitializeCmd:
	.db	"sdci", 0, 0, 0
	call	sdcInitialize
	ret	nz
	call	sdcSetBlkSize
	ret	nz
	; At this point, our buffers are unnitialized. We could have some logic
	; that determines whether a buffer is initialized in appropriate SDC
	; routines and act appropriately, but why bother when we could, instead,
	; just buffer the first two sectors of the card on initialization? This
	; way, no need for special conditions.
	; initialize variables
	ld	hl, SDC_BUFSEC1
	ld	(SDC_BUFPTR), hl
	ld	de, 0
	call	sdcReadBlk		; read sector 0 in buf1
	ret	nz
	ld	hl, SDC_BUFSEC2
	ld	(SDC_BUFPTR), hl
	inc	de
	jp	sdcReadBlk		; read sector 1 in buf2, returns

; Flush the current SDC buffer if dirty
sdcFlushCmd:
	.db	"sdcf", 0, 0, 0
	ld	hl, SDC_BUFSEC1
	ld	(SDC_BUFPTR), hl
	call	sdcWriteBlk
	ret	nz
	ld	hl, SDC_BUFSEC2
	ld	(SDC_BUFPTR), hl
	jp	sdcWriteBlk		; returns

; *** blkdev routines ***

; Make HL point to its proper place in SDC_BUF.
; EHL currently is a 24-bit offset to read in the SD card. E=high byte,
; HL=low word. Load the proper sector in memory and make HL point to the
; correct data in the memory buffer.
_sdcPlaceBuf:
	call	sdcSync
	ret	nz		; error
	; At this point, we have the proper buffer in place and synced in
	; (SDC_BUFPTR). Only the 9 low bits of HL are important.
	push	de
	ld	de, (SDC_BUFPTR)
	inc	de		; sector MSB
	inc	de		; dirty flag
	inc	de		; contents
	ld	a, h		; high byte
	and	0x01		; is first bit set?
	jr	z, .read	; first bit reset? we're in the "lowbuf" zone.
				; DE already points to the right place.
	; We're in the highbuf zone, let's inc DE by 0x100, which, as it turns
	; out, is quite easy.
	inc	d
.read:
	; DE is now placed either on the lower or higher half of the active
	; buffer and all we need is to increase DE the lower half of HL.
	ld	a, l
	call	addDE
	ex	de, hl
	pop	de
	; Now, HL points exactly at the right byte in the active buffer.
	xor	a		; ensure Z
	ret

sdcGetC:
	push	hl
	call	_sdcPlaceBuf
	jr	nz, .error

	; This is it!
	ld	a, (hl)
	cp	a		; ensure Z
	jr	.end
.error:
	call	unsetZ
.end:
	pop	hl
	ret

sdcPutC:
	push	hl
	push	af		; let's remember the char we put, _sdcPlaceBuf
				; destroys A.
	call	_sdcPlaceBuf
	jr	nz, .error

	; HL points to our dest. Recall A and write
	pop	af
	ld	(hl), a

	; Now, let's set the dirty flag
	ld	a, 1
	ld	hl, (SDC_BUFPTR)
	inc	hl		; sector MSB
	inc	hl		; point to dirty flag
	ld	(hl), a		; set dirty flag
	xor	a		; ensure Z
	jr	.end
.error:
	; preserve error code
	ex	af, af'
	pop	af
	ex	af, af'
	call	unsetZ
.end:
	pop	hl
	ret
