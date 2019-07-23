; There was a very nasty bug (cost me a couple of hours of mis-debugging) where
; ld r, (iy+d) would use the 0xdd byte code instead of the correct 0xfd one.
; genallinstrs didn't catch it because it outputs uppercase. Oh sweet mother,
; how much time did I lose over this...

ld h, (iy+1)
