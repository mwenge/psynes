.PHONY: all clean run

D64_IMAGE = "bin/psychedelia.nes"
X64 = fceux

all: clean run

psychedelia.prg: src/c64/psychedelia.asm
	ca65 src/psychedelia.asm -g -o psychedelia.o
	ld65 -o bin/psychedelia.nes -C psychedelia.cfg psychedelia.o

run: d64
	$(X64) -verbose $(D64_IMAGE)

clean:
	-rm $(D64_IMAGE) $(D64_ORIG_IMAGE) $(D64_HOKUTO_IMAGE)
	-rm bin/psychedelia.prg
	-rm bin/*.txt
