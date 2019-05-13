; Test relative jumps
label1:
	jp	label1
	jp	label2
	jp	label2
	jr	label2
	jr	nc, label1

label2:
	jr	label1
	jr	nc, label1
