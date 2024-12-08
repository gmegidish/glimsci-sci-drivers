OBJS=\
     glim8bit.drv \
     glim-st.drv \
     glim-500.drv \
     glim-98.drv \
     glim-agi.drv \
     glimflip.drv

all: $(OBJS)

clean:
	rm -f generate-palette atari-st-palette.inc $(OBJS)

generate-palette: generate-palette.c
	gcc -o generate-palette generate-palette.c

%.drv: %.s
	nasm -o $@ $<

atari-st-palette.inc: generate-palette
	./generate-palette > $@

glim8bit.drv: atari-st-palette.inc glim8bit.s

