TARGET = os.sms
ZASM = ../../tools/zasm.sh
KERNEL = ../../kernel

.PHONY: all
all: $(TARGET)
$(TARGET): glue.asm
	$(ZASM) $(KERNEL) < $< > $@
