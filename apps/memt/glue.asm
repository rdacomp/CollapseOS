; memt
;
; Write all possible values in all possible addresses that follow the end of
; this program. That means we don't test all available RAM, but well, still
; better than nothing...
;
; If there's an error, prints out where.
;
; *** Requirements ***
; printstr
; printHexPair
;
; *** Includes ***

#include "user.h"
.org	USER_CODE

jp	memtMain

#include "memt/main.asm"
