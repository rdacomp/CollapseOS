TARGET = os.bin
ZASM = ../../tools/emul/zasm/zasm

.PHONY: all
all: $(TARGET)
$(TARGET): glue.asm
	$(ZASM) < $< > $@
