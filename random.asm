;; RANDOM.ASM--implementation of minimal standard random number
;;  generator. See article by David G. Carta, CACM Jan 1990, p. 87
;;
;;  Calling Sequence:
;;
;;  EXTRN   Random: NEAR
;;  call    Random
;;  0 < value < 2**31 - 1 returned in eax
;;
;;  Program text from "Assembly Language for the IBM PC Family" by
;;   William B. Jones, (c) Copyright 1992, 1997, 2001, Scott/Jones Inc.
;;
        .MODEL  SMALL
        .586
        .DATA
        EXTRN   Seed : DWORD ;  Defined elsewhere
A       EQU     16807

        .CODE
        PUBLIC  Random
Random  PROC
        push    edx
        push    ds ;    make sure ds is set to @data
        mov     ax, @data
        mov     ds, ax
;
;   edx|eax = A * Seed
;
        mov     eax, A
        mul     Seed
;
;   represent edx|eax in base 2**31
;
        shld    edx, eax, 1
        and     eax, 7FFFFFFFh
;
;   add base 2**31 digits and if result is more than one
;   digit in base 2**31, add again
;
        add     eax, edx
        test    eax, 80000000h
        jz      noMore ;            check of leftmost bit of eax is 1
        add     eax, 80000001h ;    zeroes leftmost 1 bit
noMore:         ;                    and adds it in on the right end

        mov     Seed, eax
        pop     ds
        pop     edx
        ret
Random  ENDP
        END

