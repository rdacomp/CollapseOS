; sdc
;
; Manages the initialization of a SD card and implement a block device to read
; and write from/to it, in SPI mode.
;
; Note that SPI can't really be used directly from the z80, so this part
; assumes that you have a device that handles SPI communication on behalf of
; the z80. This device is assumed to work in a particular way.
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

; sdcSendRecv 0xff until the response is something else than 0xff for a maximum
; of 20 times. Returns 0xff if no response.
sdcWaitResp:
	push	bc
	ld	b, 20
.loop:
	ld	a, 0xff
	call	sdcSendRecv
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
	call	sdcWaitResp
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
