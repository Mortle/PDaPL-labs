.model tiny                                             
.code 
org 80h                  ; смещение 80h от начала PSP
console_len db ?
console db ?       
org 100h             

printStr macro string
    push dx
    push ax
    lea dx, string
    mov ah, 09H
    int 21h

    mov ah, 02h
        
    mov dl, 0Ah ; \n
    int 21h

    mov dl, 0Dh ; \r
    int 21h

    pop ax
    pop dx
    endm  
clearDTAFileName macro ; AX - длина имени файла, SI - указатель на конец имени
    local finish
    push cx

    mov cx, DTA_SIZE
    sub cx, 30
    sub cx, ax

    mov di, si
    lodsb
    cmp al, 0
    je finish
    
    mov al, 0
    rep stosb
    finish:
    pop cx
    endm
saveFileName macro DTA, fileName, offs
    local saveFileLoop, finish
    push si
    push di
    push ax
	push dx
    lea si, DTA
    add si, 1Eh     
	mov di, offs
    add di, offset fileName
    saveFileLoop:
        mov al, [si]
        cmp al, 0
        je finish
        movsb
    jmp saveFileLoop
    finish:
    mov [di], '$'    

	mov ax, di
    sub ax, offset fileName
    mov [offs], ax

	pop dx
    pop ax
    pop di
    pop si
    endm       
printError macro
    local nexte, fin, nextee
    
    cmp al, 03
    jne nexte        
    printStr pathNotFound
          
    jmp fin

    nexte: 
    cmp al, 12h
    jne fin 
    printStr accessError
    
    nextee:
    cmp al, 02h
    jne fin
    printStr fileNotFound        

    fin:         
    endm
clearCurrentDir macro 
    push ax
    push cx
    push di
    mov cx, 25
    mov al, '$'
    lea di, currentDir
    rep stosb
    pop di
    pop cx
    pop ax
    endm
printCurrentDir macro
    local finish
    push ax
    push dx
    push si
    push cx

    clearCurrentDir

    xor dx, dx
    xor ax, ax
    lea si, currentDir
    mov ah, 47h
    int 21h
    jc finish

    printStr currentDir

    finish:
    pop cx
    pop si
    pop dx
    pop ax
    endm
saveRootDir macro
    local finish
    push ax
    push dx
    push si
    xor dx, dx
    xor ax, ax
    lea si, rootDir
    add si, 3
    mov ah, 47h
    int 21h
    jnc finish
    printStr pathNotFound
    finish:
    pop si
    pop dx
    pop ax
    endm
changeDir macro newDir
    local finish
    push ax
    push dx
    mov di, 0
    mov ah, 3Bh
    lea dx, newDir
    int 21h

    jnc finish
    printError
    mov di, 1
    finish:
    pop dx
    pop ax
    endm
parseNamesToBuffer macro
	local finish, finish1, finish2, print1, print2, parseDir1Loop, parseDir2Loop
	push ax
	push cx
	push dx
	push si
	xor cx, cx
	
	; Первый каталог
	lea dx, DTA1
    mov ah, 1Ah
    int 21h

    changeDir dir1
    cmp di, 1
    je finish
    printCurrentDir

    lea dx, any
    mov ah, 4Eh
    int 21h
    jnc parseDir1Loop

	lea di, foundFileName1
    mov [di], 1
    jmp finish1
	
	parseDir1Loop: 
	    saveFileName DTA1, foundFileName1, offset1   
	    mov ah, 4Fh
		int 21h
	jnc parseDir1Loop
	finish1:
	
	
	; Второй каталог
	lea dx, DTA2
    mov ah, 1Ah
    int 21h

    changeDir dir2
    cmp di, 1
    je finish
    printCurrentDir

    lea dx, any
    mov ah, 4Eh
    int 21h
    jnc parseDir2Loop
	
	lea di, foundFileName2
    mov [di], 2
    jmp finish
	
	parseDir2Loop:
		saveFileName DTA2, foundFileName2, offset2
		mov ah, 4Fh
		int 21h
	jnc parseDir2Loop
	finish:
	pop si
	pop dx
	pop cx
	pop ax
	endm
CMPFiles macro
    local goodend, badend, finish, cmpLoop, isSecondExists, bothDidNot
    push si
    push di
    mov cx, 0
    
    lea si, foundFileName1
    lea di, foundFileName2

    cmp [si], 1
    jne isSecondExists
    cmp [di], 2
    je bothDidNot
    mov cx, 1
    jmp finish
    bothDidNot:
    jmp finish
    isSecondExists:
    cmp [di], 2
    jne cmpLoop
    mov cx, 1
    jmp finish

	cmpLoop:
		mov al, [si]
		mov ah, [di]
		cmp ah, al
		jne badend
		cmp al, '$'
		je finish
		inc si
		inc di
	jne cmpLoop
	jmp finish
	badend:
    mov cx, 1
	finish:
	pop di
    pop si
    endm
parseDirectoriesFromConsole macro
    local getPaths, finish, wrongParams
    push ax
    push si

    mov al, console_len
    cmp al, 0
    jne getPaths
    wrongParams:
    printStr noArgv
    mov di, 1
    jmp finish

    getPaths:
    lea di, console
        mov al, ' '
        repz scasb
        mov si, di
		dec si

        lea di, dir1
        savePath1:
            lodsb

            cmp al, 0Dh
            je wrongParams
            cmp al, ' '
            je p2

            stosb
        jmp savePath1
        p2:
        mov [di], 0
        inc di
        mov [di], '$'
        mov di, si

        mov al, ' '
        repz scasb

        mov si, di
        dec si
        lea di, dir2
        savePath2:
            lodsb

            cmp al, 0Dh
            je finale
            cmp al, ' '
            je wrongParams

            stosb
        jmp savePath2
    finale:
    mov [di], 0
    inc di
    mov [di], '$'
    mov di, 0

    printStr dir1
    printStr dir2

    finish:
    pop si
    pop ax
    endm
main:   
    cld    ; для команд строковой обработки
	mov di, 0
    parseDirectoriesFromConsole
	cmp di, 0
	jne finish
    saveRootDir
	parseNamesToBuffer
    changeDir rootDir
	cmp di, 1
	je finish
	CMPFiles
	cmp cx, 1
	jne Equal
	printStr directoriesNotEqual
	jmp finish
	Equal:
	printStr directoriesAreEqual
    finish:
    ret

DTA_SIZE equ 128    
DTA1 db DTA_SIZE DUP(0)
DTA2 db DTA_SIZE DUP(0)
any db "*.*", 0
dir1 db 20 DUP(0), 0
dir2 db 20 DUP(0), 0      
foundFileName1 db 1400 DUP('$')
offset1 dw 0
foundFileName2 db 1400 DUP('$')
offset2 dw 0
currentDir db 25 DUP('$')
rootDir db "C:\", 25 DUP(0), '$'

noArgv db "Wrong arguments passed!$"
pathNotFound db "Path not found!$"
fileNotFound db "File not found!$"
accessError db "Access Error!$"   
directoriesNotEqual db "Directories aren't equal$"
directoriesAreEqual db "Directories are equal$"