; vim: syntax=fasm
; Simple calculator
; Piotr Szczygieł - Assemblery 2019
format MZ                                   ; DOS MZ executable
entry main:start                            ; specify an application entry point

segment main
start:
    mov ax, word stack1                     ; point program where the
    mov ss, ax                              ; stack segment is
    mov sp, word stack1_end

    mov ax, word text1                      ; point program where the
    mov ds, ax                              ; data segment is

    mov dx, word str_welcome
    call print_crlf

    .loop:                                  ; main program loop
        mov dx, word str_prompt
        call print

        call read_input

        mov si, word user_input             ; terminate the program
        mov di, word command_exit           ; if user entered the 'exit'
        call str_compare
        je exit

        call split_input

        call validate_three_words
        jne .loop

        call parse_input

        call validate_parsed_input
        jne .loop

        call calculate_result
        call display_result
        jmp .loop


; Terminate the program with 0 exit code.
exit:
    mov ax, 4c00h                           ; terminates the program by
    int 21h                                 ; invoking DOS interruption


; Display the calculated result.
display_result:
    mov dx, word str_result                 ; print the result prefix
    call print

    cmp [result.sign], byte 0               ; jump straight to displaying
    je .display                             ; if the number is positive

    .negative:
        mov dx, word str_negative_result    ; otherwise display the
        call print                          ; negative number prefix

    .display:
        mov al, byte [result]               ; check if the number is lower
        cmp al, byte 20                     ; or higher than 20
        jae .big

        .small:
            mov di, word numbers.start      ; for numbers lower than 20
            call get_nth                    ; just print the result as
            mov dx, di                      ; N-th index of the
            call print_crlf                 ; numbers_twenty array
            ret

        .big:
            call split_result               ; for numbers bigger than 20
            mov al, byte [result.tens]      ; first split the result into
            sub al, byte 2                  ; tens and units
            mov di, word numbers_tens.start ; and than do the same
            call get_nth                    ; get the N-th index of the
            mov dx, di                      ; tens array and print it
            call print

            mov al, byte [result.units]     ; if the units are 0
            cmp al, 0                       ; we don't have to display
            je .finish                      ; anything more

            mov dx, word str_hyphen         ; otherwise display a hyphen
            call print

            mov di, word numbers.start      ; display the units same way
            call get_nth
            mov dx, di
            call print

    .finish:
        mov dx, word str_crlf               ; end result with a new line
        call print
        ret


; Get N-th string from dollar delimited
; array. DI - beginning of an array,
; AL - element index. DI - result.
get_nth:
    mov cl, 0                               ; element counter

    .loop:
        cmp al, cl                          ; if N == counter
        je .found

        call seek_after                     ; seek DI to next element
        inc cl
        jmp .loop

    .found:                                 ; the result is just returned
        ret                                 ; in the DI



; Split resulting number into
; tens and units.
split_result:
    mov al, byte [result]                   ; move result into AX
    xor ah, ah

    mov bx, 10                              ; divide the result by 10
    div bl

    mov [result.tens], byte al              ; store tens and units
    mov [result.units], byte ah
    ret


; Calculate a result of the expression.
calculate_result:
    mov [result.sign], byte 0               ; clear the result sign

    mov al, byte [number.first]             ; get both numbers
    mov ah, byte [number.second]

    cmp [operator], byte 0                  ; perform operations accordingly
    je .add
    cmp [operator], byte 1
    je .sub
    cmp [operator], byte 2
    je .mul

    .add:
        add al, ah
        jmp .finish

    .sub:
        sub al, ah
        js .sub_negative                    ; if SIGN flag is set
        jmp .finish

        .sub_negative:
            mov [result.sign], byte 1       ; set the result sign
            mov al, byte [number.first]
            sub ah, al                      ; switch the numbers in subtraction
            mov al, ah                      ; to make the result positive
            jmp .finish

    .mul:
        mov dl, ah
        mul dl

    .finish:                                ; move the result into memory
        mov [result], byte al
        ret


; Check if provided user input are actual
; two numbers separated by an operator.
; Display error messages if not.
; Set ZF if valid, unset otherwise.
validate_parsed_input:
    cmp [number.first], byte 10             ; if any of the provided words
    je .invalid_first_number                ; are invalid, show corresponding
    cmp [number.second], byte 10            ; error messages
    je .invalid_second_number
    cmp [operator], byte 3
    je .invalid_operator

    cmp al, al                              ; set the ZF flag
    ret

    .invalid_first_number:
        mov dx, word str_invalid_first_number
        jmp .invalid
    .invalid_second_number:
        mov dx, word str_invalid_second_number
        jmp .invalid
    .invalid_operator:
        mov dx, word str_invalid_operator
    .invalid:
        call print_crlf                     ; display new line
        cmp sp, bp                          ; unset the ZF flag
        ret


; Parse word passed in SI with match table
; passed in DI. DX - address terminating
; the table, CX - result.
parse_word:
    mov bx, si                              ; remember the word address
    mov cx, 0                               ; element counter

    .loop:
        cmp di, dx                          ; if we reached the end
        je .finish                          ; of an array

        mov si, bx                          ; compare word with a current
        call str_compare                    ; element in an array
        je .finish                          ; and finish on success

        call seek_after                     ; go to the next array element
        inc cx
        jmp .loop

    .finish:
        ret


; Seek string pointer specified in DI
; to the address after the end of it.
seek_after:
    cmp [di], byte '$'                      ; check if current char is a dollar
    jne .other

    .dollar:
        inc di                              ; if yes, than seek to the next
        ret                                 ; character and return

    .other:
        inc di                              ; otherwise seek to the next
        jmp seek_after                      ; character and loop


; Parse all three words.
parse_input:
    mov si, word words.first                ; parse the first word
    mov di, word numbers.start              ; on the numbers array
    mov dx, word numbers.ten_end
    call parse_word
    mov [number.first], byte cl

    mov si, word words.third                ; parse the third word
    mov di, word numbers.start              ; on the numbers array
    mov dx, word numbers.ten_end
    call parse_word
    mov [number.second], byte cl

    mov si, word words.second               ; parse the second word
    mov di, word operators.start            ; on the operators
    mov dx, word operators.end
    call parse_word
    mov [operator], byte cl
    ret


; Check if all words are present after
; splitting them. Set the ZF if they are
; valid, otherwise unset it.
validate_three_words:
    cmp [words.first], byte '$'             ; if the first character is
    je .invalid                             ; a dollar sign - the word is
    cmp [words.second], byte '$'            ; not present
    je .invalid
    cmp [words.third], byte '$'
    je .invalid

    cmp al, al                              ; set the ZF and return
    ret

    .invalid:
        mov dx, word str_invalid_input      ; display invalid input message
        call print_crlf

        cmp sp, bp                          ; unset the ZF and return
        ret


; Split user input into separate words.
split_input:
    mov si, word words.first                ; clear the words array
    mov di, word words.end
    call clear_buffer

    mov si, word user_input                 ; input character iterator
    mov di, word words.first                ; address to parsed destination
    mov cl, 1                               ; indicates which word is parsed

    .trim:                                  ; trim spaces at the beginning
        mov al, byte [si]
        cmp al, ' '
        jne .loop
        inc si
        jmp .trim

    .loop:
        mov al, byte [si]                   ; check if we reached the end of
        cmp al, '$'                         ; an user input
        je .dollar

        cmp al, ' '                         ; check if we reached the end of
        je .space                           ; a word

        mov [di], al                        ; otherwise copy current character

        inc si                              ; move to the next character
        inc di                              ; and loop
        jmp .loop

        .dollar:
            mov [di], byte '$'              ; terminate the last word
            ret                             ; and return

        .space:
            inc si                          ; skip the spaces
            mov al, byte [si]
            cmp al, ' '
            je .space

            mov [di], byte '$'              ; terminate current word

            cmp cl, 1                       ; check which word is parsed
            je .second
            cmp cl, 2
            je .third
            ret

            .second:
                mov di, word words.second   ; switch the destination address
                jmp .iterate                ; to the next word
            .third:
                mov di, word words.third
            .iterate:
                inc cl
                jmp .loop                   ; and loop


; Check if two dollar terminated strings
; are equal. SI - first string,
; DI - second string. Set ZF if equal,
; unset it otherwise.
str_compare:
    .loop:
        mov al, byte [si]
        mov ah, byte [di]

        cmp al, ah                          ; compare both characters
        jne .finish                         ; finish if they are different

        cmp al, byte '$'                    ; if current character is dollar
        je .finish                          ; and all previous were equal

        inc si                              ; move to the next character
        inc di                              ; and loop
        jmp .loop

    .finish:
        ret                                 ; return with ZF set accordingly


; Print string to stdout, add a newline.
; DX - dollar terminated string.
print_crlf:
    call print                              ; print dollar terminated string
    mov dx, word str_crlf                        ; passed in DX, than print a
    int 21h                                 ; new line
    ret


; Print string to stdout, without adding
; a newline. DX - dollar terminated string
print:
    mov ah, 09h                             ; print dollar terminated string
    int 21h                                 ; passed in DX by invoking
    ret                                     ; DOS interruption


; Fills the buffer with dollar signs.
; SI - buffer address, DI - address of
; a first byte after the buffer.
clear_buffer:
    mov [si], byte '$'                      ; put a dollar sign
    inc si                                  ; go to next memory address

    cmp si, di                              ; stop if the address reached
    jne clear_buffer                        ; provided limit
    ret

; Read user input into user_input buffer.
read_input:
    mov si, word user_input                 ; clear the user input buffer
    mov di, word user_input.end             ; from previous readings
    call clear_buffer

    mov dx, word user_input.dos             ; read the user input into
    mov ah, 0ah                             ; special DX buffer by invoking
    int 21h                                 ; DOS interrupt

    mov dx, word str_crlf                   ; print new line
    call print

    call user_input_to_dollar               ; convert the user input into
    ret                                     ; dollar terminated string


; Convert user_input to dollar terminated
; string.
user_input_to_dollar:
    mov cl, byte [user_input.len]           ; get the user input length
    xor ch, ch

    mov bx, word user_input                 ; offset the address by input
    add bx, cx                              ; length

    mov [bx], byte '$'                      ; place dollar at the end
    ret                                     ; of a string


segment text1
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

numbers.start:              db 'zero$'
                            db 'one$'
                            db 'two$'
                            db 'three$'
                            db 'four$'
                            db 'five$'
                            db 'six$'
                            db 'seven$'
                            db 'eight$'
                            db 'nine$'
numbers.ten_end:            db 'ten$'
                            db 'eleven$'
                            db 'twelve$'
                            db 'thirteen$'
                            db 'fourteen$'
                            db 'fifteen$'
                            db 'sixteen$'
                            db 'seventeen$'
                            db 'eighteen$'
numbers.end:                ; 19 is impossible to obtain

numbers_tens.start:         db 'twenty$'
                            db 'thirty$'
                            db 'forty$'
                            db 'fifty$'
                            db 'sixty$'
                            db 'seventy$'
                            db 'eighty$'
numbers_tens.end:           ; 81 is maximum result possible to obtain

operators.start:            db 'plus$'
                            db 'minus$'
                            db 'times$'
operators.end:

user_input.dos              db 64           ; maximum input length
user_input.len              db 0            ; actual input length
user_input                  rb 64           ; input buffer
user_input.end:

words.first                 rb 64
words.second                rb 64
words.third                 rb 64
words.end:

number.first                rb 1
number.second               rb 1

operator                    rb 1

result                      rb 1
result.sign                 rb 1
result.tens                 rb 1
result.units                rb 1

segment stack1
rb 127
stack1_end:
rb 1
