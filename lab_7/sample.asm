.model small    

.stack 100h         

.data               
    string      db 128 dup ('$')
    input_error db "Input Error", 10, 13, '$'

.code
    main:   
        mov ax, @data
        mov ds, ax
        
        mov cl, es:80h
        cmp cl, 0     ; в КС пусто
        je error
        
        mov di, 81h   ; начало КС
        mov al, ' '
        repe scasb    ; поиск начала аргумента
        dec di        ; адрес начала КС
        
        mov si, offset string
        
        xor bx, bx 
        
        start:   
            mov al, es:[di] ; КС
            cmp al, '$'
            je end_line
            cmp al, 0
            je end_line
            mov ds:[si], al ; запись
            inc si
            inc di
            inc bx ; длина
            jmp start
        
        end_line:
            cmp bx, 0
            jle error  
            mov ds:[si], '$'
            jmp end
        
        error:  
            mov ah, 9
            mov dx, offset input_error
            int 21h
            mov ax, 4c00h
            int 21h
            
        end:
            mov ah, 9
            mov dx, offset string
            int 21h
            mov ax, 4c00h
            int 21h
    end main
