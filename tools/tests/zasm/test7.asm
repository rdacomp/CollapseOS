.equ	RAMSTART		0x4000
.equ	ZASM_FIRST_PASS		RAMSTART
.equ	ZASM_LOCAL_PASS		ZASM_FIRST_PASS+1
.equ	ZASM_CTX_PC		ZASM_LOCAL_PASS+1
.equ	ZASM_RAMEND		ZASM_CTX_PC+2

#include "core.asm"
#include "parse.asm"
.equ	BLOCKDEV_RAMSTART	ZASM_RAMEND
.equ	BLOCKDEV_COUNT		0
#include "blockdev.asm"

.equ	FS_RAMSTART		BLOCKDEV_RAMEND
.equ	FS_HANDLE_COUNT		0
#include "fs.asm"

;#include "zasm/util.asm"
;.equ	IO_RAMSTART	ZASM_RAMEND
;#include "zasm/io.asm"

zasmIsFirstPass:
	nop
