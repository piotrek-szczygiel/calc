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

            ; read user input into string_input buffer
            call read
            mov dx, word string_newline
            call print

            ; reserve space for 6 variables
            sub esp, 12

            ; check if first word exists
            mov bx, word string_input + 1
            mov [esp + 2], bx       ; first word address
            call get_word_length
            cmp ax, 0
            je invalid_input
            mov [esp + 4], ax       ; first word length

            ; check if second word exists
            inc ax                  ; skip the space
            mov bx, word string_input + 1
            add bx, ax
            mov [esp + 6], bx       ; second word address
            call get_word_length
            cmp ax, 0
            je invalid_input
            mov [esp + 8], ax       ; second word length

            ; check if third word exists
            mov bx, word string_input + 1
            add bx, [esp + 4]       ; skip to the third word by adding to base
            add bx, [esp + 8]       ; address combined length of two previous words
            add bx, 2               ; skip two spaces
            mov [esp + 10], bx      ; third word address
            call get_word_length
            cmp ax, 0
            je invalid_input
            mov [esp + 12], ax      ; third word length

            ; display parsed words
            mov dx, [esp + 2]
            mov cx, [esp + 4]
            call print_n

            mov dx, string_newline
            call print

            mov dx, [esp + 6]
            mov cx, [esp + 8]
            call print_n

            mov dx, string_newline
            call print

            mov dx, [esp + 10]
            mov cx, [esp + 12]
            call print_n

            mov dx, string_newline
            call print

            ; clear the stack and go back to loop
            add esp, 12
            jmp main_loop

            ; display message that the input is invalid
            invalid_input:
                ; clear the stack
                add esp, 12

                ; compare input to 'exit' command
                mov si, word string_input
                mov di, word string_command_exit
                call compare
                cmp ax, 0
                je exit     ; exit the application if requested

                ; display invalid input error and jump back to loop
                mov dx, word string_invalid_input
                call print
                jmp main_loop

        finish:
            ; exit the application with error code 0
            mov al, 0
            call exit


    ; print string passed in DX
    print:
        mov bx, dx
        mov cl, byte [bx]   ; get string lenght
        xor ch, ch
        add dx, 1           ; set beginning of a string
        call print_n
        ret


    ; print string using DOS 21h interrupt
    ; BX - file handle
    ; CX - number of bytes to write
    ; DX - string
    print_n:
        mov bx, 1   ; stdout
        mov ah, 40h
        int 21h
        ret


    ; read from standard input to buffer passed in DX
    read:
        mov dx, string_input - 1            ; set string pointer
        mov cl, byte [string_input - 1]     ; get maximum length of the input
        mov bx, string_input + 1            ; set beginning address of the input for clearing

        ; fill the buffer with zeroes
        clear_loop:
            mov [bx], byte 0
            inc bx
            dec cl
            cmp cl, 0
            ja clear_loop

        ; read string using DOS 21h interrupt
        ; DX - buffer
        mov ah, 0ah
        int 21h
        ret


    ; compare two strings and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare:
        mov al, [si]    ; length of first string
        mov ah, [di]    ; length of second string

        cmp al, ah              ; compare length of both strings
        jne compare_mismatch    ; if lengths are different strings are also different

        ; position both pointers on first letter
        add si, 1
        add di, 1

        ; keep the length of the string in CL
        mov cl, al

        jmp compare_n


    ; compare CL bytes in two buffers and check if they are equal
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
    ; return AX - word length
    get_word_length:
        mov al, [string_input - 1]  ; maximum string length
        mov cx, 0                   ; character counter

        get_word_length_loop:
            mov dl, byte [bx]   ; load byte from string
            cmp dl, ' '         ; check if the word has ended
            je get_word_length_space_found
            cmp dl, 13
            je get_word_length_space_found

            ; increment the counter and move the pointer
            ; to the next character
            inc cl
            inc bx

            ; if counter hasn't yet exceeded maximum length
            ; jump to the beginning of the loop
            cmp cl, al
            jb get_word_length_loop

        mov ax, 0
        ret

        get_word_length_space_found:
            mov ax, cx
            ret


    ; exit application with status code
    ; AL - exit code
    exit:
        mov ah, 4ch
        int 21h
        ret


; data segment
segment text

    ; struct string {
    ;     byte length;
    ;     byte data[length];
    ; }

    string_welcome          db 33, 'Welcome to simple calculator!', 13, 10, 13, 10
    string_prompt           db 2, '> '
    string_newline          db 2, 13, 10
    string_invalid_input    db 16, 'Invalid input!', 13, 10
    string_command_exit     db 4, 'exit'

    ; reserve 32 bytes for reading user input using DOS interrupt
                        db 64   ; buffer length
    string_input        db 0    ; read string length
                        rb 64   ; string data
