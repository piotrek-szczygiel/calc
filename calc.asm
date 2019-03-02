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

        main_loop:
            ; display the prompt
            mov dx, word string_prompt
            call print

            ; read user input
            mov dx, word string_input
            call read

            ; new line
            mov dx, word string_newline
            call print

            mov dx, word string_input
            call print

            mov dx, word string_newline
            call print

            ; parsing
            mov ax, 32
            mov bx, word string_input + 2
            call get_word_length
            call exit

            cmp ax, 4
            je finish

            mov dx, word string_failure
            call print


        finish:
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


    ; compare two strings and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare:
        mov al, [si + 1]    ; length of first string
        mov ah, [di + 1]    ; length of second string

        cmp al, ah              ; compare length of both strings
        jne compare_mismatch    ; if lengths are different strings are also different

        ; position both pointers on first letter
        add si, 2
        add di, 2

        ; keep the length of the string in CL
        mov cl, al

        jmp compare_n


    ; compare CL bytes in two strings and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare_n:
        ; compare characters one by one
        compare_loop:
            ; get letter from both strings
            mov al, byte [si]
            mov ah, byte [di]

            ; compare those letters
            cmp al, ah
            jne compare_mismatch

            ; move both pointers to next character
            inc si
            inc di

            ; decrease loop counter
            dec cl
            cmp cl, 0

            ; if not every character has been compared
            ja compare_loop

        ; strings are equal - return 0
        compare_match:
            mov ax, 0
            ret

        ; strings are different - return 1
        compare_mismatch:
            mov ax, 1
            ret


    ; return length of the first word found
    ; and stores it in AX
    ; BX - string
    ; AX - maximum string length
    ; return AX - word length
    get_word_length:
        mov cx, 0   ; character counter

        get_word_length_loop:
            mov dl, byte [bx]   ; load byte from string
            cmp dl, ' '         ; check if the word has ended
            je get_word_length_space_found

            ; increment the counter and move the pointer
            ; to the next character
            inc cx
            inc bx

            ; if counter hasn't yet exceeded maximum length
            ; jump to the beginning of the loop
            cmp cx, ax
            jb get_word_length_loop

        mov ax, 0
        ret

        get_word_length_space_found:
            mov ax, cx
            ret

    parse_input:
        sub esp, 16


    ; exit application with status code
    ; AL - exit code
    exit:
        mov ah, 4ch
        int 21h
        ret


; data segment
segment text

    ; my string data structure looks like this
    ;
    ; struct string {
    ;     byte capacity;
    ;     byte length;
    ;     byte data[capacity];
    ; }

    string_welcome      db 33, 33, 'Welcome to simple calculator!', 13, 10, 13, 10
    string_prompt       db 2, 2, '> '
    string_newline      db 2, 2, 13, 10
    string_failure      db 6, 6, 'fail', 13, 10

    string_test         db 4, 4, 'test'

    ; reserve 32 bytes for user input
    string_input        db 32
                        db 0
                        times 32 db 0
