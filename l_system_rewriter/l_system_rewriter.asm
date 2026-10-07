bits 64
default rel
global _start

;--------CODE WRITTEN BY JAKUB SKALANY------

%macro swap 2                       ;swaps registers %1 and %2 
    mov     rax, %1                      ;not keeping register rax
    mov     %1, %2
    mov     %2, rax
%endmacro

;  %1-bytes currently used %2 allocated memory capacity 3-buffer adress
; Checks if there is enough space in the buffer to write a new byte.
; If counter of written elements (%1)<  the capacity (%2), it does nothing.
; If buffer is full (%1 == %2), it calls 'add_page_memory'
; which doubles the capacity (%2) 
; Because 'add_page_memory' destroys the counter (%1), macro 
; restores it div new size by two

%macro enlarge 3                  
    cmp     %1, %2                       
    jl      %%omit_memory_expandation
    mov     [rarely_used_reg_2], r11
    mov     [rarely_used_reg_3], rcx
    swap    %3, rbp
    swap    %2, r13  
    call    twice_memory   
    swap    %3, rbp
    swap    %2, r13     
    mov     r11, [rarely_used_reg_2]
    mov     rcx, [rarely_used_reg_3]
    %%omit_memory_expandation:
%endmacro

section .text
;-------------------------------constants 
SYS_EXIT          equ 60             ;of numbers of system functions
SYS_MREMAP        equ 25
SYS_MMAP          equ 9
SYS_MUNMAP        equ 11
SYS_READ          equ 0
SYS_WRITE         equ 1 
;-------------------------------------constants of bounds
UPPER_SIGN        equ 126            
LOWER_SIGN        equ 33             ;of what is sign in ascii in this program
UPPER_NUM         equ 57             ;of what is number in ascii
LOWER_NUM         equ 48
UPPER_ITERATION   equ 4294967295     ;of wwhat is upper limit in 
;------------------------------------memory protection  mmap and mremap flags
PROT_READ         equ 1              
PROT_WRITE        equ 2
MAP_PRIVATE       equ 0x2            
MAP_ANONYMUS      equ 0x20
MREMAP_MAYMOVE    equ 1
;----------------------------------- others
END_WORD_SIGN     equ 10
CARRIAGE_RETURN   equ 13
TERMINAL_END_SIGN equ 0
PAGE_SIZE         equ 4096
DESCRIPTOR_INPUT  equ 0
DESCRIPTOR_OUTPUT equ 1


section .bss
;-----------rarely used variables
all_time_iteration  resb 8       ;stores the counter of operations
EXIT_CODE           resb 1       ;stores rarely changed exit code
rarely_used_reg_1   resq 1 
rarely_used_reg_2   resq 1
rarely_used_reg_3   resq 1      
nextability         resb 1       ;buffer for check \n not only after \n    
dictionary          resq 127     ;buffer of constant memory 

;---------------DESCRIPTION OF ALGORITHM--------------------------------
;1)we check correctnes of number of iterations and put in all_time_iteration
;2)we read symbols with ongoing key:
;2a)we store two places of memory-dictionary and translation
;2b)for symbol with ascii code x we store information about it in dictionary;
;with this formula xinfo is under dictionary+8*x
;2b)in dictionary we store offset on ongoing rule:
;translation of single letter=translation adress+offset
;after making dictionary and translation we use two spaces-
;for words before and after,and rescribing data from dictionary to after 
;for every letter

;---------------------CAPTION------------------------
;we don't use stack in program's logic therefore when we call the function
;and we have to leave function without returning to previous instruction
;we can pop the stack, and jump to  interesting etiquete

section .text
_start:

    mov     byte [EXIT_CODE], 1
    mov     rcx, [rsp ]              ;loads numbers of parameters
    cmp     rcx, 2                   ;checks number of parameters 
    jne     exit                     ;invalid number of parameters

lets_check_it_num:                   ;we check correctness of num of 
                                     ;iteration parameters
                                     ;we accept leading zeroes
    xor     r8, r8                   ;our numof it will be now in R8
    mov     rcx, [rsp + 2 * 8]       ;we load address of num of params to RCX
lets_check_letter_of_initial_param:
    movzx   rax, byte [rcx]          ;we check every byte separatedly (RAX)
    cmp     rax, TERMINAL_END_SIGN
    je      initial_param_checked    ;if we got to end of word,its correct num 
    cmp     rax, LOWER_NUM           ;checking ascii bounds
    jl      exit
    cmp     rax, UPPER_NUM
    jg      exit
    sub     rax, LOWER_NUM           ;putting number to rax
    imul    r8, 10                   ;eg 123 1->1*10+2=12->12*10+3=123
    add     r8, rax                       
    mov     r9, UPPER_ITERATION      ;checking whether our result 
    cmp     r8, r9                   ;is not bigger than 2^32-1
    jg      exit
    inc     rcx                      ;going to next sign
    jmp     lets_check_letter_of_initial_param

initial_param_checked:

    mov     [all_time_iteration], r8  ;now we put counter to all_time_iteration

;we wanna alocate every used block in this section of code,
;not to write diffirent exit's because of diffirent number of allocated spaces
; registers will always be groupped in this pairs, but their usage
;may be diffirent, now not important
; rbp,r13-first memory adres, its size
; rbx,r14-second memory adress,its size
; r12,r15-third memory adress,its size

memory_allocation:
    call    make_memory
    cmp     rax, 0                 ;checks corectablility of system function
    jl      exit              
    mov     rbp, rax               ;moving adrres and size to correct registers
    mov     r13, PAGE_SIZE    


    call    make_memory            ;every exit is written to ensure
    cmp     rax, 0                 ;freeing of right amount
    jl      exit_first             ;of alocated spaces
    mov     rbx, rax
    mov     r14, PAGE_SIZE

    call    make_memory
    cmp     rax, 0
    jl      exit_second
    mov     r12, rax
    mov     r15, PAGE_SIZE


;----redisters (continue with first info)
; rbp,r13-buffer for reading whole input
; r12,r15-first word
; rcx- iterator along whole input
; r9- last char analised
; r8- iterator along first word
; r14-border of when letters are allocated

xor     rcx, rcx            
xor     r9, r9              
xor     r8, r8              
mov     [rarely_used_reg_1], r14          ;we will be using r14 and
xor     r14, r14                          ;we need place to store it

reading_first_word_input:
    call     analise_letter        ;getting letter wrom rbp+rcx in rax 
    enlarge r8, r15, r12           ;ensuring memory
    mov byte al, [rbp + rcx]
    mov byte [r12 + r8], al        ;writing letter to good adress
    inc      r8
    inc      rcx
    cmp      al, END_WORD_SIGN     ;checking if first word ended
    je       follow
    jmp      reading_first_word_input

;in first word adress we got the first word ending with end of word sign
;r12, r15- first word adress
;rbp, r13- input read and translator
;rcx-counter along translator

follow:
    mov byte [nextability], 1     ;from now there are no \n after \n

get_next_words:
    call    analise_letter
    mov     rdi, rax                   ;first letter of translating in rdi
    lea     r10, [rel dictionary]      
    mov     rax, [r10 + rdi * 8]       ;in rax is adress of byte of char
    cmp     rax, 0                     ;in dictionary
    jne     exit_memory                ;if rax !=0 letter was translated
    inc     rcx                        ;we wanna omit first letter 
    mov     [r10 + rdi * 8], rcx       ;we are writing offset 
                                       ;in translation to dictionary

iterator_of_single_translation:    ;when offset is set, we just have to write
    call    analise_letter         ;letters into translation adress,
    inc     rcx
    cmp     rax, END_WORD_SIGN     ;checking, if translation was ended
    je      get_next_words         ;ofset and end on zero
    jmp     iterator_of_single_translation

analysis:
    cmp     rcx, 0      ;we always increase rcx 
    je      finish_well ;therefor rcx==0 size means no reading 
                        ;operation-meaning no letters,
                        ;then it's nothing to do and we can finish program 
                        ;with success
;-------WE'VE FINISHED READING THE INPUT
;-------now for every letter without translation
;we want to put X=X 
;-----------register usage
;rbp, r13-dictionary
;r8-iterator al1ong dictionary 
;r9-dress of dictionary 

dictionary_enlargeing:
    mov     r14, [rarely_used_reg_1]
    mov     r11, rcx
    lea     r9, [rel dictionary]
    mov     r8, LOWER_SIGN

dictionary_loop:

    cmp     r8, UPPER_SIGN           ;check, whether all letters are translated
    jg      after_enlargeing            
    mov     rax, [r8 * 8 + r9]       ;we load cell of dictionary into rax
    cmp     rax, 0                   ;if 0 is translated
    jne     not_to_addwrite

    enlarge r11, r13, rbp
    mov     [r8 * 8 + r9], r11       ;load actual adress in translation to dic.
    mov     [r11 + rbp], r8b         ;mov x to translation 
    inc     r11

    enlarge   r11, r13, rbp                ;puting end word sign to translation
    mov byte [r11 + rbp], END_WORD_SIGN
    inc       r11

    jmp     dictionary_loop

not_to_addwrite:
    inc     r8
    jmp     dictionary_loop

;--------FINISHED FULL DICTIONARY WITH TRANSLATORS
;every sign will be translated using dictionary 
;single letters translation rewriten into word after
;after all we have to put end sign 

;-----------registers usage----------
;rax,rdi,rsi,rdx,r10-system calls,work registers
;r11,-iterator along word after
; rbp,r13-first memory adres,size-word after single process
; rbx,r14-second memory adress,size-translation
; r12,r15-third memory adress,size- word before single process
; r8- iterator along word before
; r9- translator iterator

after_enlargeing:
    swap     rbp, rbx                     ;swaps to reach correctness
    swap     r13, r14                     ;according to registers usage


main_iteration:
    mov     r8, [all_time_iteration]      ;decrement and optional leave od loop
    cmp     r8, 0                         ;using r8 in between
    je      write
    dec     r8
    mov     [all_time_iteration], r8

    xor     r8, r8
    xor     r11, r11                      ;clearing iterators along words

single_letter_before_iteration:
    mov byte r10b, [r8 + r12]             ;getting char of long word
    cmp      r10b, END_WORD_SIGN          ;if char is end word sign, 
    je       after_all                    ;we finish iteration

    lea     rsi, [rel dictionary]         
    movzx   rax, r10b
    mov     r9, [rsi + 8 * rax]           ;translation=rbx+8*char code
                                          ;+dicionary adress
single_letter_after_iteration:        
    enlarge  r11, r13, rbp                   ;of syscalls in ensuring memory


    mov byte al, [r9 + rbx]               
    cmp      al, END_WORD_SIGN            ;checks,whether single letter
    je       after_letter                 ;is translated
    mov byte [r11 + rbp], al              ;if not, rewrite to word after
    inc      r9                           ;move iterator
    inc      r11                        
    jmp      single_letter_after_iteration   

after_letter:                                 ;if letter from word 
    inc     r8                                ;before is translated
    jmp     single_letter_before_iteration    ; we go to next letter

after_all:
    enlarge  r11, r13 , rbp            ;adding end word sign to translated word
    mov byte [r11 + rbp], END_WORD_SIGN
    swap     rbp, r12                  ;swapping to ensure logic
    swap     r13, r15
    jmp main_iteration

;---------r12,r15-adress of word to write
;--------other registers to system functions
write:
    mov     al, END_WORD_SIGN   ;we wanna get,how much elements from memory
    mov     rdi, r12            ;is after end_word-sign
    mov     rcx, r15

    repne scasb

    mov     rdx, r15            ;no. letters to write 
    sub     rdx, rcx            ;whole memory-unused memory n.of bytes to write
    mov     rsi, r12            ;rsi-begin of adress
.write_loop:
    cmp     rdx, 0
    jle     finish_well

    mov     rax, SYS_WRITE
    mov     rdi, DESCRIPTOR_OUTPUT
    syscall

    cmp     rax, 0              ;checks succesfullnes of syswrite
    jl      exit_memory         ;if rax<0 error
    je      exit_memory         ;according to cmp rdx,0 there is something
                                ;to write, therefore it's lack is error
    add     rsi, rax
    sub     rdx, rax            ;moving to write not written yet letters
    jmp     .write_loop

finish_well:                ;if syswrite was succesful,we can finish with 0
    mov   byte [EXIT_CODE], 0

;------------functions to remove allocated memory
;they removes memory in order opposed to allocating order
;therefore after each allocation we can remove only allocated spaces
;after calls for dealocating functions, we check theirs correctness 

exit_memory:
    mov   rax, SYS_MUNMAP
    mov   rdi, r12
    mov   rsi, r15
    syscall
    cmp   rax, 0
    je    exit_second
    mov   byte [EXIT_CODE], 1

exit_second:
    mov   rax, SYS_MUNMAP
    mov   rdi, rbx
    mov   rsi, r14
    syscall
    cmp   rax,0
    je    exit_first
    mov   byte [EXIT_CODE], 1
 
exit_first: 
    mov   rax, SYS_MUNMAP
    mov   rdi, rbp
    mov   rsi, r13
    syscall
    cmp   rax, 0
    je    exit
    mov   byte [EXIT_CODE], 1

exit:                           
    movzx rdi, byte [EXIT_CODE] ;we can finish whole program with exit code
    mov   rax, SYS_EXIT         ;stored in EXIT_CODE
    syscall

analise_letter:                     
    cmp   rcx, r14
    jne   .not_read              
    call  read_function              ;it analises errors

    .not_read:
    mov   al,byte [rbp+rcx] 
    movzx rax, al                
    cmp   rax, 0                        
    je    eof                       ;we check whether is eof    
    cmp   al, END_WORD_SIGN
    je    .eol                      ;if number is 10, its end of line
                                    ;we return 1 

    cmp   al, LOWER_SIGN            ;we check bounds of symbol (its correctnes) 
    jl    error
    cmp   al, UPPER_SIGN     
    jg    error
    
    mov   r9, rax                                    
    ret

.eol:                              
    mov    rdi, [nextability]     ;we check, whether \n after \n is possible
    cmp    rdi, 0
    je     .to_ret_eol            ;if is, go to return
    cmp    r9, END_WORD_SIGN      ;if not compare if it happend
    je     error                  ;if so return error
    jne    .to_ret_eol            ;if no go home
    
.to_ret_eol:
    mov    rax, END_WORD_SIGN
    mov    r9,  END_WORD_SIGN 
    ret


error:                            ;if we don't wan to return the letter
    pop   rax                     ;we pop the stack and don't return
    jmp   exit_memory             ;but go to looked place
                                  ;if sign is not in bounds, it is error
                                  ;when we're reading input
eof:
    pop   rax                     ;if it's eof, we finished reading input
    cmp   r9, END_WORD_SIGN
    je    analysis
    jne   error
make_memory:                            ;makes memory block of one page
    mov   rax, SYS_MMAP                 ;returns its adress to rax
    mov   rdi, 0                        ;does not check sucessfullnes
    mov   rsi, PAGE_SIZE                ;of system functions
    mov   rdx, PROT_READ|PROT_WRITE     ;in this place, only in program
    mov   r10, MAP_PRIVATE|MAP_ANONYMUS
    mov   r8, -1                        
    mov   r9,0
    syscall
    ret

read_function:  
    cmp   r13, r14
    jg    .read_without_reallocing

    call  twice_memory                   ;we ensure memory in buffer
    cmp   rax, 0
    jl    .read_fail

    mov   rdi,  DESCRIPTOR_INPUT      
    mov   rax,  SYS_READ
    mov   rsi,  rbp                      
    shr   r13,  1                        ;we want to put letters only to later
    add   rsi,  r13                      ;half of allocated memory
    mov   rdx,  r13                      ;we put size of buffer to rdx
    shl   r13,  1                        ;we put correct size of buffer to let 
    syscall                              ;realloc after wrond 
    
    cmp   rax, 0
    jl    .read_fail
    je    .read_eof
    mov   rcx, r14                       ;we put back rcx
    add   r14, rax
    ret

.read_without_reallocing:
    mov   rdi,  DESCRIPTOR_INPUT      
    mov   rax,  SYS_READ
    mov   rsi,  rbp  
    add   rsi,  rcx 
    mov   rdx,  r13
    sub   rdx,  rcx
    syscall

    cmp   rax, 0
    jl    .read_fail 
    je    .read_eof
    mov   rcx, r14                       ;we put back rcx
    add   r14, rax
    ret

.read_eof:
    pop   rax
    mov   rcx, r14                        ;we put back rcx
    jmp   eof


.read_fail:  
    pop   rax                        ;we need to go from analyse letter
    pop   rax                        ;we need to exit read fail
    jmp   exit_memory

twice_memory:                        ;double memory in one block 
    mov   rax, SYS_MREMAP            ;(memory in rbp,size in r13)
    mov   rdi, rbp
    mov   rsi, r13                   ;we load to adresses
    add   r13, r13                   ;double the size of r13
    mov   rdx, r13
    mov   r10, MREMAP_MAYMOVE
    syscall
    cmp   rax, 0
    jl    .twice_alloc_error         ;check correctness of realloc
    mov   rbp, rax
    mov   rax, 0               
    ret

.twice_alloc_error:
    mov   rax, 1                     ;returning wrong code 
    ret
