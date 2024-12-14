## Introduction

glimsci is a collection of VGA video drivers for Sierra's SCI (Sierra Creative Interpreter) game engine. It provides multiple 16-color VGA display modes with different palettes inspired by classic computer systems like the Amiga 500, PC-98, Atari ST, and others.

## Available Drivers

| Driver | Description |
|--------|-------------|
| glim-98 | A VGA driver that emulates the PC-98 color palette and display characteristics. Optimized for games with an anime/visual novel aesthetic. |
| glim-agi | Provides a color palette similar to Sierra's AGI engine games, offering a nostalgic look for classic adventure games. |
| glim-500 | Emulates the Amiga 500's color palette and display characteristics, providing rich, vibrant colors typical of Amiga games. |
| glim-st | Atari ST-inspired color palette and display mode. |

### AGI Driver (Faux 160x200)

Downsample the original 320x200 display to 160x200. Resembling the aesthetics of the original AGI games. All it does it draw every even pixel twice and drop every odd pixel. You will notice that if there is a black pixel or a white pixel in two adjacent pixels, both will be rendere, so the text could be read properly.

|||
|-|-|
| <img src="img/camelot-agi-1.png" width="400">|<img src="img/camelot-agi-2.png" width="400">|
| <img src="img/lsl2-agi-1.png" width="400">|<img src="img/lsl2-agi-2.png" width="400">|

### Custom Palettes: Amiga 500, Atari ST, PC-98

|||
|---|---|
| <img src="img/qfg-spielburg-ega.png" width="400">|<img src="img/qfg-spielburg-amiga.png" width="400">|
|<img src="img/qfg-spielburg-atarist.png" width="400">|<img src="img/qfg-spielburg-pc98.png" width="400">|

## How to Compile
To compile the drivers, you'll need:
- nasm
- make
- gcc

Run the following command in the project directory:
```make```

This will build all available drivers in the `drivers/` directory.

## Usage
To use a driver with your SCI game:

1. Copy driver or all drivers to your game directory
2. Run `INSTALL.EXE`, select the driver you want to use
3. Run your game

## License
This project is available under the LGPL License.

## Credits
**Big shoutout** goes out to Benedikt Freisen for their work on reverse-engineering the SCI engine drivers. You can see the original work at [FOSS SCI Drivers](https://github.com/roybaer/foss_sci_drivers/).
