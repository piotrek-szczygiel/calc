; Piotr Szczygieł - Assemblery 2019
; Simple calculator
format MZ                                                   ; DOS MZ executable
stack 256                                                   ; set stack size to 256 bytes
entry main:start                                            ; specify application entry point

segment main                                                ; main code segment
    start:                                                  ; application entry point
        mov ax, word text                                   ; initialize the data segment
        mov ds, ax

        mov dx, word string_welcome                         ; display the welcome string
        call print_string
        mov dx, word string_type_exit                       ; display 'type exit to terminate'
        call print_string

        main_loop:                                          ; main loop entry
            mov dx, word string_newline                     ; display prompt
            call print_string
            mov dx, word string_prompt
            call print_string

            call read_string_input                          ; read user keyboard input into string_input

            mov dx, word string_newline                     ; move to next line
            call print_string

            call parse_string_input                         ; parse user input
            cmp ax, 1                                       ; terminate the application if exit is entered
            je finish

            jmp main_loop

        finish:                                             ; exit application with error code 0
            mov al, 0
            jmp exit


    ; print string passed in DX
    print_string:
        mov bx, dx
        mov cl, byte [bx]                                   ; get string lenght
        xor ch, ch
        add dx, 1                                           ; point to beginning of a string
        call print_n                                        ; delegate to print_n
        ret


    ; print string using DOS 21h interrupt
    ; CX - number of bytes to write
    ; DX - string
    print_n:
        mov bx, 1                                           ; file handle - stdout
        mov ah, 40h
        int 21h
        ret


    ; read from standard input to buffer passed in DX
    read_string_input:
        mov dx, string_input - 1                            ; set string pointer
        mov cl, byte [string_input - 1]                     ; get maximum length of the input
        mov bx, string_input + 1                            ; set beginning address of the input for clearing

        clear_loop:                                         ; fill the string_input data with zeroes
            mov [bx], byte 0
            inc bx
            dec cl
            cmp cl, 0
            ja clear_loop

        mov ah, 0ah                                         ; read string using DOS 21h interrupt
        int 21h                                             ; DX - buffer
        ret


    ; compare two strings and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare_strings:
        mov al, [si]                                        ; length of first string
        mov ah, [di]                                        ; length of second string

        cmp al, ah                                          ; compare length of both strings
        jne compare_mismatch                                ; if lengths are different strings are also different

        add si, 1                                           ; position both pointers on first letter
        add di, 1

        mov cl, al                                          ; keep the length of the string in CL
        jmp compare_n                                       ; delegate to compare_n


    ; compare CL bytes in two buffers and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare_n:
        compare_loop:                                       ; loop comparing bytes one by one

            mov al, byte [si]                               ; get letter from both strings
            mov ah, byte [di]

            cmp al, ah                                      ; compare those letters
            jne compare_mismatch

            inc si                                          ; move both pointers to next character
            inc di

            dec cl                                          ; decrease loop counter
            cmp cl, 0
            ja compare_loop                                 ; continue if there are more bytes to compare

        compare_match:                                      ; return 0 if strings are equal
            mov ax, 0
            ret

        compare_mismatch:                                   ; return 1 if strings are equal
            mov ax, 1
            ret


    ; return length of the first word found - delimited by space or CR
    ; and stores it in AX
    ; BX - string
    ; return AX - word length
    get_word_length:
        mov al, [string_input - 1]                          ; maximum string length
        mov cx, 0                                           ; character counter

        get_word_length_loop:
            mov dl, byte [bx]                               ; load byte from string
            cmp dl, ' '                                     ; check if the word has ended
            je get_word_length_space_found
            cmp dl, 13                                      ; CR is also a delimiter
            je get_word_length_space_found

            inc cl                                          ; increase the counter
            inc bx                                          ; move to next byte

            cmp cl, al                                      ; if counter hasn't yet exceeded maximum length
            jb get_word_length_loop                         ; jump to the beginning of the loop

        mov ax, 0                                           ; return 0 if word hasn't been found
        ret

        get_word_length_space_found:                        ; if the space was found
            mov ax, cx                                      ; return word length
            ret


    ; parse user input stored in string_input buffer
    ; return 1 in AX if user wants to terminate the application
    parse_string_input:
        push ebp                                            ; save current base pointer
        mov ebp, esp                                        ; create stack frame
        sub esp, 12                                         ; reserve space for 6 word variables

        mov bx, word string_input + 1
        mov [esp + 2], bx                                   ; first word address
        call get_word_length                                ; check if first word exists
        cmp ax, 0
        je invalid_input
        mov [esp + 4], ax                                   ; first word length

        inc ax                                              ; skip the space
        mov bx, word string_input + 1
        add bx, ax
        mov [esp + 6], bx                                   ; second word address
        call get_word_length                                ; check if second word exists
        cmp ax, 0
        je invalid_input
        mov [esp + 8], ax                                   ; second word length

        mov bx, word string_input + 1
        add bx, [esp + 4]                                   ; skip to the third word by adding to base
        add bx, [esp + 8]                                   ; address combined length of two previous words
        add bx, 2                                           ; skip two spaces
        mov [esp + 10], bx                                  ; third word address
        call get_word_length                                ; check if third word exists
        cmp ax, 0
        je invalid_input
        mov [esp + 12], ax                                  ; third word length

        ; display parsed words
        mov dx, [esp + 2]
        mov cx, [esp + 4]
        call print_n

        mov dx, string_newline
        call print_string

        mov dx, [esp + 6]
        mov cx, [esp + 8]
        call print_n

        mov dx, string_newline
        call print_string

        mov dx, [esp + 10]
        mov cx, [esp + 12]
        call print_n

        mov dx, string_newline
        call print_string

        jmp parse_string_input_finish_normally              ; finish the cycle

        invalid_input:                                      ; display message that the input is invalid
            mov si, word string_input
            mov di, word string_command_exit
            call compare_strings                            ; compare input to 'exit' command
            cmp ax, 0
            je parse_string_input_finish_terminate          ; let the main loop know we want to terminate the program

            mov dx, word string_invalid_input               ; display invalid input error and jump back to loop
            call print_string

            jmp parse_string_input_finish_normally          ; finish the cycle without terminating

        parse_string_input_finish_normally:
            mov ax, 0                                       ; return 0 in AX to let main loop know we want to continue
            jmp parse_string_input_finish

        parse_string_input_finish_terminate:
            mov ax, 1                                       ; return 1 in AX to let main loop know we want to exit
            jmp parse_string_input_finish

        parse_string_input_finish:
            mov esp, ebp                                    ; clear current stack frame
            pop ebp                                         ; restore previous base pointer
            ret                                             ; return


    ; exit application with exit status code
    ; AL - exit code
    exit:
        mov ah, 4ch
        int 21h


; data segment
segment text

    ; struct string {
    ;     byte length;
    ;     byte data[length];
    ; }
    string_welcome          db 31, 'Welcome to simple calculator!', 13, 10
    string_type_exit        db 43, 'Type ', 39, 'exit', 39, ' to terminate the application.', 13, 10
    string_prompt           db 18, 'Enter expression> '
    string_invalid_input    db 16, 'Invalid input!', 13, 10
    string_newline          db 2, 13, 10

    string_command_exit     db 4, 'exit'

                        db 64                               ; buffer length
    string_input        db 0                                ; read string length
                        rb 64                               ; string data
