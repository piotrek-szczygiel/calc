; Piotr Szczygieł - Assemblery 2019
; Simple calculator
format MZ                                       ; DOS MZ executable
stack 80h                                       ; set stack size to 128 bytes
entry main:start                                ; specify an application entry point

segment main
start:
    mov ax, word text
    mov ds, ax

    mov dx, str_welcome
    call print_crlf

    .loop:
        mov dx, str_prompt
        call print

        call read_input

        mov si, user_input
        mov di, command_exit
        call str_compare
        je exit

        call split_input

        call validate_unparsed_input
        jne .loop

        call parse_input

        call validate_parsed_input
        jne .loop

        call calculate_result
        call display_result
        jmp .loop


; terminate the program
; AL - return code
exit:
    mov ah, 4ch
    int 21h


display_result:
    mov dx, str_result
    call print

    cmp [result.sign], byte 0
    je .display

    .negative:
        mov dx, str_negative_result
        call print

    .display:
        mov al, byte [result]
        cmp al, byte 20
        jae .big

        .small:
            mov di, numbers_twenty.start
            call get_nth
            mov dx, di
            call print_crlf
            ret

        .big:
            call split_result
            mov al, byte [result.tens]
            sub al, byte 2
            mov di, numbers_tens.start
            call get_nth
            mov dx, di
            call print
            mov al, byte [result.units]
            cmp al, 0
            je .finish
            mov dx, str_hyphen
            call print
            mov di, numbers_ten.start
            call get_nth
            mov dx, di
            call print

    .finish:
        mov dx, str_crlf
        call print
        ret


; get N-th string from dollar delimited array
; pass beginning of a array in DI, and index in AL
; stores result in DI
get_nth:
    mov cl, 0

    .loop:
        cmp al, cl
        je .found

        call seek_after
        inc cl
        jmp .loop

    .found:
        ret



; split resulting number into tens and units
split_result:
    mov al, byte [result]
    xor ah, ah
    mov bx, 10
    div bl
    mov [result.tens], byte al
    mov [result.units], byte ah
    ret


; calculates the result of the expression
calculate_result:
    mov [result.sign], byte 0
    mov al, byte [number.first]
    mov ah, byte [number.second]
    cmp [operator], byte 0
    je .add
    cmp [operator], byte 1
    je .sub
    cmp [operator], byte 2
    je .mul
    jmp exit

    .add:
        add al, ah
        jmp .finish

    .sub:
        sub al, ah
        js .sub_negative
        jmp .finish
        .sub_negative:
            mov [result.sign], byte 1
            mov al, byte [number.first]
            sub ah, al
            mov al, ah
            jmp .finish

    .mul:
        mov dl, ah
        mul dl

    .finish:
        mov [result], al
        ret


; check if provided user input are actual two numbers
; separated by operator, display error messages if not
; set ZF if valid, unset if not
validate_parsed_input:
    cmp [number.first], byte 10
    je .invalid_first_number
    cmp [number.second], byte 10
    je .invalid_second_number
    cmp [operator], byte 3
    je .invalid_operator

    cmp al, al
    ret

    .invalid_first_number:
        mov dx, str_invalid_first_number
        jmp .invalid
    .invalid_second_number:
        mov dx, str_invalid_second_number
        jmp .invalid
    .invalid_operator:
        mov dx, str_invalid_operator
    .invalid:
        call print_crlf
        cmp sp, bp
        ret


; parse word passed in SI with match table passed in DI
; pass address terminating the table in DX
; result will be stored in CX
parse_word:
    mov bx, si
    mov cx, 0

    .loop:
        cmp di, dx
        je .finish

        mov si, bx
        call str_compare
        je .finish

        call seek_after

        inc cx
        jmp .loop

    .finish:
        ret


; seek string pointer specified in DI
; to the address after the end of it
seek_after:
    cmp [di], byte '$'
    jne .not_dollar
    jmp .dollar
    .not_dollar:
        inc di
        jmp seek_after
    .dollar:
        inc di
        ret


; parse all three words
parse_input:
    mov si, words.first
    mov di, numbers_ten.start
    mov dx, numbers_ten.end
    call parse_word
    mov [number.first], byte cl

    mov si, words.third
    mov di, numbers_ten.start
    mov dx, numbers_ten.end
    call parse_word
    mov [number.second], byte cl

    mov si, words.second
    mov di, operators.start
    mov dx, operators.end
    call parse_word
    mov [operator], byte cl
    ret


; check if all words are present after splitting them
; set the ZF if they are valid, otherwise unset it
validate_unparsed_input:
    cmp [words.first], byte '$'
    je .invalid
    cmp [words.second], byte '$'
    je .invalid
    cmp [words.third], byte '$'
    je .invalid

    cmp al, al
    ret

    .invalid:
        mov dx, str_invalid_input
        call print_crlf

        cmp sp, bp
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
print_crlf:
    mov ah, 09h
    int 21h

    mov dx, str_crlf
    int 21h
    ret


; print string to stdout, without adding a newline
; DX - dollar terminated string
print:
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
    call print
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
str_welcome                 db 'Simple ASM calculator', 13, 10
                            db 'Piotr Szczygiel 2019', 13, 10
                            db  'Type exit to terminate the program$'
str_prompt                  db  13, 10, 'Enter expression: $'
str_result                  db 'Result: $'
str_invalid_input           db 'Invalid input!$'
str_invalid_first_number    db 'Invalid first number!$'
str_invalid_second_number   db 'Invalid second number!$'
str_invalid_operator        db 'Invalid operator!$'
str_negative_result         db 'minus $'
str_hyphen                  db '-$'
str_crlf                    db 13, 10, '$'

command_exit                db 'exit$'

numbers_twenty.start:
numbers_ten.start:          db 'zero$'
                            db 'one$'
                            db 'two$'
                            db 'three$'
                            db 'four$'
                            db 'five$'
                            db 'six$'
                            db 'seven$'
                            db 'eight$'
                            db 'nine$'

numbers_ten.end:            db 'ten$'
                            db 'eleven$'
                            db 'twelve$'
                            db 'thirteen$'
                            db 'fourteen$'
                            db 'fifteen$'
                            db 'sixteen$'
                            db 'seventeen$'
                            db 'eighteen$'
                            ; 19 is impossible to obtain
numbers_twenty.end:

numbers_tens.start:         db 'twenty$'
                            db 'thirty$'
                            db 'forty$'
                            db 'fifty$'
                            db 'sixty$'
                            db 'seventy$'
                            db 'eighty$'
                            ; 81 is maximum result possible to obtain
numbers_tens.end:

operators.start:            db 'plus$'
                            db 'minus$'
                            db 'times$'
operators.end:

user_input.dos              db 20
user_input.len              db 0
user_input                  rb 20
user_input.end:

words.first                 rb 20
words.second                rb 20
words.third                 rb 20
words.end:

number.first                rb 1
number.second               rb 1

operator                    rb 1

result                      rb 1
result.sign                 rb 1
result.tens                 rb 1
result.units                rb 1
