; Piotr Szczygieł - Assemblery 2019
; Simple calculator
format MZ                                                   ; DOS MZ executable
stack 256                                                   ; set stack size to 256 bytes
entry main:start                                            ; specify application entry point

segment main                                                ; main code segment
    start:                                                  ; application entry point
        mov     ax, word text                               ; initialize the data segment
        mov     ds, ax

        mov     dx, word string_welcome                     ; display the welcome string
        call    print_string
        mov     dx, word string_type_exit                   ; display 'type exit to terminate'
        call    print_string

        sub esp, 6                                          ; allocate stack for 4 word variables
        mov [esp + 2], word 10                              ; first number
        mov [esp + 4], word 10                              ; second number
        mov [esp + 6], word 10                              ; operator
        main_loop:                                          ; main loop entry
            mov     dx, word string_newline                 ; display prompt
            call    print_string
            mov     dx, word string_prompt
            call    print_string

            call    read_string_input                       ; read user keyboard input into string_input

            mov     dx, word string_newline                 ; move to next line
            call    print_string

            call    parse_string_input                      ; parse user input
            jc      finish                                  ; terminate program if exit was entered

            cmp cx, 3
            jne main_loop

            mov     [esp + 2], ax                           ; first number
            mov     [esp + 4], dx                           ; second number
            mov     [esp + 6], bx                           ; operator

            cmp     [esp + 2], word 10                      ; print error messages
            je      print_invalid_first
            cmp     [esp + 4], word 10
            je      print_invalid_second
            cmp     [esp + 6], word 10
            je      print_invalid_operator

            cmp     cx, 1                                   ; perform selected calculation
            je      operation_add
            cmp     cx, 2
            je      operation_subtract
            cmp     cx, 3
            je      operation_multiply

            print_invalid_first:
                mov     dx, word string_invalid_first
                call    print_string
                jmp     main_loop

            print_invalid_second:
                mov     dx, word string_invalid_second
                call    print_string
                jmp     main_loop

            print_invalid_operator:
                mov     dx, word string_invalid_operator
                call    print_string
                jmp     main_loop

            operation_add:
            operation_subtract:
            operation_multiply:

            jmp     main_loop

        finish:
            add     esp, 6                                  ; clear the stack
            mov     al, 0                                   ; exit program with error code 0
            jmp     exit


    ; print string passed in DX
    print_string:
        mov     bx, dx
        mov     cl, byte [bx]                               ; get string lenght
        xor     ch, ch
        add     dx, 1                                       ; point to beginning of a string
        call    print_n                                     ; delegate to print_n
        ret


    ; print string using DOS 21h interrupt
    ; CX - number of bytes to write
    ; DX - string
    print_n:
        mov     bx, 1                                       ; file handle - stdout
        mov     ah, 40h
        int     21h
        ret


    ; read from standard input to buffer passed in DX
    read_string_input:
        mov     dx, word string_input - 1                   ; set string pointer
        mov     cl, byte [string_input - 1]                 ; get maximum length of the input
        mov     bx, word string_input + 1                   ; set beginning address of the input for clearing

        clear_loop:                                         ; fill the string_input data with zeroes
            mov     [bx], byte 0
            inc     bx
            dec     cl
            cmp     cl, 0
            ja      clear_loop

        mov     ah, 0ah                                     ; read string using DOS 21h interrupt
        int     21h                                         ; DX - buffer
        ret


    ; compare two strings and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare_strings:
        mov     al, byte [si]                               ; length of first string
        mov     ah, byte [di]                               ; length of second string

        cmp     al, ah                                      ; compare length of both strings
        jne     compare_mismatch                            ; if lengths are different strings are also different

        add     si, 1                                       ; position both pointers on first letter
        add     di, 1

        mov     cl, al                                      ; keep the length of the string in CL
        jmp     compare_n                                   ; delegate to compare_n


    ; compare CL bytes in two buffers and check if they are equal
    ; strings are pointed by SI and DI
    ; stores result in AX
    ; 0 - strings are the same
    ; 1 - strings are different
    compare_n:
        compare_loop:                                       ; loop comparing bytes one by one

            mov     al, byte [si]                           ; get letter from both strings
            mov     ah, byte [di]

            cmp     al, ah                                  ; compare those letters
            jne     compare_mismatch

            inc     si                                      ; move both pointers to next character
            inc     di

            dec     cl                                      ; decrease loop counter
            cmp     cl, 0
            ja      compare_loop                            ; continue if there are more bytes to compare

        compare_match:                                      ; return 0 if strings are equal
            mov     ax, 0
            ret

        compare_mismatch:                                   ; return 1 if strings are equal
            mov     ax, 1
            ret


    ; return length of the first word found - delimited by space or CR
    ; and stores it in AX
    ; BX - string
    ; return AX - word length
    get_word_length:
        mov     al, byte [string_input - 1]                 ; maximum string length
        mov     cx, 0                                       ; character counter

        get_word_length_loop:
            mov     dl, byte [bx]                           ; load byte from string
            cmp     dl, ' '                                 ; check if the word has ended
            je      get_word_length_space_found
            cmp     dl, 13                                  ; CR is also a delimiter
            je      get_word_length_space_found

            inc     cl                                      ; increase the counter
            inc     bx                                      ; move to next byte

            cmp     cl, al                                  ; if counter hasn't yet exceeded maximum length
            jb      get_word_length_loop                    ; jump to the beginning of the loop

        mov     ax, 0                                       ; return 0 if word hasn't been found
        ret

        get_word_length_space_found:                        ; if the space was found
            mov     ax, cx                                  ; return word length
            ret


    ; parse user input stored in string_input buffer
    ; set carry flag if user wants to terminate the program
    ; return word counter in CX
    ; return first number in AX
    ; return second number in DX
    ; return operator in BX:
    ; 1 - plus
    ; 2 - minus
    ; 3 - times
    parse_string_input:
        push    ebp                                         ; save current base pointer
        mov     ebp, esp                                    ; create stack frame
        sub     esp, 24                                     ; reserve space for 12 word variables

        mov     [esp + 24], word 0                          ; no words are present yet

        mov     bx, word string_input + 1
        mov     [esp + 2], word bx                          ; first word address
        call    get_word_length                             ; check if first word exists
        cmp     ax, 0
        je      invalid_input
        mov     [esp + 4], word ax                          ; first word length
        mov     [esp + 24], word 1                          ; one word is present

        inc     ax                                          ; skip the space
        mov     bx, word string_input + 1
        add     bx, ax
        mov     [esp + 6], word bx                          ; second word address
        call    get_word_length                             ; check if second word exists
        cmp     ax, 0
        je      invalid_input
        mov     [esp + 8], ax                               ; second word length
        mov     [esp + 24], word 2                          ; second word is present

        mov     bx, word string_input + 1
        add     bx, word [esp + 4]                          ; skip to the third word by adding to base
        add     bx, word [esp + 8]                          ; address combined length of two previous words
        add     bx, 2                                       ; skip two spaces
        mov     [esp + 10], word bx                         ; third word address
        call    get_word_length                             ; check if third word exists
        cmp     ax, 0
        je      invalid_input
        mov     [esp + 12], word ax                         ; third word length
        mov     [esp + 24], word 3                          ; third word is present

        mov     bx, [esp + 2]
        mov     [esp + 14], bx                              ; current word address
        mov     bx, [esp + 4]
        mov     [esp + 16], bx                              ; current word length

        mov     [esp + 18], word 10                         ; first number, 10 means undefined
        mov     [esp + 20], word 10                         ; second number
        mov     [esp + 22], word 10                         ; operator

        mov     bx, string_zero                             ; store address to current analyzed number in BX
        number_compare_loop:                                ; word comparing loop
            cmp     byte [bx], 0                            ; check if all the numbers have been checked
            je      invalid_input                           ; none of the numbers matched

            mov     ax, word [esp + 16]                     ; compare length of input with length of current
            mov     cl, byte [bx]                           ; number being analyzed
            xor     ch, ch
            cmp     ax, cx
            jne     wrong_number

            mov     si, word [esp + 14]                     ; if words are the same length compare them
            mov     di, word bx                             ; byte by byte
            inc     di
            call    compare_n
            cmp     ax, 0
            je      number_compare_loop_found               ; comparison was successful

            wrong_number:                                   ; no match in this iteration
                add     bl, byte [bx]
                add     bx, 2
                jmp     number_compare_loop

            number_compare_loop_found:                      ; number matched to current word
                add     bl, byte [bx]                       ; move to the end of the found word
                inc     bx                                  ; where the number value is stored
                xor     ah, ah
                mov     al, byte [bx]                       ; and store it on stack

                cmp     [esp + 18], word 10                 ; if first number is undefined
                je      first_number
                cmp     [esp + 20], word 10                 ; if second number is undefined
                je      second_number
                cmp     [esp + 22], word 10                 ; if operator is undefined
                je      operator

                first_number:
                    mov     [esp + 18], ax                  ; first parsed number

                    mov     bx, [esp + 10]                  ; do the parsing loop again for third word
                    mov     [esp + 14], bx
                    mov     bx, [esp + 12]
                    mov     [esp + 16], bx
                    mov     bx, string_zero                 ; reset number address
                    jmp     number_compare_loop

                second_number:
                    mov     [esp + 20], ax                  ; second parsed number

                    mov     bx, [esp + 6]                   ; do the parsing loop again for second word
                    mov     [esp + 14], bx
                    mov     bx, [esp + 8]
                    mov     [esp + 16], bx
                    mov     bx, string_operator_plus
                    jmp     number_compare_loop

                operator:
                    mov     [esp + 22], ax                  ; operator

        jmp     parse_string_input_finish_normally          ; finish the cycle

        invalid_input:                                      ; display message that the input is invalid
            mov     si, word string_input
            mov     di, word string_command_exit
            call    compare_strings                         ; compare input to 'exit' command
            cmp     ax, 0
            je      parse_string_input_finish_terminate     ; let the main loop know we want to terminate the program

            mov     dx, word string_invalid_input           ; display invalid input error and jump back to loop
            call    print_string

            jmp     parse_string_input_finish_normally      ; finish the cycle without terminating

        parse_string_input_finish_normally:
            mov     ax, [esp + 18]                          ; first number
            mov     bx, [esp + 22]                          ; operator
            mov     cx, [esp + 24]                          ; word counter
            mov     dx, [esp + 20]                          ; second number

            clc                                             ; cleared carry flag means user wants to continue
            jmp     parse_string_input_finish

        parse_string_input_finish_terminate:
            stc                                             ; set carry flag means user wants to terminate the program
            jmp     parse_string_input_finish

        parse_string_input_finish:
            mov     esp, ebp                                ; clear current stack frame
            pop     ebp                                     ; restore previous base pointer
            ret                                             ; return


    ; exit application with exit status code
    ; AL - exit code
    exit:
        mov     ah, 4ch
        int     21h


; data segment
segment text

    ; struct string {
    ;     byte length;
    ;     byte data[length];
    ; }
    string_welcome          db 31, 'Welcome to simple calculator!', 13, 10
    string_type_exit        db 43, 'Type ', 39, 'exit', 39, ' to terminate the application.', 13, 10
    string_prompt           db 18, 'Enter expression: '
    string_invalid_input    db 16, 'Invalid input!', 13, 10
    string_invalid_first    db 23, 'Invalid first number!', 13, 10
    string_invalid_second   db 24, 'Invalid second number!', 13, 10
    string_invalid_operator db 19, 'Invalid operator!', 13, 10
    string_newline          db 2, 13, 10

    string_command_exit     db 4, 'exit'

    string_zero             db 4, 'zero', 0
    string_one              db 3, 'one', 1
    string_two              db 3, 'two', 2
    string_three            db 5, 'three', 3
    string_four             db 4, 'four', 4
    string_five             db 4, 'five', 5
    string_six              db 3, 'six', 6
    string_seven            db 5, 'seven', 7
    string_eight            db 5, 'eight', 8
    string_nine             db 4, 'nine', 9
    string_numbers_end      db 0

    string_operator_plus    db 4, 'plus', 1
    string_operator_minus   db 5, 'minus', 2
    string_operator_times   db 5, 'times', 3
    string_operators_end    db 0

numbers_end:

                            db 64                           ; buffer length
    string_input            db 0                            ; read string length
                            rb 64                           ; string data
