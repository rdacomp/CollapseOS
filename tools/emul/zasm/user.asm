; *** JUMP TABLE ***
JUMP_STRNCMP    .equ    0x03
JUMP_ADDDE      .equ    0x06
JUMP_ADDHL      .equ    0x09
JUMP_UPCASE     .equ    0x0c
JUMP_UNSETZ     .equ    0x0f
JUMP_INTODE	.equ    0x12
JUMP_INTOHL	.equ    0x15
JUMP_FINDCHAR	.equ    0x18
JUMP_PARSEHEXPAIR .equ  0x1b
JUMP_BLKSEL	.equ    0x1e
JUMP_FSFINDFN	.equ    0x21
JUMP_FSOPEN	.equ    0x24
JUMP_FSGETC	.equ    0x27
JUMP_FSSEEK	.equ    0x2a
JUMP_FSTELL	.equ    0x2d

.equ	FS_HANDLE_SIZE	8
.equ	USER_CODE	0x4800
.equ	RAMSTART	0x5800
.org	USER_CODE
#include "main.asm"
