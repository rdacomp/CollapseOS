.equ	RAMSTART	0x4000
.equ	ACIA_CTL	0x80	; Control and status. RS off.
.equ	ACIA_IO		0x81	; Transmit. RS on.

#include "core.asm"
#include "parse.asm"
.equ	ACIA_RAMSTART	RAMSTART
#include "acia.asm"
