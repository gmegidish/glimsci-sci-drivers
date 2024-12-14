; glimsci.drv - Collection of SCIV video drivers, all hacked up
; Copyright (C) 2024 Gil Megidish
; Based on code by Benedikt Freisen (

[bits 16]
[org 0]

entry:  jmp     dispatch

signature       db      00h, 21h, 43h, 65h, 87h, 00h
driver_name     db      8, "glimpc98"
description     db      41, "MCGA - GLIMSCI - PC98 palette - 16 colors"

palette:
		db 0x00, 0x00, 0x00 ; black
		db 0x00, 0x00, 0x77 ; blue
		db 0x00, 0x77, 0x00 ; green
		db 0x00, 0x77, 0x77 ; cyan
		db 0x77, 0x00, 0x00 ; red
		db 0x77, 0x00, 0x77 ; magenta
		db 0x77, 0x55, 0x00 ; brown
		db 0x99, 0x99, 0x99 ; light gray
		db 0x66, 0x66, 0x66 ; dark gray		
		db 0x00, 0x00, 0xff ; bright blue
		db 0x00, 0xff, 0x00 ; bright green
		db 0x00, 0xff, 0xff ; bright cyan
		db 0xff, 0x77, 0x66 ; bright red
		db 0xff, 0x00, 0xff ; bright magenta
		db 0xff, 0xff, 0x00 ; bright yellow 
		db 0xff, 0xff, 0xff ; bright white

%include "glimbase.s"
