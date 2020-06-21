.model tiny
org 100h
rezSize equ start - $

jmp start

id db "prog"
res_flag db 0
old_timer_interrupt dd ?
old_keyboard_interrupt dd ?

screen_buffer db 81 dup ('$')
cmdl              db  127 dup(0); whole command line
file_path            db  127 + 2 dup(0)
file_id dw 0
print_require db 0
reset_require db 0
p equ 19h
cannot_create_file_str db "Cannot create file", 10, 13 
key_letter db 2 dup(?)
wrong_args_cmdl db "Wrong command line arguments. Usage: first arg - filename; second arg: 1 - ctrl+p, 2 - ctrl+f, 3 - ctrl+l;"  , '$'
begin_program db "Program started", '$', 10, 13
resident_str db "Program is resident now", 10, 13, "Press ctrl+z to return old interrupts" , '$'
already_exec_str db "Program is already running.", '$'
endl db 10, 13, '$'               

output_str macro str
  	mov ah, 09h
	mov dx, offset str
	int 21h       
endm

create_new_file proc
    pusha
        mov ah, 3ch;create or open existing file
        mov cx, 0 
        lea dx, file_path
        int 21h
        mov file_id, ax
        jnc proc_exit
        ;output_str   
proc_exit:               
    popa
    ret
create_new_file endp 
 
write_whole_buffer proc
    pusha
        lea dx, screen_buffer      
        mov bx, file_id
        mov cx, ax
        mov ah, 40h   
        int 21h
    popa
    ret  
write_whole_buffer endp  
 
new_timer_interrupt proc far
    pusha
    push ds
    push es
    
    mov ax, cs; code segment to data segment
    mov ds, ax
    
    cmp reset_require, 1; check if user require to restore interrupts handlers ??
    jne noNeedReset
    
    ;return old interrupts handlers
    mov ah, 25h
    mov al, 08h    
    mov dx, cs:old_timer_interrupt
    mov ds, cs:old_timer_interrupt + 2
    int 21h
    
    mov ah, 25h
    mov al, 09h    
    mov dx, cs:old_keyboard_interrupt
    mov ds, cs:old_keyboard_interrupt + 2
    int 21h
    
    mov ax, cs
    mov es, ax
    jmp end_interrupt

    ;if interrupts were not restore
noNeedReset:
cmp print_require,1
jne end_interrupt    
   cli   ; ban interrupts  
   pushf   
   pusha                
    ;to be resident
   push ds
   push es
   ; setting ds-register on data of resident program
   push cs
   pop ds   
   
   call cs:create_new_file
       
   push 0B800h  ;
   pop es ;set es-segment to begin of videomemory , es = B800h 

   xor cx, cx 
   mov di, offset screen_buffer
   ; in ax the general amount of symbols
   xor ax, ax    
character_recording:
      
        cmp al, 80; we will be print our console string by string
        jae write_buffer ;>= 
    
        cmp cx, 4000 ;when we will go all console leave handler
        jae exit_handler  
        
 usual:       
        mov bx, cx;
        ;mov symbol from console to screen_buffer
        push es:[bx]
        pop  cs:[di] ;cs:[di] = es:[bx]
        
        ;go to next symbol skipping attribute
        add cx, 2
        inc di 
        inc ax                                       
    jmp character_recording 

write_buffer:
       ;we need to set new_line symbol and car_return symbol in the end of the line
process_buf:
        mov ax, cs
	    mov ds, ax
        push si
        push di
        push ax
        push bx
        push cx 
        mov cx, 79
        xor si, si
        mov di, offset screen_buffer
        xor bl, bl
add_car:
        mov ah, [di]
        mov byte ptr screen_buffer[si], ah
        ;cmp bl, 79 
        inc bl
        inc si
        add di, 1
loop add_car
        ;add new line symbol and car_return symbol
        ;jne continue
        mov byte ptr screen_buffer[si], 0Dh
        mov byte ptr screen_buffer[si+1], 0Ah
        inc si 
        inc si
        mov bl, -1        
        
        pop cx
        pop bx
        pop ax
        pop di
        pop si

        ;write one line                        	    
        mov ax, 81
        call write_whole_buffer
        ;continue write lines
        xor ax, ax
        mov di, offset screen_buffer                        
   jmp character_recording 
     
exit_handler:
   call close_file
   pop es
   pop ds
   
   popa
   popf
   sti
   
end_interrupt:
    mov print_require, 0
    
    pushf
    call cs:dword ptr old_timer_interrupt
    
    pop es
    pop ds
    popa
    iret
new_timer_interrupt endp

new_keyboard_interrupt proc far
    pusha
        
    pushf
    call cs:dword ptr old_keyboard_interrupt
    
    mov ax, cs
	mov ds, ax
    ; get key letter 
    xor si, si
    mov di, offset key_letter
    mov dh, [di]
    
    mov ah, 01h; get scan-code from keyboard buffer 
    int 16h 
    
    mov bh, ah; remember this scan-code
    jz noKey

    mov ah, 02h;get condition of keyboard
    int 16h
    and al, 4; check if ctrl pressed
    cmp al, 0
    je noKey
    
    cmp  bh, dh 
    je to_print

not_this_keys:
    ; check ctrl+z to set
    cmp bh, 2ch
    jne noKey
    mov cs:reset_require, 1
    mov ah, 00h
    int 16h    
to_print:    
    mov cs:print_require, 1
    mov ah, 00h
    int 16h
noKey:
    
    popa 
    iret 
new_keyboard_interrupt endp

close_file proc
    pusha    
    mov bx, file_id
    xor ax, ax    
    mov ah, 3Eh    
    int 21h
    popa
    ret
close_file endp

read_cmdl proc
    push cx 
    push si
    push di
    
    xor cx, cx              ; 
	mov cl, ds:[80h]		; set len of command line
	mov bx, cx
	 		 
	mov si, 81h             ; set si in 81h because the first symbol always space
	lea di, cmdl            ; set di into begin of cmdl
	rep movsb 
        
    pop di
    pop si
    pop cx
    ret
read_cmdl endp

get_file_path proc   
    push ax 
    push cx
    push di
    xor ax,ax
    xor cx,cx
    
    mov cx, bx  
    
    lea si, cmdl          ; command line - source string 
    
    inc si
    lea di, file_path     ; file path - destination string
loop_get_path:    
    mov bl, ds:[si]
    cmp bl,' ' 
    je delim_symbol
    cmp bl, 0
    je delim_symbol
    
    mov es:[di],bl
    inc di
    inc si
loop loop_get_path    
    
delim_symbol:
     mov bl,0; symbol of the ending of the ASCIIZ string
     mov es:[di],bl; mov at the of path zero 
     inc si
     
     pop di
     pop cx
     pop ax
     ret              
get_file_path endp  

get_key_combination proc
    push ax 
    push cx
    push dx
   
    xor ax,ax
    xor cx,cx 
        
    mov cl,127   
    
    ; command line - source string
    lea di,key_letter ; file path - destination string

    mov bl, ds:[si]

    cmp bl, '1'
    je p_letter
    cmp bl, '2'
    je f_letter
    cmp bl, '3'
    je l_letter         
    
    jmp out_proc
p_letter:
     mov es:[di],19h
     inc si
     cmp ds:[si],0
     jne wrong_number
     jmp out_proc  
f_letter: 
     mov es:[di],21h
     inc si
     cmp ds:[si],0
     jne wrong_number
     jmp out_proc 
l_letter: 
     mov es:[di],26h
     inc si
     cmp ds:[si],0
     jne wrong_number
     jmp out_proc 
wrong_number:
     mov es:[di],0
     jmp out_proc     
out_proc:     
     pop dx
     pop cx                                  
     pop ax                                          
     ret
endp    

str_len proc
    push cx                   
	push bx                     
	push si                       
	xor ax, ax                 
count_len:                  
     mov bl, ds:[si]; while not zero          
	 cmp bl,  0            
	 je end_count_len             
	 inc si                
	 inc ax                                                                    
jmp count_len           
	                            
end_count_len:               
	pop si                      
	pop bx
	pop cx                      
	ret                         
str_len endp

start:
    call read_cmdl
    push si  
    lea si, cmdl
    call str_len
    pop si
    cmp ax,0
    je  emp
    
    call get_file_path
    push si 
    lea si, file_path
    call str_len
    pop si
    cmp ax,0
   
    je  emp
    
    call get_key_combination
    push si
    lea si, key_letter
    call str_len
    pop si
    cmp ax,0
    je  emp
        
    mov ah, 35h
    mov al, 08h
    int 21h
    mov word ptr old_timer_interrupt, bx
    mov word ptr old_timer_interrupt + 2, es
    
    lea di, id      
    lea si, id
    mov cx, 4
    repe cmpsb
    je already_exec
    
    mov ah, 25h
    mov al, 08h
    mov dx, offset new_timer_interrupt
    int 21h
    
    mov ah, 35h
    mov al, 09h
    int 21h
    mov word ptr old_keyboard_interrupt, bx
    mov word ptr old_keyboard_interrupt + 2, es    
    
    mov ah, 25h
    mov al, 09h
    mov dx, offset new_keyboard_interrupt
    int 21h
    
    output_str resident_str
    ;mov res_flag, 1
    mov ax, 3100h; stay resident
    mov dx, (rezSize + 100h) / 16 + 1
    int 21h
      
emp:
    output_str wrong_args_cmdl
    jmp endProgram:
already_exec:
    output_str already_exec_str
endProgram:
    mov ah, 4ch
    int 21h                              
end start