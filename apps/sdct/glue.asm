; sdct
;
; We want to test reading and writing random data in random sequences of
; sectors. Collapse OS doesn't have a random number generator, so we'll simply
; rely on initial SRAM value, which tend is random enough for our purpose.
;
; How it works is simple. From its designated RAMSTART, it calls PutC until it
; reaches the end of RAM (0xffff). Then, it starts over and this time it reads
; every byte and compares.
;
; If there's an error, prints out where.
;
; *** Requirements ***
; sdcPutC
; sdcGetC
; printstr
; printHexPair
;
; *** Includes ***

.inc "user.h"
.org	USER_CODE
.equ	SDCT_RAMSTART	USER_RAMSTART

jp	sdctMain

.inc "sdct/main.asm"
