; tetris.asm
; A TETRIS clone written in assembly
; author: Dominic Canare <dom@dominiccanare.com>
;
; F2		- pause/unpause
; Escape	- quit
; it's important to note that microsoft's DOS emulator
; 	must be placed into FULL SCREEN MODE before running

INCLUDE pcmac.inc

.MODEL SMALL

.586

.STACK 100h

.DATA
	EXTRN penColor: BYTE
	PUBLIC seed

	; Game states
	RUNNING	equ	1
	PAUSED	equ	2
	OVER		equ	3
	state	db	RUNNING
	DND		db	0	; do not disturb flag for timing issue workaround

	; Keyboard codes
	UP		equ	72
	DOWN		equ	80
	LEFT		equ	75
	RIGHT	equ	77
	F2		equ	60

	initX	equ	6
	initY	equ	-4

	msg1		db "Controls:", 13, 10, "  Left/Right - Move piece", 13, 10, "  Up - Rotate Piece", 13, 10, "  Down - Lower piece", 13, 10, "  Space - Drop piece", 13, 10, "  F2 - Pause/Unpause", 13, 10, "$"
	msg2		db "Please make sure you are running in FULL SCREEN MODE by pressing ALT+ENTER.", 13, 10, "When you are ready to play, press F2...", "$"
	msg3		db "You made ", "$"
	msg4		db " line(s)!", 13, 10, "Press F2 to quit...", "$"

	; Classic tetris pieces defined as words
	pieces	dw	0100010001000100b,	; - X - - | - - - - | - - - - | - - - -
				0000011000100010b,	; - X - - | - X X - | - X X - | - X X -
				0000011001000100b,	; - X - - | - - X - | - X - - | - X X -
				0000011001100000b,	; - X - - | - - X - | - X - - | - - - -
				0000001001100010b,	; - - - - | - - - - | - - - -
				0000110001100000b,	; - - X - | X X - - | - - X X
				0000001101100000b	; - X X - | - X X - | - X X -
								; - - X - | - - - - | - - - -

	colors	db	4, 14, 3, 2, 6, 9, 13

			db	4 dup(3 dup(1), 10 dup(0), 3 dup(1))
	board	db	20 dup(3 dup(1), 10 dup(0), 3 dup(1))
								; --X-  ----  ----
	;Size of gameboard in blocks
	gameW	dw	10
	gameH	dw	20

	;Size of piece blocks in pixels
	blockS	dw	20

	;Offset of gameboard
	xOffset	dw	10
	yOffset	dw	10

	; location of the current piece's bottom-leftmost corner on the gameboard
	pieceX	dw	?
	pieceY	dw	?

	; the current block in the gameboard to be drawn/erased
	x	dw	0
	y	dw	0

	; temp
	i	dw	?
	j	dw	?
	tmp	dw	?
	tmp1 dw	?
	tmp2	dw	?
	tmpb	db	?

	; the current piece
	piece	dw	0	; holds the 2byte binary representation of the piece
	piecePtr	db	0	; points to the piece in the pieces and colors arrays
	nxtPieceP	db	0	; points to the next piece

	; number of lines the user has made
	lines	dw	0

	; for random piece selection
	seed		dd	0

	; clock interrupt handler
	OldClockHandler	dd	?
	startTicks		equ	21
	WaitTicks			dw	startTicks
	timeCounter		dw	startTicks
	ClockInt			equ	1Ch

.CODE
	EXTRN SaveVideoMode: NEAR, RestoreVideoMode: NEAR, SetGraphicsMode: NEAR, HLine: NEAR, VLine: NEAR, Rect: NEAR, FillRect: NEAR, Random: NEAR, PutDec: NEAR

	ClockHandler PROC	; from text
		push ds
		push ax
		mov ax, @data	;   in general
		mov ds, ax
		pushf
		call OldClockHandler; Let normal processing take place

		cmp state, PAUSED
		je NotDone

		cmp DND, 1
		je NotDone

		dec timeCounter
		jnz NotDone
		call Drop
		mov ax, waitTicks
		mov timeCounter, ax
NotDone:
		pop ax
		pop ds
		iret
	ClockHandler ENDP

	Main	PROC
		_Begin


		_PutStr msg1
		_PutStr msg2

waitLoop1:
		mov ah, 01h
		int 16h
		jz waitLoop1
		mov ah, 0
		int 16h
		cmp al, 0
		jnz waitLoop1
		mov al, ah
		cbw
		cmp al, F2
		jne waitLoop1

		_SaveIntVec ClockInt, OldClockHandler
		_SetIntVec ClockInt, ClockHandler

		call SaveVideoMode
		call SetGraphicsMode

		call DrawFrame

		mov penColor, 15

		call NewGame

ReadLoop:
		cmp state, OVER
		je quit
		;test timeToDrop, 1
		;jz kbd
		;mov timeToDrop, 0
		;call Drop

kbd:
		mov ah, 01h
		int 16h
		jz ReadLoop
		mov ah, 0		;Read Key opcode
		int 16h
		cmp al, 0		;Special function key?
		jz  Special

		push ax
		cbw

		cmp al, 13
		je EnterKey
		cmp al, 32
		jne Continue

SpaceBar:
		cmp state, RUNNING
		jne ReadLoop

		mov DND, 1
		call drop
		cmp ax, 1
		jne SpaceBar
		mov DND, 0

EnterKey:
		; jmp DrawSpot

Continue:
		pop ax
		cmp al, 27         ;escape key
		je Quit
		jmp ReadLoop

Special:
		mov DND, 1

		mov al, ah
		cbw

		cmp al, F2
		je toggleState

		cmp state, RUNNING
		jne ReadLoop
		; cmp state, RUNNING
		; jne ReadLoop

		cmp al, UP
		je DoUp
		cmp al, LEFT
		je DoLeft
		cmp al, RIGHT
		je DoRight
		cmp al, DOWN
		je DoDown

		jmp Continue

ToggleState:
		call PAUSETOGGLE
		mov bl, piecePtr
		mov bh, 0
		mov bl, colors[bx]
		mov penColor, bl
		mov DND, 0
		jmp ReadLoop
		jmp DrawSpot

DoUp:
		call ErasePiece

		call Rotate
		jmp DrawSpot

DoLeft:
		call ErasePiece
		mov ax, -1
		mov bx, 0
		jmp lblM

DoRight:
		call ErasePiece
		mov ax, 1
		mov bx, 0
		jmp lblM

DoDown:
		call Drop
		cmp ax, 1
		jmp DrawSpot

lblM:
		call TryMovePiece

DrawSpot:
		mov bl, piecePtr
		mov bh, 0
		mov bl, colors[bx]
		mov penColor, bl
		call DrawPiece

		mov DND, 0

		jmp ReadLoop

Quit:

		_SetIntVec ClockInt, OldClockHandler
		call RestoreVideoMode

		_PutStr msg3
		mov ax, lines
		call PutDec
		_PutStr msg4
waitLoop2:
		mov ah, 01h
		int 16h
		jz waitLoop2
		mov ah, 0
		int 16h
		cmp al, 0
		jnz waitLoop2
		mov al, ah
		cbw
		cmp al, F2
		jne waitLoop2

		_Exit 0

	Main	ENDP

	DrawFrame	PROC
;;		mov penColor, 8
;;		add blockS, 2		; two pixel margin for grid

		;draw horizontal lines
;;		mov ax, gameW	; width of horiz lines = blocks * block size
;;		imul blockS		;
;;		mov bx, ax		;

;;		mov ax, gameH	;
;;		imul blockS
;;		mov dx, ax
;;		add dx, yOffset		; draw grid 10 pixels from the top
;;		mov cx, xOffset
;;		sub dx, blockS
;;drawHLine:
;;		push bx
;;		push cx
;;		push dx
;;		call HLine
;;		pop dx
;;		pop cx
;;		pop bx
;;		sub dx, blockS
;;		cmp dx, yOffset
;;		ja drawHLine

		;draw vertical lines
;;		mov ax, gameW	;
;;		imul blockS
;;		mov cx, ax
;;		add cx, xOffset		; draw grid 10 pixels from the left

;;		mov ax, gameH	; width of horiz lines = blocks * block size
;;		imul blockS		;

;;		mov dx, yOffset
;;		sub cx, blockS

;;drawVLine:
;;		push ax
;;		push cx
;;		push dx
;;		call VLine
;;		pop dx
;;		pop cx
;;		pop ax
;;		sub cx, blockS
;;		cmp cx, xOffset
;;		ja drawVLine

; now draw the frame around the grid

		mov penColor, 15
		mov ax, gameW
		imul blockS
		mov bx, ax

		mov ax, gameH
		imul blockS

		mov cx, xOffset
		mov dx, yOffset
		sub cx, 2
		sub dx, 2
		add ax, 4
		add bx, 4

		call Rect

		sub blockS, 2

		ret
	DrawFrame	ENDP

	; pieceX, pieceY = bottomleft corner of piece
	PutPiece	PROC
		;for(i=0;i<4 && (i+piecY)<gameH;i++){	// for each row
		;	for(j=0;j<4;j++){	// for each cell in that row
		;		ColorBlock(j+x, i+y);
		;	}
		;}

		mov i, 0

		loop1:

			mov j, 0
			loop2:
				;if this block is 0, "je loop2"
				;mov ax, piece
				rol piece, 1
				jnc endLoop2	; nothing to draw

				mov ax, pieceX
				add ax, j
				mov x, ax

				mov ax, pieceY
				add ax, i
				cmp ax, 0
				jl endLoop2

				mov y, ax

				sub x, 3

				call ColorBlock
				endLoop2:
				inc j
				cmp j, 4
			jl loop2

			inc i
			cmp i, 4
		jl loop1

		ret
	PutPiece	ENDP

	DrawPiece	PROC
		mov bl, piecePtr
		mov bh, 0
		mov bl, colors[bx]
		mov penColor, bl

		call PutPiece

		ret
	DrawPiece	ENDP

	ErasePiece	PROC
		mov al, penColor
		;push ax
		mov penColor, 0
		call PutPiece
		;pop ax
		;mov penColor, al
		ret
	ErasePiece	ENDP

	; x
	; y
	ColorBlock	PROC
		push ax
		push bx
		push cx
		push dx

		mov ax, x
		imul blockS
		mov cx, ax
		add cx, xOffset
		mov ax, x
		mov bx, 2
		imul bx
		add cx, ax
		inc cx

		mov ax, y
		imul blockS
		mov dx, ax
		add dx, yOffset
		add dx, y
		mov ax, y
		add dx, ax
		inc dx

		mov ax, blockS
		mov bx, blockS

		call FillRect

		cmp penColor, 0
		je exit

		push ax
		mov al, penColor
		mov tmpB, al
		mov penColor, 15
		pop ax

		sub ax, 3
		sub bx, 3
		add cx, 2
		add dx, 2
		push ax
		push bx
		push cx
		push dx
		call Rect
		pop dx
		pop cx
		pop bx
		pop ax

		mov penColor, 0

		add dx, ax
		;sub dx, 3
		push bx
		push cx
		push dx
		call HLine
		pop dx
		pop cx
		pop bx
		mov ax, bx
		sub dx, ax
		call VLine
		mov al, tmpB
		mov penColor, al
	; ax = height
	; bx = width
	; cx = x
	; dx = y

exit:
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	ColorBlock	ENDP

	EraseBlock	PROC
		mov al, penColor
		push ax
		mov penColor, 0
		call ColorBlock
		pop ax
		mov penColor, al

		ret
	EraseBlock	ENDP

	; ax = pieceX
	; bx = pieceY
	; returns 0 in ax if no collision, 1 in ax if collision
	CollisionDet	PROC
		;for(i=0;i<4 && (i+piecY)<gameH;i++){	// for each row
		;	for(j=0;j<4;j++){	// for each cell in that row
		;		if(!Test(j+x, i+y)) return false
		;	}
		;}
		;

		;mov tmp, 0
		mov tmp1, ax
		mov tmp2, bx
		mov y, 0
		mov cx, piece
		loop1:
			mov x, 0
			loop2:
				inc tmp
				rol cx, 1
				jnc endLoop2	; block is empty, no collision possible

				mov ax, y
				add ax, tmp2
				;cmp ax, 0
				;jl endLoop2

				cmp ax, gameH
				jge collision

				mov bx, 16
				mul bx
				mov bx, ax
				add bx, x
				add bx, tmp1

				cmp board[bx], 0
				jng endLoop2	; no collision

				collision:
				mov ax, 1
				ret

				;pop bx

				endLoop2:
				inc bx
				inc x
				cmp x, 4
			jl loop2

			inc y
			cmp y, 4
		jl loop1
		mov ax, 0
		ret
	CollisionDet	ENDP

	; ax = delta x
	; bx = delta y
	; returns 1 in ax if move fails
	TryMovePiece	PROC
		add ax, pieceX
		add bx, pieceY
		push ax
		push bx
		call CollisionDet
		mov tmp, ax
		pop bx
		pop ax
		cmp tmp, 1
		je quitCollision	; collision detected
		mov pieceX, ax
		mov pieceY, bx
		mov ax, 0
		jmp quitNoColl
quitCollision:
		mov ax, 1
quitNoColl:
		ret
	TryMovePiece	ENDP

	DrawBoard	PROC
		mov ax, gameH
		dec ax
		mov y, ax
		loop1:
			mov ax, y
			mov bx, 16	; each row is 16 bytes
			mul bx
			mov bx, ax	;bx now points to start of the row
			add bx, 3
			mov x, 3
			loop2:
				mov cl, board[bx]
				mov penColor, cl
				push x
				sub x, 3

				call ColorBlock

				pop x

				inc bx
				inc x
				cmp x, 13
			jl loop2

			dec y
			cmp y, 0
		jge loop1

		ret
	DrawBoard	ENDP

	PlacePiece	PROC
		mov tmp, 0
		mov y, 0
		loop1:
			mov x, 0
			loop2:
				inc tmp
				rol piece, 1
				jnc endLoop2

				push bx
				mov bl, piecePtr
				mov bh, 0
				mov cl, colors[bx]

				mov ax, y
				add ax, pieceY
				mov bx, 16
				mul bx
				mov bx, ax
				add bx, x
				add bx, pieceX
				cmp bx, 3
				jge itsOK
				mov state, OVER
				itsOK:
				mov board[bx], cl

				pop bx

				endLoop2:
				inc bx
				inc x
				cmp x, 4
			jl loop2

			inc y
			cmp y, 4
		jl loop1

		call CheckLines

		call GetNewPiece
;		jmp endPlacePiece
;dead:
;		mov state, OVER
;endPlacePiece:
		ret
	PlacePiece	ENDP

	Rotate	PROC
		;for(int i=0;i<4;i++){
		;	for(int j=0;j<4;j++){
		;		tmp[j][i] = piece[i][j];
		;	}
		;}
		mov cx, piece
		mov tmp, 0
		mov i, 0
		loop1:
			mov j, 0
			loop2:
				rol cx, 1
				jnc endLoop2	; no block

				;rotate temp piece to proper position
				push cx
				mov ax, j
				mov bx, 4
				mul bx
				add ax, 3
				sub ax, i
				mov cl, al
				inc cl
				rol tmp, cl
				inc tmp
				ror tmp, cl
				pop cx

				endLoop2:
				inc j
				cmp j, 4
				jl loop2

			inc i
			cmp i, 4
		jl loop1

		push cx
		mov ax, tmp
		mov piece, ax
		mov ax, pieceX
		mov bx, pieceY
		call CollisionDet
		pop cx
		cmp ax, 1
		jne exit
		mov piece, cx
exit:
		mov al, piecePtr
		mov penColor, al
		call DrawPiece

		ret
	Rotate	ENDP

	; returns 1 in ax if piece is set
	Drop		PROC
		call ErasePiece
		mov ax, 0
		mov bx, 1
		call TryMovePiece
		cmp ax, 1
		jne quit
		; collision detected
		call PlacePiece
		mov ax, 1
quit:
		mov al, piecePtr
		mov penColor, al
		call DrawPiece

		ret
	Drop		ENDP

	GetNewPiece	PROC
		mov al, nxtPieceP
		mov piecePtr, al
		mov pieceX, 14
		mov pieceY, 5
		call getPiece
		call erasePiece

		mov ah, 2ch
		mov al, 0
		int 21h

		mov seed, edx

		call Random

		mov bl, 7
		sub ah, ah
		div bl

		mov piecePtr, ah

		mov pieceX, 14
		mov pieceY, 5
		call GetPiece
		call DrawPiece

		mov al, piecePtr
		mov ah, nxtPieceP
		mov piecePtr, ah
		mov nxtPieceP, al

		mov pieceX, initX
		mov pieceY, initY

		call GetPiece
		call DrawPiece

		ret
	GetNewPiece	ENDP

	GetPiece	PROC
		sub ah, ah
		mov al, piecePtr
		mov bl, 2
		mul bl
		mov bx, ax
		mov bx, pieces[bx]
		mov piece, bx

		ret
	GetPiece	ENDP

	CheckLines	PROC
		mov ax, 0
		;dec ax
		mov y, ax
		loop1:
			mov ax, y
			mov bx, 16	; each row is 16 bytes
			mul bx
			mov bx, ax	;bx now points to start of the row
			add bx, 3
			mov x, 3
			loop2:
				cmp board[bx], 0
				jng EndLoop1

				inc bx
				inc x
				cmp x, 13
			jl loop2

			; this line is full, clear it!
			inc lines
			mov ax, lines
			mov bx, 10
			cwd
			idiv bx
			cmp dx, 0		; see if user hit a new level
			mov ax, y
			push ax
			jne loop3		; not on a new level
			sub waitTicks, 2
			cmp waitTicks, 2	; speed cap
			jge loop3
			mov waitTicks, 2

			loop3:
				mov ax, y
				mov bx, 16	; each row is 16 bytes
				mul bx
				mov bx, ax	;bx now points to start of the row
				add bx, 3
				mov x, 3
				loop4:
					mov dl, board[bx-16]
					mov board[bx], dl

					inc bx
					inc x
					cmp x, 13
				jl loop4

				dec y
				cmp y, 0
			jg loop3
			mov bx, 3
			loop5:
				mov board[bx], 0

				inc bx
				cmp bx, 13
				jl loop5
			pop y

			; function lineCheck(){
				; clr = new Array();
				; for(i=0;i<height;i++){
					; failed = false;
					; for(j=0;j<width && !failed;j++){
						; if(board[j][i]==-1){
							; failed = true;
						; }
					; }
					; if(!failed){ clr.push(i); }
				; }
				; for(i=0;i<clr.length;i++){
					; for(j=clr[i];j>0;j--){
						; for(k=0;k<width;k++){
							; board[k][j] = board[k][j-1];
						; }
					; }
				; }
				; for(i=0;i<width && clr.length>0;i++){
					; board[i][0]=-1;
				; }
				; if(clr.length>0) {addScore(clr.length); }
			; }

			EndLoop1:
			inc y
			mov ax, gameH
			cmp y, ax
		jl loop1
		call drawBoard

		ret
	CheckLines	ENDP

	NewGame	PROC
		mov lines, 0
		mov waitTicks, startTicks
		mov timeCounter, startTicks

		mov ax, initX
		mov pieceX, ax
		mov ax, initY
		mov pieceY, ax

		call GetNewPiece

		ret
	NewGame	ENDP

	PauseToggle	PROC
		cmp state, PAUSED
		je unpause
		mov state, PAUSED

		; mov al, penColor
		; push ax

		; mov penColor, 0
		; add blockS, 2
		; mov ax, gameW
		; imul blockS
		; mov bx, ax

		; mov ax, gameH
		; imul blockS

		; mov cx, xOffset
		; mov dx, yOffset
		; sub cx, 1
		; sub dx, 1
		; add ax, 2
		; add bx, 2

		; call FillRect

		; sub blockS, 2

		; pop ax
		; mov penColor, al

		jmp quit
unpause:
		mov state, RUNNING
		call DrawBoard
		;_SetIntVec ClockInt, ClockHandler
quit:
		ret
	PauseToggle	ENDP

END     Main
