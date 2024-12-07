; glimsci.drv - Collection of SCIV video drivers, all hacked up
; Copyright (C) 2024 Gil Megidish
; Based on code by Benedikt Freisen (

[bits 16]
[org 0]

entry:  jmp     dispatch

signature       db      00h, 21h, 43h, 65h, 87h, 00h
driver_name     db      6, "glimst"
description     db      45, "MCGA - GLIMSCI - Atari ST palette - 16 colors"

call_tab        dw      get_color_depth         ; bp = 0
                dw      init_video_mode         ; bp = 2
                dw      restore_mode            ; bp = 4
                dw      update_rect             ; bp = 6
                dw      show_cursor             ; bp = 8
                dw      hide_cursor             ; bp = 10
                dw      move_cursor             ; bp = 12
                dw      load_cursor             ; bp = 14
                dw      shake_screen            ; bp = 16
                dw      scroll_rect             ; bp = 18

x0		dw	0
y0		dw	0
x1		dw	0
y1		dw	0

atari_st_palette:
		db 0x00, 0x00, 0x00 ; black
		db 0x00, 0x00, 0xa0 ; blue
		db 0x00, 0x80, 0x00 ; green
		db 0x40, 0x80, 0x80 ; cyan
		db 0x80, 0x00, 0x00 ; red
		db 0x80, 0x00, 0x80 ; magenta
		db 0xa0, 0x60, 0x00 ; brown
		db 0xa0, 0xa0, 0xa0 ; light gray
		db 0x40, 0x40, 0x40 ; dark gray
		db 0x00, 0x60, 0xe0 ; bright blue
		db 0x80, 0xe0, 0x40 ; bright green
		db 0x60, 0xe0, 0xe0 ; bright cyan
		db 0xe0, 0x60, 0x40 ; bright red(?)
		db 0xe0, 0x60, 0xe0 ; bright magenta
		db 0xe0, 0xe0, 0x40 ; bright yellow 
		db 0xe0, 0xe0, 0xe0 ; bright white

;-------------- dispatch -----------------------------------------------
; This is the dispatch routine that delegates the incoming far-call to
; to the requested function via call.
;
; Parameters:   bp      index into the call table (always even)
;               ?       depends on the requested function
; Returns:      ?       depends on the requested function
;-----------------------------------------------------------------------
dispatch:
        ; save segments & set ds to cs
        push    es
        push    ds
        push    cs
        pop     ds

        ; dispatch the call while preserving ax, bx, cx, dx and si
        call    [cs:call_tab+bp]

        ; restore segments
        pop     ds
        pop     es

        retf

get_color_depth:
        mov     ax, 16
        ret

init_video_mode:
        ; get current video mode
        mov     ah, 0fh
        int     10h

        ; save mode number
        push    ax

        ; set video mode 0x13 (320x200 - 256 colors)
        mov     ax, 13h
        int     10h

	lea si, [atari_st_palette]
	mov ax, cs
	mov ds, ax

	xor ax, ax
	mov dx, 3c8h
	out dx, al
	inc dx
	mov cx, 300h
.pal:
	lodsb
	shr al, 2
	out dx, al
	loop .pal

        ; restore mode number
        pop     ax
        xor     ah,ah

        ret

restore_mode:
        ; set video mode
        xor     ah,ah
        int     10h
        ret

update_rect:
        mov     bp, 0a000h
        mov     es, bp
        push    ds
        mov     ds, si

	; go one pixel to the left if at odd position
	and	bx, 0xfffe

	; go one pixel to the right if at odd position
	inc	dx
	and	dx, 0xfffe

	mov     word [y0], ax
	mov	word [x0], bx
	mov	word [y1], cx
	mov	word [x1], dx

.loop_y:
	mov	ax, word [y0]
	cmp	ax, word [y1]
	ja	.done_copy

	; get offset of (x0, y)
	mov	ax, word [y0]
	mov	bx, ax
	shl	ax, 8	; *256
	shl	bx, 6	; *32
	add	ax, bx
	add	ax, word [x0]
	mov	di, ax	; 8bpp
	shr	ax, 1
	mov	si, ax ; 4bpp
	mov	cx, word [x1]
	sub	cx, word [x0]
.loop_x:
	ds	lodsb
	mov	ah, al
	and	al, 0fh
	shr     ah, 4
	es	mov	byte [di+0], ah
	es	mov	byte [di+1], al
	add	di, 2
	loop	.loop_x

	inc	word [y0]
	jmp	.loop_y

.done_copy:
	pop	ds
	ret

;-------------- show_cursor --------------------------------------------
; Increment the mouse cursor visibility counter and draw the cursor if
; the counter reaches one.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
show_cursor:
        ret

hide_cursor:
        ret

move_cursor:
	ret

load_cursor:
	ret

shake_screen:
        ret

scroll_rect:
        ; update_rect expects the target frame buffer segment in si
        mov     si,di
        jmp     update_rect

