; *** JUMP TABLE ***
JUMP_STRNCMP    .equ    0x02
JUMP_ADDDE      .equ    0x05
JUMP_ADDHL      .equ    0x08
JUMP_UPCASE     .equ    0x0b
JUMP_UNSETZ     .equ    0x0e
JUMP_INTODE	.equ    0x11
JUMP_FINDCHAR	.equ    0x14
JUMP_PARSEHEXPAIR .equ    0x17
JUMP_BLKSEL	.equ    0x1a

.equ	USER_CODE	0x4800
.equ	RAMSTART	0x5800
.org	USER_CODE
#include "main.asm"
