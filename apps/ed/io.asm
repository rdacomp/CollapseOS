; io - handle ed's I/O

; *** Consts ***
;
; Max length of a line
.equ	IO_MAXLEN	0x7f

; *** Variables ***
; Handle of the target file
.equ	IO_FILE_HDL	IO_RAMSTART
; block device targeting IO_FILE_HDL
.equ	IO_BLK		IO_FILE_HDL+FS_HANDLE_SIZE
; Buffer for lines read from I/O.
.equ	IO_LINE		IO_BLK+BLOCKDEV_SIZE
.equ	IO_RAMEND	IO_LINE+IO_MAXLEN+1	; +1 for null
; *** Code ***

; Given a file name in (HL), open that file in (IO_FILE_HDL) and open a blkdev
; on it at (IO_BLK).
ioInit:
	call	fsFindFN
	ret	nz
	ld	ix, IO_FILE_HDL
	call	fsOpen
	ld	de, IO_BLK
	ld	hl, .blkdev
	jp	blkSet
.fsGetC:
	ld	ix, IO_FILE_HDL
	jp	fsGetC
.fsPutC:
	ld	ix, IO_FILE_HDL
	jp	fsPutC
.blkdev:
	.dw	.fsGetC, unsetZ

ioGetC:
	push	ix
	ld	ix, IO_BLK
	call	_blkGetC
	pop	ix
	ret

ioPutC:
	push	ix
	ld	ix, IO_BLK
	call	_blkPutC
	pop	ix
	ret

ioSeek:
	push	ix
	ld	ix, IO_BLK
	call	_blkSeek
	pop	ix
	ret

ioTell:
	push	ix
	ld	ix, IO_BLK
	call	_blkTell
	pop	ix
	ret
