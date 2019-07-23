#include "user.h"

; *** Overridable consts ***
; Maximum number of lines allowed in the buffer.
.equ	ED_BUF_MAXLINES		0x800
; Size of our scratchpad
.equ	ED_BUF_PADMAXLEN	0x1000

; ******

#include "err.h"
.org	USER_CODE

	jp	edMain

#include "lib/util.asm"
#include "lib/parse.asm"
.equ	IO_RAMSTART	USER_RAMSTART
#include "ed/io.asm"
.equ	BUF_RAMSTART	IO_RAMEND
#include "ed/buf.asm"
.equ	CMD_RAMSTART	BUF_RAMEND
#include "ed/cmd.asm"
.equ	ED_RAMSTART	CMD_RAMEND
#include "ed/main.asm"
