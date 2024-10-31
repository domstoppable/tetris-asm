; graphics.asm
; some very simple graphics routines
; author: Dominic Canare <dom@dominiccanare.com>
;
; todo: implement bresenham's algorithm for drawing lines and circles

.MODEL SMALL

.DATA
	PUBLIC penColor
	penColor		db 15
	tmp			dw ?
	tmp2			dw ?
	oldVideoMode	dw 3

.code
	PUBLIC PutPixel, SaveVideoMode, RestoreVideoMode, SetGraphicsMode, HLine, VLine, Rect, FillRect

	SaveVideoMode PROC
		mov ah, 0Fh
		int 10h
		mov oldVideoMode, ax
		ret
	SaveVideoMode ENDP

	RestoreVideoMode PROC
		mov ax, oldVideoMode
		mov ah, 0
		int 10h
		ret
	RestoreVideoMode ENDP

	SetGraphicsMode PROC ;mode
		mov ah, 0
		mov al, 12h
		int 10h
		ret
	SetGraphicsMode ENDP

	; cx = row
	; dx = col
	PutPixel PROC
		mov al, penColor
		mov ah, 0ch

		int 10h

		ret
	PutPixel ENDP

    ; cx = col
    ; dx = row
    ; bx = width
		HLine PROC;x, y, width, penColor
		mov tmp, cx
		add cx, bx
 draw:
		call PutPixel

		dec cx
		cmp cx, tmp
		jae draw

		ret
	HLine ENDP

	; cx = col
	; dx = row
	; ax = height
	VLine PROC
		mov tmp, dx
		add dx, ax
draw:
		call PutPixel
		dec dx
		cmp dx, tmp
		jae draw

		ret
	VLine ENDP

	;cx = col
	;dx = row
	;bx = width
	;ax = height
	Rect PROC

		push ax
		push bx
		push cx
		push dx
		call HLine

		pop dx
		pop cx
		pop bx
		pop ax
		push ax
		push bx
		push cx
		push dx
		add dx, ax
		call HLine

		pop dx
		pop cx
		pop bx
		pop ax
		push ax
		push bx
		push cx
		push dx
		call VLine

		pop dx
		pop cx
		pop bx
		pop ax
		add cx, bx
		call VLine

		ret
	Rect ENDP

	; ax = height
	; bx = width
	; cx = x
	; dx = y
	FillRect	PROC
		mov tmp2, cx
		add cx, bx
draw:
		push cx
		push dx
		push ax
		call VLine
		pop ax
		pop dx
		pop cx
		dec cx
		cmp cx, tmp2
		jae draw
		ret
	FillRect	ENDP

END