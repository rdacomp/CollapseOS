; test some weird label bug zasm had at some point. Simply to refer to a local
; label in a .dw directive would mess up future label references.
foo:
	inc	a
.bar:
	inc	b
.baz:
	.dw	.bar

loop:
	jr	loop
