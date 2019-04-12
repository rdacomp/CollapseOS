; classic RC2014 setup (8K ROM + 32K RAM) and a stock Serial I/O module

RAMEND		.equ	0xa000
ACIA_CTL	.equ	0x80	; Control and status. RS off.
ACIA_IO		.equ	0x81	; Transmit. RS on.
