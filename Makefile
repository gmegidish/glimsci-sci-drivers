all: wip.drv glimst.drv glim500.drv glimpc98.drv

clean:
	rm -f generate-palette atari-st-palette.inc wip.drv

generate-palette: generate-palette.c
	gcc -o generate-palette generate-palette.c

%.drv: %.s
	nasm -o $@ $<

atari-st-palette.inc: generate-palette
	./generate-palette > $@

wip.drv: atari-st-palette.inc wip.s

glimst.drv: glimst.s

glim500.drv: glim500.s

glimpc98.drv: glimpc98.s

