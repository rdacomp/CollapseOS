; test .org directive
.equ foo 1234
.org foo
label1:
	jp	label1
	jr	label1
