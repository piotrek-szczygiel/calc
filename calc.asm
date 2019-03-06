; Piotr Szczygieł - Assemblery 2019
; Simple calculator
format MZ                                                   ; DOS MZ executable
stack 256                                                   ; set stack size to 256 bytes
entry main:start                                            ; specify application entry point

segment main
start:
    mov ax, word text
    mov ds, ax

    mov dx, str_welcome
    call print

    main_loop:
        mov dx, str_prompt
        call print_no_crlf

        call read_input
        call parse_input

        mov dx, parsed_input.first
        call print
        mov dx, parsed_input.second
        call print
        mov dx, parsed_input.third
        call print

    mov al, 0
    jmp exit


; terminate the program
; AL - return code
exit:
    mov ah, 4ch
    int 21h


parse_input:
    mov si, user_input
    mov di, parsed_input.first
    mov cl, 1
    .loop:
        mov al, byte [si]
        cmp al, '$'
        je .delimeter

        cmp al, ' '
        je .delimeter

        mov [di], al

        inc si
        inc di
        jmp .loop

        .delimeter:
            inc si
            mov [di], byte '$'
            cmp cl, 1
            je .first
            cmp cl, 2
            je .second
            jmp .finish

            .first:
                mov di, parsed_input.second
                jmp .iterate

            .second:
                mov di, parsed_input.third

            .iterate:
                inc cl
                jmp .loop

    .finish:
        ret


; print string to stdout, add newline
; DS:DX - dollar terminated string
print:
    mov ah, 09h
    int 21h

    mov dx, str_crlf
    int 21h
    ret


; print string to stdout, without adding a newline
; DS:DX - dollar terminated string
print_no_crlf:
    mov ah, 09h
    int 21h
    ret


; read user input into user_input buffer
read_input:
    mov dx, user_input.dos
    mov ah, 0ah
    int 21h

    call user_input_to_dollar

    mov dx, str_crlf
    call print_no_crlf
    ret


; convert user_input to dollar terminated string
user_input_to_dollar:
    mov cl, byte [user_input.len]
    xor ch, ch
    cmp cx, 0
    je .finish

    mov bx, user_input
    add bx, cx

    mov [bx], byte '$'

    .finish:
        ret



segment text
str_crlf            db 13, 10, '$'
str_welcome         db 'Simple calculator.', 13, 10, '$'
str_prompt          db 'Enter expression: $'

user_input.dos      db 32
user_input.len      db 0
user_input          rb 32

parsed_input.first  rb 32
parsed_input.second rb 32
parsed_input.third  rb 32
