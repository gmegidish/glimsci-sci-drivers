OUTDIR=drivers
OBJS=\
     $(OUTDIR)/glim8bit.drv \
     $(OUTDIR)/glim-st.drv \
     $(OUTDIR)/glim-500.drv \
     $(OUTDIR)/glim-98.drv \
     $(OUTDIR)/glim-agi.drv

all: $(OBJS)

clean:
	rm -f generate-palette atari-st-palette.inc $(OBJS)
	rmdir $(OUTDIR)

generate-palette: generate-palette.c
	gcc -o generate-palette generate-palette.c

$(OUTDIR)/%.drv: %.s
	@mkdir -p $(OUTDIR)
	nasm -o $@ $<

atari-st-palette.inc: generate-palette
	./generate-palette > $@

$(OUTDIR)/glim8bit.drv: atari-st-palette.inc glim8bit.s

