.model small  

.data

    string             db "  ", 128 dup ('$')
    prog_name          db "sample.exe", 0
    file_name          db 128 dup ('$')

    buffer             db 1
    counter            db 1

    input_error        db "Input Error!", '$'
    file_open_error    db "File Opening Error!", '$'
    file_reading_error db "File Reading Error!", '$'
    prog_open_error    db "Program Opening Error!", '$'

    epb                dw 0
    cmd_off            dw offset string 
    cmd_seg            dw ?
    
    EPB_len dw $-epb
    dsize = $ - string    
    
.stack 100h    

.code
    process_command_line macro 
        local end,error
        push cx
        push ax
        push bx
        push di
        push si
        
        mov cl, es:80h
        cmp cl, 0
        je error
        
        mov di, 81h ; начало ком. строки в памяти
        mov al, ' '
        repe scasb
        dec di ; адрес начала командной строки
        xor si, si
        
        copy_path:
            mov al, es:[di] ; КС
            cmp al, 13 ; конец строки
            je end_line
            mov file_name[si], al ; имя файла с аргументами
            inc si
            inc di
            jmp copy_path
        
        end_line:
            mov file_name[si], 0
            jmp end
        
        error:
            mov ah, 9
            mov dx, offset input_error
            int 21h
            jmp program_end
        
        end:
            pop si
            pop di
            pop bx
            pop ax
            pop cx
    process_command_line endm

    main:
        xor ax, ax
        mov ah, 4ah 
        mov bx,(csize / 16) + 17
        add bx,(dsize / 16) + 17
        inc bx
        int 21h
        
        mov ax, @data
        mov ds, ax
        
        process_command_line
        
        mov ax, @data
        mov es, ax
        mov cmd_seg, ax
        
        mov dx, offset file_name
        mov ah, 3dh
        mov al, 00 ; read-only
        int 21h
        jc fopen_error
        
        mov bx, ax ; дескриптор файла
        mov si, 2 ; запас для длины
        mov counter, 1 ; длина  
        
        read:
            mov cx,1
            mov dx, offset buffer ; символ -> буфер
            mov ah, 3fh
            int 21h
            jc read_error
            cmp ax, 0
            je read_end
        
            mov al, buffer
            cmp al, 13
            je next      
            
            cmp al,10
            je read
            mov string[si],al
            inc si
            inc counter
            jmp read
        
        next:
            mov string[si], ' '
            inc si
            inc counter
            jmp read
        
        read_end:
            mov ah, 3eh
            int 21h
        
            mov dl, counter ; размер КС
            mov string[0], dl
        
            mov bx, offset epb
            mov dx, offset prog_name
            mov ax, 4b00h ; загрузка и запуск программы
            int 21h
            jb prog_error
            jmp program_end
        
        read_error:
            mov ah, 9
            mov dx, offset file_reading_error
            int 21h
            jmp program_end  
        
        fopen_error:
            mov ah,9
            mov dx,offset file_open_error
            int 21h
            jmp program_end
        
        prog_error:
            mov ah,9
            mov dx,offset prog_open_error
            int 21h
        
        program_end:
            mov ax, 4c00h
            int 21h 
    csize=$-main
    end main
