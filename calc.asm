; Piotr Szczygieł - Assemblery 2019
; Simple calculator

; DOS MZ executable
format MZ

; specify application entry point
entry main:start

; set stack size to 256 bytes
stack 256

; main code segment
segment main

    ; application entry point
    start:

        ; initialize the data segment
        mov ax, word text
        mov ds, ax

        ; display the welcome string
        mov dx, word string_welcome
        call print

        ; display the prompt
        mov dx, word string_prompt
        call print

        ; read user input
        mov dx, word string_input
        call read

        ; new line
        mov dx, word string_newline
        call print

        ; echo user input
        mov dx, word string_input
        call print

        ; new line
        mov dx, word string_newline
        call print

        ; exit the application with error code 0
        mov al, 0
        call exit


    ; print string passed in DX
    print:
        mov bx, dx
        add dx, 2
        mov cl, byte [bx + 1]
        xor ch, ch
        mov bx, 1   ; stdout
        mov ah, 40h
        int 21h
        ret


    ; read from standard input to buffer passed in DX
    read:
        mov ah, 0ah
        int 21h
        ret


    ; exit application with status code passed in AL
    exit:
        mov ah, 4ch
        int 21h
        ret


; data segment
segment text

    string_welcome      db 33, 33, 'Welcome to simple calculator!', 13, 10, 13, 10
    string_prompt       db 2, 2, '> '
    string_newline      db 2, 2, 13, 10

    string_input        db 32   ; maximum length of user input
                        db 0    ; actual length
                        rb 32   ; reserve 32 bytes
