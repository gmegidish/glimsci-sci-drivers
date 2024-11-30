; PCPLUS.DRV - An SCI video driver for the Plantronics ColorPlus.
; Copyright (C) 2020  Benedikt Freisen
;
; This library is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; This library is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

; SCI drivers use a single code/data segment starting at offset 0
[bits 16]
[org 0]

;-------------- entry --------------------------------------------------
; This is the driver entry point that delegates the incoming far-call
; to the dispatch routine via jmp.
;
; Parameters:   bp      index into the call table (always even)
;               ?       depends on the requested function
; Returns:      ?       depends on the requested function
;-----------------------------------------------------------------------
entry:  jmp     dispatch

; magic numbers followed by two pascal strings
signature       db      00h, 21h, 43h, 65h, 87h, 00h
driver_name     db      6, "pcplus"
description     db      33, "Plantronics ColorPlus - 16 Colors"

; call-table for the dispatcher
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

; active mouse cursor in the internal pixel format
; five bytes per line (four bytes mask data + one padding byte)
cursor_and      times   80 db 0                 ; inverted and-mask
cursor_or       times   80 db 0                 ; or-mask

; saved background pixels overwritten by the cursor
cursor_bg       times   160 db 0
cursor_ofs      dw      0
cursor_hbytes   db      0
cursor_rows     db      0

cursor_counter  dw      0
cursor_x        dw      0
cursor_y        dw      0
cursor_new_x    dw      0
cursor_new_y    dw      0

cursor_lock     dw      0

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

new_palette:
	db 0x00, 0x00, 0x00
	db 0x00, 0x00, 0x28
	db 0x00, 0x20, 0x00
	db 0x10, 0x20, 0x20
	db 0x20, 0x00, 0x00
	db 0x20, 0x00, 0x20
	db 0x28, 0x18, 0x00
	db 0x28, 0x28, 0x28
	db 0x10, 0x10, 0x10
	db 0x00, 0x18, 0x38
	db 0x20, 0x38, 0x10
	db 0x18, 0x38, 0x38
	db 0x38, 0x18, 0x10
	db 0x38, 0x18, 0x38
	db 0x38, 0x38, 0x10
	db 0x38, 0x38, 0x38
	db 0x00, 0x00, 0x14
	db 0x00, 0x00, 0x28
	db 0x00, 0x10, 0x14
	db 0x08, 0x10, 0x24
	db 0x10, 0x00, 0x14
	db 0x10, 0x00, 0x24
	db 0x14, 0x0c, 0x14
	db 0x14, 0x14, 0x28
	db 0x08, 0x08, 0x1c
	db 0x00, 0x0c, 0x30
	db 0x10, 0x1c, 0x1c
	db 0x0c, 0x1c, 0x30
	db 0x1c, 0x0c, 0x1c
	db 0x1c, 0x0c, 0x30
	db 0x1c, 0x1c, 0x1c
	db 0x1c, 0x1c, 0x30
	db 0x00, 0x10, 0x00
	db 0x00, 0x10, 0x14
	db 0x00, 0x20, 0x00
	db 0x08, 0x20, 0x10
	db 0x10, 0x10, 0x00
	db 0x10, 0x10, 0x10
	db 0x14, 0x1c, 0x00
	db 0x14, 0x24, 0x14
	db 0x08, 0x18, 0x08
	db 0x00, 0x1c, 0x1c
	db 0x10, 0x2c, 0x08
	db 0x0c, 0x2c, 0x1c
	db 0x1c, 0x1c, 0x08
	db 0x1c, 0x1c, 0x1c
	db 0x1c, 0x2c, 0x08
	db 0x1c, 0x2c, 0x1c
	db 0x08, 0x10, 0x10
	db 0x08, 0x10, 0x24
	db 0x08, 0x20, 0x10
	db 0x10, 0x20, 0x20
	db 0x18, 0x10, 0x10
	db 0x18, 0x10, 0x20
	db 0x1c, 0x1c, 0x10
	db 0x1c, 0x24, 0x24
	db 0x10, 0x18, 0x18
	db 0x08, 0x1c, 0x2c
	db 0x18, 0x2c, 0x18
	db 0x14, 0x2c, 0x2c
	db 0x24, 0x1c, 0x18
	db 0x24, 0x1c, 0x2c
	db 0x24, 0x2c, 0x18
	db 0x24, 0x2c, 0x2c
	db 0x10, 0x00, 0x00
	db 0x10, 0x00, 0x14
	db 0x10, 0x10, 0x00
	db 0x18, 0x10, 0x10
	db 0x20, 0x00, 0x00
	db 0x20, 0x00, 0x10
	db 0x24, 0x0c, 0x00
	db 0x24, 0x14, 0x14
	db 0x18, 0x08, 0x08
	db 0x10, 0x0c, 0x1c
	db 0x20, 0x1c, 0x08
	db 0x1c, 0x1c, 0x1c
	db 0x2c, 0x0c, 0x08
	db 0x2c, 0x0c, 0x1c
	db 0x2c, 0x1c, 0x08
	db 0x2c, 0x1c, 0x1c
	db 0x10, 0x00, 0x10
	db 0x10, 0x00, 0x24
	db 0x10, 0x10, 0x10
	db 0x18, 0x10, 0x20
	db 0x20, 0x00, 0x10
	db 0x20, 0x00, 0x20
	db 0x24, 0x0c, 0x10
	db 0x24, 0x14, 0x24
	db 0x18, 0x08, 0x18
	db 0x10, 0x0c, 0x2c
	db 0x20, 0x1c, 0x18
	db 0x1c, 0x1c, 0x2c
	db 0x2c, 0x0c, 0x18
	db 0x2c, 0x0c, 0x2c
	db 0x2c, 0x1c, 0x18
	db 0x2c, 0x1c, 0x2c
	db 0x14, 0x0c, 0x00
	db 0x14, 0x0c, 0x14
	db 0x14, 0x1c, 0x00
	db 0x1c, 0x1c, 0x10
	db 0x24, 0x0c, 0x00
	db 0x24, 0x0c, 0x10
	db 0x28, 0x18, 0x00
	db 0x28, 0x20, 0x14
	db 0x1c, 0x14, 0x08
	db 0x14, 0x18, 0x1c
	db 0x24, 0x28, 0x08
	db 0x20, 0x28, 0x1c
	db 0x30, 0x18, 0x08
	db 0x30, 0x18, 0x1c
	db 0x30, 0x28, 0x08
	db 0x30, 0x28, 0x1c
	db 0x14, 0x14, 0x14
	db 0x14, 0x14, 0x28
	db 0x14, 0x24, 0x14
	db 0x1c, 0x24, 0x24
	db 0x24, 0x14, 0x14
	db 0x24, 0x14, 0x24
	db 0x28, 0x20, 0x14
	db 0x28, 0x28, 0x28
	db 0x1c, 0x1c, 0x1c
	db 0x14, 0x20, 0x30
	db 0x24, 0x30, 0x1c
	db 0x20, 0x30, 0x30
	db 0x30, 0x20, 0x1c
	db 0x30, 0x20, 0x30
	db 0x30, 0x30, 0x1c
	db 0x30, 0x30, 0x30
	db 0x08, 0x08, 0x08
	db 0x08, 0x08, 0x1c
	db 0x08, 0x18, 0x08
	db 0x10, 0x18, 0x18
	db 0x18, 0x08, 0x08
	db 0x18, 0x08, 0x18
	db 0x1c, 0x14, 0x08
	db 0x1c, 0x1c, 0x1c
	db 0x10, 0x10, 0x10
	db 0x08, 0x14, 0x24
	db 0x18, 0x24, 0x10
	db 0x14, 0x24, 0x24
	db 0x24, 0x14, 0x10
	db 0x24, 0x14, 0x24
	db 0x24, 0x24, 0x10
	db 0x24, 0x24, 0x24
	db 0x00, 0x0c, 0x1c
	db 0x00, 0x0c, 0x30
	db 0x00, 0x1c, 0x1c
	db 0x08, 0x1c, 0x2c
	db 0x10, 0x0c, 0x1c
	db 0x10, 0x0c, 0x2c
	db 0x14, 0x18, 0x1c
	db 0x14, 0x20, 0x30
	db 0x08, 0x14, 0x24
	db 0x00, 0x18, 0x38
	db 0x10, 0x28, 0x24
	db 0x0c, 0x28, 0x38
	db 0x1c, 0x18, 0x24
	db 0x1c, 0x18, 0x38
	db 0x1c, 0x28, 0x24
	db 0x1c, 0x28, 0x38
	db 0x10, 0x1c, 0x08
	db 0x10, 0x1c, 0x1c
	db 0x10, 0x2c, 0x08
	db 0x18, 0x2c, 0x18
	db 0x20, 0x1c, 0x08
	db 0x20, 0x1c, 0x18
	db 0x24, 0x28, 0x08
	db 0x24, 0x30, 0x1c
	db 0x18, 0x24, 0x10
	db 0x10, 0x28, 0x24
	db 0x20, 0x38, 0x10
	db 0x1c, 0x38, 0x24
	db 0x2c, 0x28, 0x10
	db 0x2c, 0x28, 0x24
	db 0x2c, 0x38, 0x10
	db 0x2c, 0x38, 0x24
	db 0x0c, 0x1c, 0x1c
	db 0x0c, 0x1c, 0x30
	db 0x0c, 0x2c, 0x1c
	db 0x14, 0x2c, 0x2c
	db 0x1c, 0x1c, 0x1c
	db 0x1c, 0x1c, 0x2c
	db 0x20, 0x28, 0x1c
	db 0x20, 0x30, 0x30
	db 0x14, 0x24, 0x24
	db 0x0c, 0x28, 0x38
	db 0x1c, 0x38, 0x24
	db 0x18, 0x38, 0x38
	db 0x28, 0x28, 0x24
	db 0x28, 0x28, 0x38
	db 0x28, 0x38, 0x24
	db 0x28, 0x38, 0x38
	db 0x1c, 0x0c, 0x08
	db 0x1c, 0x0c, 0x1c
	db 0x1c, 0x1c, 0x08
	db 0x24, 0x1c, 0x18
	db 0x2c, 0x0c, 0x08
	db 0x2c, 0x0c, 0x18
	db 0x30, 0x18, 0x08
	db 0x30, 0x20, 0x1c
	db 0x24, 0x14, 0x10
	db 0x1c, 0x18, 0x24
	db 0x2c, 0x28, 0x10
	db 0x28, 0x28, 0x24
	db 0x38, 0x18, 0x10
	db 0x38, 0x18, 0x24
	db 0x38, 0x28, 0x10
	db 0x38, 0x28, 0x24
	db 0x1c, 0x0c, 0x1c
	db 0x1c, 0x0c, 0x30
	db 0x1c, 0x1c, 0x1c
	db 0x24, 0x1c, 0x2c
	db 0x2c, 0x0c, 0x1c
	db 0x2c, 0x0c, 0x2c
	db 0x30, 0x18, 0x1c
	db 0x30, 0x20, 0x30
	db 0x24, 0x14, 0x24
	db 0x1c, 0x18, 0x38
	db 0x2c, 0x28, 0x24
	db 0x28, 0x28, 0x38
	db 0x38, 0x18, 0x24
	db 0x38, 0x18, 0x38
	db 0x38, 0x28, 0x24
	db 0x38, 0x28, 0x38
	db 0x1c, 0x1c, 0x08
	db 0x1c, 0x1c, 0x1c
	db 0x1c, 0x2c, 0x08
	db 0x24, 0x2c, 0x18
	db 0x2c, 0x1c, 0x08
	db 0x2c, 0x1c, 0x18
	db 0x30, 0x28, 0x08
	db 0x30, 0x30, 0x1c
	db 0x24, 0x24, 0x10
	db 0x1c, 0x28, 0x24
	db 0x2c, 0x38, 0x10
	db 0x28, 0x38, 0x24
	db 0x38, 0x28, 0x10
	db 0x38, 0x28, 0x24
	db 0x38, 0x38, 0x10
	db 0x38, 0x38, 0x24
	db 0x1c, 0x1c, 0x1c
	db 0x1c, 0x1c, 0x30
	db 0x1c, 0x2c, 0x1c
	db 0x24, 0x2c, 0x2c
	db 0x2c, 0x1c, 0x1c
	db 0x2c, 0x1c, 0x2c
	db 0x30, 0x28, 0x1c
	db 0x30, 0x30, 0x30
	db 0x24, 0x24, 0x24
	db 0x1c, 0x28, 0x38
	db 0x2c, 0x38, 0x24
	db 0x28, 0x38, 0x38
	db 0x38, 0x28, 0x24
	db 0x38, 0x28, 0x38
	db 0x38, 0x38, 0x24
	db 0x38, 0x38, 0x38


; up to 64 additional colors, where byte is made of two colors of pattern [0..f]
; color is preset at offset+0x10
clut times(64) db 0
clut_used dw 0

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

;-------------- get_color_depth ----------------------------------------
; Returns the number of colors supported by the driver, e.g. 4 or 16.
;
; Parameters:   --
; Returns:      ax      number of colors
; Notes:        The PC1512 driver returns the word -1, instead.
;-----------------------------------------------------------------------
get_color_depth:
        mov     ax, 16
        ret

;-------------- init_video_mode-----------------------------------------
; Initializes the video mode provided by this driver and returns the
; previous video mode, i.e. the BIOS mode number.
;
; Parameters:   --
; Returns:      ax      BIOS mode number of the previous mode
;-----------------------------------------------------------------------
init_video_mode:
        ; get current video mode
        mov     ah, 0fh
        int     10h

        ; save mode number
        push    ax

        ; set video mode 0x13 (320x200 - 256 colors)
        mov     ax, 13h
        int     10h

	lea si, [new_palette]
	mov ax, cs
	mov ds, ax

	xor ax, ax
	mov dx, 3c8h
	out dx, al
	inc dx
	mov cx, 300h
.loop3:
	lodsb
	out dx, al
	loop .loop3

        ; restore mode number
        pop     ax
        xor     ah,ah

        ret

;-------------- restore_mode -------------------------------------------
; Restores the provided BIOS video mode.
;
; Parameters:   ax      BIOS mode number
; Returns:      --
;-----------------------------------------------------------------------
restore_mode:
        ; set video mode
        xor     ah,ah
        int     10h
        ret

;-------------- update_rect --------------------------------------------
; Transfer the specified rectangle from the engine's internal linear
; frame buffer of IRGB pixels to the screen.
;
; Parameters:   ax      Y-coordinate of the top-left corner
;               bx      X-coordinate of the top-left corner
;               cx      Y-coordinate of the bottom-right corner
;               dx      X-coordinate of the bottom-right corner
;               si      frame buffer segment (offset = 0)
; Returns:      --
; Notes:        The implementation may expand the rectangle as needed
;               and may assume that all parameters are valid.
;               It has to hide the mouse cursor if it intersects with
;               the rectangle and has to lock it, otherwise.
;-----------------------------------------------------------------------
update_rect:
	jmp	.skip_mouse

        shr     bx,1
        shr     bx,1
        add     dx,3
        shr     dx,1
        shr     dx,1
        ; load and convert cursor x
        mov     bp,[cursor_x]
        shr     bp,1
        shr     bp,1
        ; compare to right edge
        cmp     dx,bp
        jl      .just_lock
        ; compare to left edge (a bit generously)
        add     bp,5
        sub     bp,bx
        jl      .just_lock
        ; load cursor y
        mov     bp,[cursor_y]
        ; compare to bottom edge
        cmp     cx,bp
        jl      .just_lock
        ; compare to top edge
        add     bp,16
        sub     bp,ax
        jl      .just_lock

        ; locking the cursor is not enough -> hide it
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        call    hide_cursor
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        clc
        jmp     .just_hide

.just_lock:
        call    lock_cursor
        stc
.just_hide:
        pushf

.skip_mouse:
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
	ds	mov al, byte [si]
	mov	ah, al
	and	al, 0fh
	shr	ah, 4

	; read the line below
	ds mov	bl, byte [si+1]
	mov	bh, bl
	and	bl, 0fh
	shr	bh, 4

	; find hatch
	cmp	al, ah
	je	.store_x	; two pixels of the same color

	cmp	al, bl
	jne	.store_x
	cmp	ah, bh
	jne	.store_x

	; found a hatch! check if one of the colors is black
	cmp	al, 0
	je	.one_is_black
	cmp	ah, 0
	je	.one_is_black

	; none is black
	ds	mov al, byte [si]
	mov	ah, al
	jmp	.store_x

.one_is_black:
	add	al, ah
	shl	al, 4
	mov	ah, al
	jmp	.store_x

.store_x:
	es	mov	byte [di+0], ah
	es	mov	byte [di+1], al
	inc	si
	add	di, 2
	loop	.loop_x

	inc	word [y0]
	jmp	.loop_y

.done_copy:
	pop	ds
	ret


        pop     ds
        ; unlock/show cursor
        popf
        jnc     .show
        call    unlock_cursor
        ret
.show:  call    show_cursor

        ret

;-------------- show_cursor --------------------------------------------
; Increment the mouse cursor visibility counter and draw the cursor if
; the counter reaches one.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
show_cursor:
        ; hard synchronization
        pushf
        cli

        or      word [cursor_counter],0
        jne     .skip
        call    draw_cursor

.skip:  inc     word [cursor_counter]
        popf

        ret

;-------------- hide_cursor --------------------------------------------
; Decrement the mouse cursor visibility counter and restore the
; background if the counter reaches zero.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
hide_cursor:
        ; hard synchronization
        pushf
        cli

        dec     word [cursor_counter]
        jnz     .skip
        call    restore_background

.skip:  popf

        ret

;-------------- move_cursor --------------------------------------------
; Moves the mouse cursor, unless it is locked, in which case it will be
; moved when unlocked.
;
; Parameters:   ax      new X-coordinate
;               bx      new Y-coordinate
; Returns:      --
; Note:         This function has to preserve all registers not
;               otherwise preserved.
;-----------------------------------------------------------------------
move_cursor:
        ; save everything
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        pushf

        ; move the cursor, unless it is locked
        cli
        push    bx
        push    ax
        cmp     word [cursor_lock],0
        jnz     .skip
        call    hide_cursor
        pop     word [cursor_x]
        pop     word [cursor_y]
        call    show_cursor
        jmp     .end
.skip:
        ; if locked, save coordinates for later
        pop     word [cursor_new_x]
        pop     word [cursor_new_y]
.end:

        ; restore everything
        popf
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax

        ret

;-------------- load_cursor --------------------------------------------
; Loads a new graphical mouse cursor.
;
; Parameters:   ax      segment of the new cursor
;               bx      offset of the new cursor
; Returns:      ax      the current cursor visibility
; Notes:        Source cursor format expected by load_cursor:
;               Two unused words followed by an AND- and an OR-matrix,
;               each conststing of sixteen 16-bit little-endian words.
;               The most significant bit is the left-most pixel.
;-----------------------------------------------------------------------
load_cursor:
        ; copy the new cursor to the internal cursor data structure
        push    ds
        mov     ds,ax
        lea     si,[bx+4]
        mov     di,cursor_and
        mov     ax,cs
        mov     es,ax

        mov     dx,16
.loop_y_and:
        lodsw
        xchg    al,ah
        not     ax
        mov     cx,8
.shift_loop_1_and:
        shr     ax,1
        rcr     bx,1
        sar     bx,1
        loop    .shift_loop_1_and
        xchg    bl,bh
        mov     [es:di],bx
        inc     di
        inc     di
        mov     cx,8
.shift_loop_2_and:
        shr     ax,1
        rcr     bx,1
        sar     bx,1
        loop    .shift_loop_2_and
        mov     ax,bx
        xchg    al,ah
        stosw
        xor     ax,ax
        stosb
        dec     dx
        jnz    .loop_y_and

        mov     dx,16
.loop_y_or:
        lodsw
        xchg    al,ah
        mov     cx,8
.shift_loop_1_or:
        shr     ax,1
        rcr     bx,1
        sar     bx,1
        loop    .shift_loop_1_or
        xchg    bl,bh
        mov     [es:di],bx
        inc     di
        inc     di
        mov     cx,8
.shift_loop_2_or:
        shr     ax,1
        rcr     bx,1
        sar     bx,1
        loop    .shift_loop_2_or
        mov     ax,bx
        xchg    al,ah
        stosw
        xor     ax,ax
        stosb
        dec     dx
        jnz    .loop_y_or

        pop     ds

        ; make sure that the on-screen cursor changes, as well
        call    hide_cursor
        call    show_cursor

        ; return the cursor visibility counter
        mov     ax,[cursor_counter]

        ret

;-------------- shake_screen -------------------------------------------
; Quickly shake the screen horizontally and/or vertically by a few
; pixels to visualize collisions etc.
;
; Parameters:   ax      segment of timer tick word for busy waiting
;               bx      offset of timer tick word for busy waiting
;               cx      number of times (forth & back count separately)
;               dl      direction mask (bit 1: down; bit 2: right)
; Returns:      --
; Notes:        The implementation should use hardware scrolling and
;               eventually restore the original screen position.
;               The timer tick word is modified concurrently and should
;               be treated as read-only value within this function.
;               The CGA drivers shake by one CRTC character cell size
;               and wait for three timer ticks between steps, whereas
;               the MCGA driver provides an empty dummy function.
;-----------------------------------------------------------------------
shake_screen:
        ; this dummy implementation returns right away
        ret

;-------------- scroll_rect --------------------------------------------
; Scroll out the content of the specified rectangle while filling it
; with the new content.
;
; Parameters:   ax      Y-coordinate of the top-left corner
;               bx      X-coordinate of the top-left corner
;               cx      Y-coordinate of the bottom-right corner
;               dx      X-coordinate of the bottom-right corner
;               di      frame buffer segment (offset = 0)
;               ?       potentially further parameters for
;                       implementations that actually scroll
; Returns:      --
; Notes:        Simple implementations may omit the scrolling and
;               delegate the call to update_rect, adjusting the
;               parameters as needed.
;-----------------------------------------------------------------------
scroll_rect:
        ; update_rect expects the target frame buffer segment in si
        mov     si,di
        ; tail call to update_rect
        jmp     update_rect

;***********************************************************************
; The helper functions below are not part of the API.
;***********************************************************************

;-------------- draw_cursor --------------------------------------------
; Draws the mouse cursor after saving the screen content at its
; position to a buffer.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
draw_cursor:
	ret

        ; calculate on-screen cursor dimensions
        mov     ax,200
        sub     ax,[cursor_y]
        cmp     ax,16
        jl      .nocrop_v
        mov     ax,16
.nocrop_v:
        mov     [cursor_rows],ax

        mov     ax,[cursor_x]
        shr     ax,1
        shr     ax,1
        mov     bx,ax
        sub     ax,80
        neg     ax
        cmp     ax,5
        jl      .nocrop_h
        mov     ax,5
.nocrop_h:
        mov     [cursor_hbytes],al

        ; calculate cursor offset in video ram
        mov     ax,[cursor_y]
        xor     si,si
        shr     ax,1
        rcr     si,1
        shr     si,1
        shr     si,1
        mov     ah,80
        mul     ah
        add     si,ax
        add     si,bx
        mov     [cursor_ofs],si

        ; save screen content that will be overwritten
        push    ds
        mov     ax,ds
        mov     es,ax
        mov     ax,0a000h
        mov     ds,ax
        mov     di,cursor_bg

        ; red/green page
        xor     bx,bx
        mov     bl,[cs:cursor_hbytes]
        mov     dl,[cs:cursor_rows]
        xor     cx,cx
.save_y_loop_rg:
        mov     cl,bl
        rep     movsb
        sub     si,bx
        ; handle scanline interleaving
        add     si,8192
        cmp     si,16384
        jb      .save_odd_rg
        sub     si,16304
.save_odd_rg:
        dec     dl
        jnz     .save_y_loop_rg

        ; blue/intensity page
        mov     si,[cs:cursor_ofs]
        add     si,16384
        xor     bx,bx
        mov     bl,[cs:cursor_hbytes]
        mov     dl,[cs:cursor_rows]
        xor     cx,cx
.save_y_loop_bi:
        mov     cl,bl
        rep     movsb
        sub     si,bx
        ; handle scanline interleaving
        add     si,8192
        cmp     si,32768
        jb      .save_odd_bi
        sub     si,16304
.save_odd_bi:
        dec     dl
        jnz     .save_y_loop_bi

        pop     ds

        ; draw cursor
        mov     ax,0a000h
        mov     es,ax
        mov     di,[cursor_ofs]
        mov     si,cursor_and
        ; calculate X-offset, load row count
        mov     cx,[cursor_x]
        and     cx,3
        shl     cl,1
        mov     ch,[cursor_rows]

.draw_y_loop:
        ; count horizontal bytes in bl
        xor     bx,bx

        ; handle first byte in line
        ; load one word of the inverted AND-mask for this line
        mov     ax,[si]
        xchg    al,ah
        shr     ax,cl
        ; restore non-inverted
        not     ax
        mov     al,ah
        ; apply the AND-mask
        and     al,[es:di]
        and     ah,[es:di+16384]
        mov     bp,ax
        mov     ax,[si+80]
        xchg    al,ah
        shr     ax,cl
        mov     al,ah
        ; apply the OR-mask
        or      ax,bp
        mov     [es:di+bx],al
        mov     [es:di+bx+16384],ah
        inc     bl

        ; handle rest of line
.draw_x_loop:
        cmp     bl,[cursor_hbytes]
        je      .draw_x_loop_end
        ; load one word of the inverted AND-mask for this line
        mov     ax,[si+bx-1]
        xchg    al,ah
        shr     ax,cl
        ; restore non-inverted
        not     ax
        mov     ah,al
        ; apply the AND-mask
        and     al,[es:di+bx]
        and     ah,[es:di+bx+16384]
        mov     bp,ax
        mov     ax,[si+bx+80-1]
        xchg    al,ah
        shr     ax,cl
        mov     ah,al
        ; apply the OR-mask
        or      ax,bp
        mov     [es:di+bx],al
        mov     [es:di+bx+16384],ah
        inc     bl
        jmp     .draw_x_loop
.draw_x_loop_end:
        add     si,5

        ; handle scanline interleaving
        add     di,8192
        cmp     di,16384
        jb      .draw_odd
        sub     di,16304
.draw_odd:
        dec     ch
        jnz     .draw_y_loop

        ret

;-------------- restore_background -------------------------------------
; Restore the screen content previously saved and overwritten by
; draw_cursor.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
restore_background:
        mov     ax,0a000h
        mov     es,ax

        ; red/green page
        mov     di,[cursor_ofs]

        mov     si,cursor_bg
        xor     bx,bx
        mov     bl,[cursor_hbytes]
        mov     dl,[cursor_rows]
        xor     cx,cx
.y_loop_rg:
        mov     cl,bl
        rep     movsb
        sub     di,bx
        ; handle scanline interleaving
        add     di,8192
        cmp     di,16384
        jb      .odd_rg
        sub     di,16304
.odd_rg:
        dec     dl
        jnz     .y_loop_rg

        ; blue/intensity page
        mov     di,[cursor_ofs]
        add     di,16384

        xor     bx,bx
        mov     bl,[cursor_hbytes]
        mov     dl,[cursor_rows]
        xor     cx,cx
.y_loop_bi:
        mov     cl,bl
        rep     movsb
        sub     di,bx
        ; handle scanline interleaving
        add     di,8192
        cmp     di,32768
        jb      .odd_bi
        sub     di,16304
.odd_bi:
        dec     dl
        jnz     .y_loop_bi

        ret

;-------------- lock_cursor --------------------------------------------
; Locks the cursor in its current position without changing its
; visibility.
;
; Parameters:   --
; Returns:      --
; Notes:        Has to preserve all registers
;-----------------------------------------------------------------------
lock_cursor:
        ; hard synchronization
        pushf
        cli

        inc     word [cursor_lock]
        push    ax
        ; initialize new cursor position with current cursor position
        mov     ax,[cursor_x]
        mov     [cursor_new_x],ax
        mov     ax,[cursor_y]
        mov     [cursor_new_y],ax
        pop     ax

        popf

        ret

;-------------- unlock_cursor ------------------------------------------
; Unlocks the cursor and updates its position, if it has changed since
; the cursor has been locked.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
unlock_cursor:
        ; hard synchronization
        pushf
        cli

        dec     word [cursor_lock]
        jnz     .end
        ; check if cursor should have moved and move for real
        mov     ax,[cursor_new_x]
        mov     bx,[cursor_new_y]
        cmp     ax,[cursor_x]
        jne     .move
        cmp     bx,[cursor_y]
        jne     .move
        jmp     .end
.move:  call    move_cursor

.end:   popf

        ret
