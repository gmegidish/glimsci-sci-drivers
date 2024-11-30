all: wip.drv

clean:
	rm -f generate-palette atari-st-palette.inc wip.drv

generate-palette: generate-palette.c
	gcc -o generate-palette generate-palette.c

%.drv: %.s
	nasm -o $@ $<

atari-st-palette.inc: generate-palette
	./generate-palette > $@

wip.drv: atari-st-palette.inc wip.s

