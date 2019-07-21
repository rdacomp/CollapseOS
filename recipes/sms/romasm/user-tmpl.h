; USER_CODE is filled in on-the-fly with either ED_CODE or ZASM_CODE
.equ    ED_CODE         0x1800
.equ    ZASM_CODE       0x1c00
.equ    USER_RAMSTART   0xc200
.equ    FS_HANDLE_SIZE  6
.equ    BLOCKDEV_SIZE   8

; *** JUMP TABLE ***
.equ	strncmp			0x03
.equ	addDE			0x06
.equ	addHL			0x09
.equ	upcase			0x0c
.equ	unsetZ			0x0f
.equ	intoDE			0x12
.equ	intoHL			0x15
.equ	writeHLinDE		0x18
.equ	findchar		0x1b
.equ	parseHex		0x1e
.equ	parseHexPair	0x21
.equ	blkSel			0x24
.equ	blkSet			0x27
.equ	fsFindFN		0x2a
.equ	fsOpen			0x2d
.equ	fsGetC			0x30
.equ	fsPutC			0x33
.equ	fsSetSize		0x36
.equ	cpHLDE			0x39
.equ	parseArgs		0x3c
.equ	printstr		0x3f
.equ	_blkGetC		0x42
.equ	_blkPutC		0x45
.equ	_blkSeek		0x48
.equ	_blkTell		0x4b
.equ	printcrlf		0x4e
.equ	stdioPutC		0x51
.equ	stdioReadLine	0x54

