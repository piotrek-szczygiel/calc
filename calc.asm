; Piotr Szczygieł - Assemblery 2019
; Simple calculator
format MZ                                                   ; DOS MZ executable
stack 80h                                                   ; set stack size to 128 bytes
entry main:start                                            ; specify an application entry point

segment main
start:
    mov ax, word text
    mov ds, ax

    mov dx, str_welcome
    call print

    .loop:
        mov dx, str_prompt
        call print_no_crlf

        call read_input
        call split_input
        call validate_input

    mov al, 0
    jmp exit


; terminate the program
; AL - return code
exit:
    mov ah, 4ch
    int 21h


; check if all words are present after splitting them
validate_input:
    cmp [words.first], byte '$'
    je .invalid
    cmp [words.second], byte '$'
    je .invalid
    cmp [words.third], byte '$'
    je .invalid
    ret

    .invalid:
        mov dx, str_invalid_input
        call print
        ret


; split user input into separate words to be
; stored at words.{first, second, third}
split_input:
    mov di, words.first
    mov si, words.end
    call clear_buffer

    mov si, user_input
    mov di, words.first
    mov cl, 1
    .loop:
        mov al, byte [si]
        cmp al, '$'
        je .dollar

        cmp al, ' '
        je .space

        mov [di], al

        inc si
        inc di
        jmp .loop

        .dollar:
            mov [di], byte '$'
            ret

        .space:
            inc si
            mov [di], byte '$'
            cmp cl, 1
            je .second
            cmp cl, 2
            je .third
            ret

            .second:
                mov di, words.second
                jmp .iterate
            .third:
                mov di, words.third
            .iterate:
                inc cl
                jmp .loop


; check if two dollar terminated strings are equal
; SI - firsrt string
; DI - second string
; set ZF if equal
str_compare:
    .loop:
        mov al, byte [si]
        mov ah, byte [di]

        cmp al, ah
        jne .finish

        cmp al, byte '$'
        je .finish

        inc si
        inc di
        jmp .loop

    .finish:
        ret


; print string to stdout, add newline
; DX - dollar terminated string
print:
    mov ah, 09h
    int 21h

    mov dx, str_crlf
    int 21h
    ret


; print string to stdout, without adding a newline
; DX - dollar terminated string
print_no_crlf:
    mov ah, 09h
    int 21h
    ret


; fills the buffer with dollar signs
; DI - buffer address
; SI - address of a first byte after the buffer
clear_buffer:
    mov [di], byte '$'
    inc di
    cmp si, di
    jne clear_buffer
    ret

; read user input into user_input buffer
read_input:
    mov si, user_input.end
    mov di, user_input
    call clear_buffer

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
str_invalid_input   db 'Invalid input!$'

numbers_small       db 'zero$'
                    db 'one$'
                    db 'two$'
                    db 'three$'
                    db 'four$'
                    db 'five$'
                    db 'six$'
                    db 'seven$'
                    db 'eight$'
                    db 'nine$'

user_input.dos      db 32
user_input.len      db 0
user_input          rb 32
user_input.end:

words.first         rb 32
words.second        rb 32
words.third         rb 32
words.end:
