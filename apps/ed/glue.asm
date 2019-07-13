#include "user.h"
#include "err.h"
.org	USER_CODE

	jp	edMain

#include "lib/parse.asm"
.equ	IO_RAMSTART	USER_RAMSTART
#include "ed/io.asm"
.equ	BUF_RAMSTART	IO_RAMEND
#include "ed/buf.asm"
.equ	ED_RAMSTART	BUF_RAMEND
#include "ed/main.asm"

