RAMSTART	.equ	0x8000
RAMEND		.equ	0xffff
USER_CODE	.equ	RAMSTART

; *** JUMP TABLE ***
JUMP_STRNCMP    .equ    0x02
JUMP_ADDDE      .equ    0x05
JUMP_UPCASE     .equ    0x08
JUMP_UNSETZ     .equ    0x0b
