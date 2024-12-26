; glimsci.drv - Collection of SCIV video drivers, all hacked up
; Copyright (C) 2024 Gil Megidish
; Based on code by Benedikt Freisen

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
driver_name     db      7, "glim-a2"
description     db      35, "MCGA - GLIMSCI - Apple II DHGR - 320x200"

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

cursor_counter  dw      0

x0		dw	0
y0		dw	0
x1		dw	0
y1		dw	0
mul320		times(200) dw 0

palette:
		db 0x00, 0x00, 0x00 ; black
		db 0x0c, 0x11, 0xa4 ; blue
		db 0x1c, 0x82, 0x31 ; green
		db 0x7a, 0xb3, 0xff ; cyan
		db 0xdb, 0x1f, 0x42 ; red
		db 0xdc, 0x43, 0xe1 ; magenta
		db 0xfb, 0xa5, 0x93 ; brown
		db 0xb3, 0xb3, 0xb3 ; light gray
		db 0x63, 0x63, 0x63 ; dark gray
		db 0x39, 0x3d, 0xff ; bright blue
		db 0x40, 0xde, 0x00 ; bright green
		db 0x7a, 0xb3, 0xff ; bright cyan (DUPLICATE)
		db 0x91, 0x64, 0x00 ; bright red (actually brown?)
		db 0xdc, 0x43, 0xe1 ; bright magenta (duplicate)
		db 0xfe, 0xfe, 0x00 ; bright yellow
		db 0xff, 0xff, 0xff ; bright white

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

	; prepare lookup table
	xor	ax, ax
	mov	cx, 200
	lea	si, [mul320]
.loop4:
	cs	mov [si], ax
	add	si, 2
	add	ax, 320
	loop	.loop4

	; copy palette
	lea si, [palette]
	mov ax, cs
	mov ds, ax

	xor ax, ax
	mov dx, 3c8h
	out dx, al
	inc dx
	mov cx, 16*3
.pal:
	lodsb
	shr al, 2
	out dx, al
	loop .pal

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
        mov     bp, 0a000h
        mov     es, bp
        push    ds
        mov     ds, si

	; go one pixel to the left if at odd position
	and	bx, 0xfffe

	; go one pixel to the right if at odd position
	inc	dx
	and	dx, 0xfffe

	; TODO: because the state depends on the previous 3 pixels, we need to calculate
	; the top 3 bits of the color before we render the 4th. however, I'm too lazy for
	; this right now
	mov	bx, 0
	mov	dx, 320

	mov     word [y0], ax
	mov	word [x0], bx
	mov	word [y1], cx
	mov	word [x1], dx

.loop_y:
	mov	ax, word [y0]
	cmp	ax, word [y1]
	ja	.done_copy

	; get offset of (x0, y)
	mov	bx, word [y0]
	shl	bx, 1
	lea	si, [mul320]
	cs	mov	ax, [si + bx]
	add	ax, word [x0]
	mov	di, ax	; 8bpp
	shr	ax, 1
	mov	si, ax ; 4bpp
	mov	cx, word [x1]
	sub	cx, word [x0]
	inc	cx
	shr	cx, 1

	mov	dl, 0	; pixel
	mov	dh, 8	; 1<<3 within current pixel

.loop_even:
	lodsb					; read 2 pixels
	mov	ah, al				; split into two pixels of 4 bits, [ah, al]
	shr	ah, 4
	and	al, 0fh

	; turn off bit in dl first
	not	dh
	and	dl, dh				; turn it off
	not	dh
	and	ah, dh				; mask out the bit in the original pixel
	or	dl, ah				; update state
	es	mov byte [di], dl		; write to screen
	inc	di

	; next pixel
	shr	dh, 1
	jnz	.no_warp
	mov	dh, 8
.no_warp:
	; now do the same for right pixel
	not	dh
	and	dl, dh				; turn it off
	not	dh
	and	al, dh				; mask out the bit in the original pixel
	or	dl, al				; update state
	es	mov byte [di], dl		; write to screen
	inc	di

	; next pixel
	shr	dh, 1
	jnz	.no_warp2
	mov	dh, 8
.no_warp2:

	loop	.loop_even

	; end of row
	inc	word [y0]
	jmp	.loop_y

.done_copy:
	pop	ds
	ret

        ret

;-------------- show_cursor --------------------------------------------
; Increment the mouse cursor visibility counter and draw the cursor if
; the counter reaches one.
;
; Parameters:   --
; Returns:      --
;-----------------------------------------------------------------------
show_cursor:
	pushf
	inc	word [cursor_counter]
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
	pushf
	dec	word [cursor_counter]
	popf
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
	mov ax, word [cursor_counter]
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

