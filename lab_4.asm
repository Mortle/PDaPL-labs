.model small

.stack 100h

.data
	snake	dw 0101h, 0102h, 0103h, 0104h, 0105h, 7CCh dup('?')
	cycle_pause_length dw 0FFFFh
	score db  0
	score_inc db  0
	speed_level  db  0
	up_speed_key equ 4Eh
	down_speed_key equ 4Ah
	move_up_key  equ 48h
	move_down_key equ 50h
	move_left_key equ 4Bh
	move_right_key equ 4Dh
	exit_key equ 01h
	start_position dw 0
	empty_line db ' ', 1Fh
	output_line_size equ 14

.code
	cycle_pause proc
	  push cx
		mov cx, 0
		mov dx, cycle_pause_length ; 10 milliseconds * cycle_pause_length
	  mov ah, 86h
		int 15h
		pop cx
		ret
	cycle_pause endp

	check_wall_collision proc
		cmp dl, 15h
		jne check_left
		mov dl, 01h
		jmp check_cur
		check_left:
			cmp dl,0
			jne check_up
			mov dl, 14h
			jmp check_cur
		check_up:
			cmp dh, 0
			jne check_down
			mov dh, 10h
			jmp check_cur
		check_down:
			cmp dh, 11h
			jne check_ret
			mov dh, 01h
			jmp check_cur
		check_cur:
			mov ax, 0200h
			mov [snake + si], dx
			int 10h
		check_ret:
			ret
	check_wall_collision endp

	game_over proc
		cmp al, 02h ; snake body symbol
		je collision
		ret
		collision:
		  mov ax, 4c00h
		  int 21h
	game_over endp

	process_input proc
		mov ax, 0100h
		int 16h	; check if symbol present in buffer
		jz return_
		xor ah, ah
		int 16h
		cmp ah, move_down_key
		jne up
		cmp cx, 0FF00h ; avoid going into snake head
		je return_
		mov cx, 0100h
		jmp return_

		up:
			cmp ah, move_up_key
			jne left
			cmp cx, 0100h
			je return_
			mov cx, 0FF00h
			jmp return_

		left:
			cmp ah, move_left_key
			jne right
			cmp cx, 0001h
			je return_
			mov cx, 0FFFFh
			jmp return_

		right:
			cmp ah, move_right_key
			jne increase_speed
			cmp cx, 0FFFFh
			je return_
			mov cx, 0001h
		  jmp return_

	  return_:
	    ret

		increase_speed:
			cmp ah, up_speed_key
			jne decrease_speed
			cmp speed_level, 09h
			je return
			add speed_level, 1
			sub cycle_pause_length, 1000h
			jmp change

		decrease_speed:
			cmp ah, down_speed_key
			jne exit_
			cmp speed_level, 00h
			je return
			sub speed_level, 1
			add cycle_pause_length, 1000h
			jmp change

		change:
			mov ax, 0200h
			mov dx, 1115h
			int 10h
			mov ah, 02h
			mov dl, speed_level
			add dl, '0'
			int 21h

		exit_:
			cmp ah, exit_key
			jne return
			mov ax, 4c00h
		  int 21h

		return:
			ret
	process_input endp

	draw_apple proc
		push ax
		push bx
		push cx
		push dx

		draw_apple_start:
			mov ah, 2Ch
			int 21h
			xor ax, ax
			mov al, dl
			mov dl, 13h
			div dl
			mov bl, ah ; read coordinate

		draw_apple_continue:
			mov ah, 2Ch ; time
			int 21h

			xor ax, ax
			mov al, dl

			mov dl, 0Fh
			div dl

			mov dl, bl
			mov dh, ah ; save coordinate
			add dx, 0101h

			xor bx, bx
			xor cx, cx

			mov ax, 0200h
			int 10h

			mov ax, 0800h	; read symbol (AL) & symbol attribute (AH) at current cursor position
			int 10h

			cmp al, 02h
			je draw_apple_start

		  cmp al, 40h
		  je draw_apple_start

			push cx
			mov cx, 1
			mov bl, 01110100b
			mov ax, 0923h
			int 10h

			pop cx
			pop dx
			pop cx
			pop bx
			pop ax
		ret
	draw_apple endp

	start:
		mov ax, @data
		mov ds, ax
		mov es, ax

		mov ax, 0003h ; Clear
		int	10h       ; game board

		xor bx, bx
		mov ax, 0B800h
		mov es, ax

		mov dh, 01100000b
		mov dl, 0B2h

		mov cx, 16h

		draw_upper_wall:
			mov word ptr es:[bx], dx
			add bx, 2
			loop draw_upper_wall

		mov cx, 10h

		draw_body:
			add bx, 116 ; wall piece
			mov word ptr es:[bx],dx
			push cx	; cells to draw left
			mov dh, 01110000b
			mov dl, 020h
			mov cx, 14h

		draw_body_gamezone:
			add bx, 2
			mov word ptr es:[bx], dx
			loop draw_body_gamezone

			pop cx

			mov dh, 01100000b
			mov dl, 0B2h

			add bx, 2
			mov word ptr es:[bx], dx

			add bx, 2
			loop draw_body

			add bx, 116

			mov dl, score
			add dl, '0'

		draw_score:
			mov word ptr es:[bx], dx
			add bx, 2
			mov word ptr es:[bx], dx
			add bx, 2

			mov dl, 0B2h
			mov cx, 13h

		draw_lower_wall:
			mov word ptr es:[bx], dx
			add bx, 2
			loop draw_lower_wall

			mov dl, speed_level
			add dl, '0'

		draw_speed_level:
			mov word ptr es:[bx], dx
			add bx, 2

			xor ax, ax
			xor bx, bx
			xor cx, cx
			xor dx, dx

			mov ax, 0200h
			mov dx, 0101h
			int 10h

		draw_snake:
			mov cx, 5
			mov bl, 01110000b
			mov ax, 092Ah
			int 10h

			mov si, 8			 ; Snake head
			xor di, di		 ; Snake tail
			mov cx, 0001h	 ; CX for head managing

			mov bl, 7h

			call draw_apple

		game:
			call cycle_pause

			call process_input

			xor bh, bh

			mov ax, [snake + si] ; head coord
			add ax, cx ; change x coordinate
			inc si
			inc si
			mov [snake + si], ax ; new head coordinate
			mov dx, ax
			mov ax, 0200h
			int 10h ; move cursor

			mov ax, 0800h
			int 10h

			call check_wall_collision

			call game_over

			mov ax, 0800h
			int 10h
			cmp al, 23h
			jne next
			call draw_apple
			add score, 1
			cmp score, 10
			je next_score

		back:
			mov ax,0200h ; score
			mov dx,1101h
			int 10h

			mov ah,02h
			mov dl, score
			add dl, '0'
			int 21h
			jmp game
			mov dh, al

		next_score:
			add score_inc, 1
			mov ax, 0200h ; score
			mov dx, 1100h
			int 10h

			mov ah,02h
			mov dl, score_inc
			add dl, '0'
			int 21h

			mov score, 0

			jmp back

		next_:
				mov cx, output_line_size ; cx contains number of bytes in string
				push 0B800h
				pop es ; videomemory address
				mov di, word ptr start_position  ; ES:DI
				mov si,offset empty_line       ; адрес строки в DS:SI
				cld
				rep movsb

		next:
			push cx
			mov cx, 1
			mov bl, 01110000b
			mov ax, 0902h
			int 10h
			pop cx

			mov ax,0200h
			mov dx, [snake + di]
			int 10h
			mov ax,0200h
			mov dl,0020h
			int 21h	; space replaces tail element
			inc di
			inc di
		jmp game
	end	start
