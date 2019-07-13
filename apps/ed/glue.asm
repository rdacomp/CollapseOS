#include "user.h"
#include "err.h"
.org	USER_CODE

	jp	edMain

.equ	IO_RAMSTART	USER_RAMSTART
#include "ed/io.asm"
#include "ed/main.asm"

