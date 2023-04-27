.PHONY: all clean run

D64_IMAGE = "bin/psychedelia.nes"
X64 = fceux

all: clean run

psychedelia.prg:
	ca65 src/psychedelia.asm -l bin/psychedelia.lst -o psychedelia.o
	ld65 -o bin/psychedelia.nes -C psychedelia.cfg psychedelia.o

run: psychedelia.prg
	$(X64) -verbose $(D64_IMAGE)

clean:
	-rm $(D64_IMAGE) $(D64_ORIG_IMAGE) $(D64_HOKUTO_IMAGE)
	-rm bin/psychedelia.prg
	-rm bin/*.txt
