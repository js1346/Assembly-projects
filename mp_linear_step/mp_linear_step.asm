bits 64
global mp_linear_step     ;rdi-a0* rsi-*a1 i rdx-*ak, rcx-n, r8-k;     
    
                            
section .text
mp_linear_step:            

;chcemy poznac wynik działania a0+(a1-a0)*k=a0+(a0-a1)*(-k)
;dla dalszej logiki chcemy wybrac wariant, 
;w ktorym drugi czynnik bedzie wiekszy od zera

;-------------------rejestry----------
    ;rdi-aktualny adres a0
    ;rsi-aktualny adres a1
    ;rax-adres roboczy do odejmowania
    ;rdx-roboczy adres różnicy
    ;rcx adres licznika
    ;r8-adres k
    ;r9,r10 -magazyn adresu roznicy i licznika
    ;r11,magazyn adresu a0

mov    r11, rdi          ;zgodnie z logika wsadzamy akumulatory
mov    r10, rcx
mov    r9,  rdx
test   r8,  r8           ;chcemy pozyskać pierwszy bit r8 za pomocą SF0
jns    nie_neguj_r8      ;jesli pierwszy bit to 0 mozemy pominac logikę ponizej
neg    r8                ;od teraz zawartosc r8 traktujemy jako unsigned int
mov    rdi, rsi          ;zamienilismy ze soba liczby rdi i rsi
mov    rsi, r11          ;dzieki czemu rsi-rdi to a0-a1 

nie_neguj_r8:
clc                     ;w logice bedziemy korzystac z carry flag,
                        ; dlatego ja czyscimy 

petla_odejmowania:
mov   rax, qword[rsi]         ;w rax pdejmujemy rsi-rdi
sbb   rax, qword[rdi]
mov  qword[rdx], rax          ;wsadzamy wynik pod adres rdx
lea   rsi, qword[rsi+8]       ;przesuwamy adresy o jedno slowo
lea   rdx, qword[rdx+8] 
lea   rdi, qword[rdi+8]
loop petla_odejmowania

mov   rsi,0             ;czyscimy rsi
setl  sil               ;wstawia znak wyniku do rsi (SF!=OF)
neg   rsi               ;negacja 00001 daje 11110+1=11111
                        ;negacja 00000 daje 11111+1=00000

;mnozym roznice r*k unsignedowo, jezeli r>0 to nic nie zmieniamy, jezeli r<0 :
;r=-2^(64n+63)+p czyli r*k=(-2^(64n+63)+p)*k
;a my pomnozylismy (2^(64n+63)+p)*k,
;czyli różnica, którą musimy odjąć od mnożenia to -2*(2^64n+63)*k=-2^(64n+64)*k
;czyli od n+2-go słowa musimy odjąć k(dzięki nadmiarowości znaków w wyniku
;dodawania nie będzie overflow'u)

;--------zawartosc rejestrow---------------------------------------
;r12-overflow z mnożenia
;rdi-aktualny adres w różnicy
;rsi-n+1sze słowo różnicy
;r8-r11 ,rcx niezmienne
;rax,rdx wyniki mnozenia
mov   rcx, r10
mov   rdi, r9
push  r12
xor   r12, r12              ;czyscimy rejestr r12

petla_mnozenia:
mov    rax, qword[rdi]        
mul    r8                    ;mnozymy fragment różnicy przez k
add    rax, r12               ;dodajemy overflow
adc    rdx, 0                 ;przekazujemy overflow dalej
mov    r12, rdx              ;wsadzamy overflow do r12
mov    qword[rdi], rax       ;wynik mozemy wsadzic spowrotem;
                            ;na tej czesci juz nie robimy operacji w tej sekcji
lea    rdi, [rdi+8]          ;przechodzimy do kolejnej czesci roznicy         
loop   petla_mnozenia

mov    rax, rsi              ;obrót mnozenia dla N+1go słowa
mul    r8                   ;analogicznt do poprzenich instrukcji
add    rax, r12
adc    rdx, 0               ;dwie mozliwe wartosci r11 to 1111... i 000...
cmp    rsi, 0               ;jezeli 0000..., to roznica dodatnia,nic nie robimy
je     koncowka_mnozenia    
sub    rdx, r8              ;jezeli ujemna, to odejmujemy k od pierwszego bitu
koncowka_mnozenia:
pop    r12                  ;juz go nie bedziemy potrzebowac w logice

;pozyskujemy znak a0 i przepisujemy go na dwa slowa przednie
;dodajemy a0,ze wzgledu na rozmiar a0 
;i rozmiar iloczynu nie przekroczy on zawartosci n+2 słow
;mozemy porzucic adresy mnozenia itd. poniewaz juz ich nie bedziemy potrzebowac
;--------rejestry-----------------------------
;rax,rdx-wynikowe
;r11-aktualny adres w a0
;rdi-aktualny adres w różnicy
;rsi-adres roboczy
;rcx-counter
;r8,rejestr dw och pierwszych pierwszych bitów a0
mov    rcx, r10                ;przerzucamy do zgodnosci z logiką
mov    rdi, r9
mov    rsi, qword[r11+rcx*8-8] ;pozyskujemy MS bajt z a0
mov    r8,0
test   rsi, rsi                ;pozyskujemy MSB z a0
sets   r8b                     ;wsadzamy do dolnej ósemki r8
neg    r8                      ;analogicznie do 1szej petli
clc                         ;czyscimy carry flaga,by moc dodac z przeniesieniem

petla_dodawania:
mov    rsi,qword[r11]
adc    qword[rdi],rsi      ;dodajemy z overflow r11 do rdi za posrednictwem rsi
lea    rdi, [rdi+8]        ;przesuwamy indeksy
lea    r11, [r11+8]
loop petla_dodawania

adc    rax,r8              ;dodajemy pozostałe dwa rejestry
adc    rdx,r8

ret
