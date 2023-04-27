.PHONY: all clean run

NES_IMAGE = "bin/psychedelia.nes"
FCEUX = fceux

all: clean run

psychedelia.prg:
	ca65 src/psychedelia.asm -l bin/psychedelia.lst -o psychedelia.o
	ld65 -o $(NES_IMAGE) -C psychedelia.cfg psychedelia.o

run: psychedelia.prg
	$(FCEUX) -verbose $(NES_IMAGE)

clean:
	-rm $(NES_IMAGE)
	-rm bin/*.txt
	-rm bin/*.lst
