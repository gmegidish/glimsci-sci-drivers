#include <stdio.h>
#include <string.h>

static const unsigned char atari_st[16*3] = {
	0x00, 0x00, 0x00, // black
	0x00, 0x00, 0xa0, // blue
	0x00, 0x80, 0x00, // green
	0x40, 0x80, 0x80, // cyan
	0x80, 0x00, 0x00, // red
	0x80, 0x00, 0x80, // magenta
	0xa0, 0x60, 0x00, // brown
	0xa0, 0xa0, 0xa0, // light gray
	0x40, 0x40, 0x40, // dark gray
	0x00, 0x60, 0xe0, // bright blue
	0x80, 0xe0, 0x40, // bright green
	0x60, 0xe0, 0xe0, // bright cyan
	0xe0, 0x60, 0x40, // bright red(?)
	0xe0, 0x60, 0xe0, // bright magenta
	0xe0, 0xe0, 0x40, // bright yellow 
	0xe0, 0xe0, 0xe0, // bright white
};

int main() {

	unsigned char palette[768] = {0};

	unsigned char *ptr = palette;

	memcpy(ptr, atari_st, 16*3);
	ptr += 16*3;

	for (int lo=1; lo<16; lo++) {
		for (int hi=0; hi<16; hi++) {
			*ptr++ = (atari_st[lo*3+0] + atari_st[hi*3+0]) >> 1;
			*ptr++ = (atari_st[lo*3+1] + atari_st[hi*3+1]) >> 1;
			*ptr++ = (atari_st[lo*3+2] + atari_st[hi*3+2]) >> 1;
		}
	}

	for (int i=0; i<256; i++) {
		printf("\tdb 0x%02x, 0x%02x, 0x%02x\n", palette[i*3+0] >> 2, palette[i*3+1] >> 2, palette[i*3+2] >> 2);
	}

	return 0;
}
