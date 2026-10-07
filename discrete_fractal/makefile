ASM      := nasm
LD       := ld
ASMFLAGS := -f elf64 -w+all -w+error -w-unknown-warning -w-reloc-rel
LDFLAGS  := -pie -I /lib64/ld-linux-x86-64.so.2 --fatal-warnings

TARGET   := discrete_fractal
SRC      := discrete_fractal.asm
OBJ      := discrete_fractal.o

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $<

$(OBJ): $(SRC)
	$(ASM) $(ASMFLAGS) -o $@ $<

clean:
	rm -f $(OBJ) $(TARGET)
