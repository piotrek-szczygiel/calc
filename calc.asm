; Simple calculator
; Piotr Szczygieł - Assemblery 2019
format MZ                                   ; DOS MZ executable
stack 32                                    ; set stack size to 32 bytes
entry main:start                            ; specify an application entry point

segment main
start:                                      ; entry point
    mov ax, word text                       ; show program
    mov ds, ax                              ; where the data segment is

    mov dx, str_welcome
    call print_crlf

    .loop:                                  ; main program loop
        mov dx, str_prompt
        call print

        call read_input

        mov si, user_input                  ; terminate the program
        mov di, command_exit                ; if user entered the 'exit'
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


; Terminate the program.
; AL - return code
exit:
    mov ah, 4ch                             ; terminates the program by
    int 21h                                 ; invoking DOS interruption


; Display the calculated result.
display_result:
    mov dx, str_result                      ; print the result prefix
    call print

    cmp [result.sign], byte 0               ; jump straight to displaying
    je .display                             ; if the number is positive

    .negative:
        mov dx, str_negative_result         ; otherwise display the
        call print                          ; negative number prefix

    .display:
        mov al, byte [result]               ; check if the number is lower
        cmp al, byte 20                     ; or higher than 20
        jae .big

        .small:
            mov di, numbers_twenty.start    ; for numbers lower than 20
            call get_nth                    ; just print the result as
            mov dx, di                      ; N-th index of the
            call print_crlf                 ; numbers_twenty array
            ret

        .big:
            call split_result               ; for numbers bigger than 20
            mov al, byte [result.tens]      ; first split the result into
            sub al, byte 2                  ; tens and units
            mov di, numbers_tens.start      ; and than do the same
            call get_nth                    ; get the N-th index of the
            mov dx, di                      ; tens array and print it
            call print

            mov al, byte [result.units]     ; if the units are 0
            cmp al, 0                       ; we don't have to display
            je .finish                      ; anything more

            mov dx, str_hyphen              ; otherwise display a hyphen
            call print

            mov di, numbers_ten.start       ; display the units same way
            call get_nth
            mov dx, di
            call print

    .finish:
        mov dx, str_crlf                    ; end result with a new line
        call print
        ret


; Get N-th string from dollar delimited
; array. DI - beginning of an array,
; AL - element index. DI - result.
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



; Split resulting number into
; tens and units.
split_result:
    mov al, byte [result]
    xor ah, ah
    mov bx, 10
    div bl
    mov [result.tens], byte al
    mov [result.units], byte ah
    ret


; Calculate a result of the expression.
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


; Check if provided user input are actual
; two numbers separated by an operator.
; Display error messages if not.
; Set ZF if valid, unset otherwise.
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


; Parse word passed in SI with match table
; passed in DI. DX - address terminating
; the table, CX - result.
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


; Seek string pointer specified in DI
; to the address after the end of it.
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


; Parse all three words.
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


; Check if all words are present after
; splitting them. Set the ZF if they are
; valid, otherwise unset it.
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


; Split user input into separate words.
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


; Check if two dollar terminated strings
; are equal. SI - first string,
; DI - second string. Set ZF if equal,
; unset it otherwise.
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


; Print string to stdout, add a newline.
; DX - dollar terminated string.
print_crlf:
    mov ah, 09h
    int 21h

    mov dx, str_crlf
    int 21h
    ret


; Print string to stdout, without adding
; a newline. DX - dollar terminated string
print:
    mov ah, 09h
    int 21h
    ret


; Fills the buffer with dollar signs.
; DI - buffer address, SI - address of
; a first byte after the buffer.
clear_buffer:
    mov [di], byte '$'
    inc di
    cmp si, di
    jne clear_buffer
    ret

; Read user input into user_input buffer.
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


; Convert user_input to dollar terminated
; string.
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
