ASM      := nasm
ASMFLAGS := -f elf64 -w+all -w+error

SRC      := arithmetic_sequence.asm
OBJ      := arithmetic_sequence.o

.PHONY: all clean

all: $(OBJ)

$(OBJ): $(SRC)
	$(ASM) $(ASMFLAGS) -o $@ $<

clean:
	rm -f $(OBJ)
