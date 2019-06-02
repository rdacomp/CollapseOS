.equ	RAMSTART	0x4000
.equ	ACIA_CTL	0x80	; Control and status. RS off.
.equ	ACIA_IO		0x81	; Transmit. RS on.

#include "err.h"
#include "core.asm"
#include "parse.asm"
.equ	ACIA_RAMSTART	RAMSTART
#include "acia.asm"

.equ	BLOCKDEV_RAMSTART	ACIA_RAMEND
.equ	BLOCKDEV_COUNT		1
#include "blockdev.asm"
.dw	aciaGetC, aciaPutC, 0, 0

.equ	STDIO_RAMSTART		BLOCKDEV_RAMEND
#include "stdio.asm"

.equ	SHELL_RAMSTART		STDIO_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT	0
#include "shell.asm"
