
_reset:     LDA:Y   #100
            LDA:A   #$C000
            STA:A   $A0
            LDA:A   #$B000
            STA:A   $A2
_loop:      SUB:Y   #1 ?
            LDA:A   byte ($A0),Y
            STA:A   byte ($A2),Y
            BNE     _loop
            LDA:A   #0
            STA:A   byte $FFFF ; stop the clock

706C6   64                  ; LDA:Y #$64
A818
C858
3

700C0   C000                ; LDA:A $C000
A818
C858
3

2C84    A0                  ; STA:A $A0
A818
C858
3

700C0   B000                ; LDA:A $B000
A818
C858
3

2C84    A2                  ; STA:A $A2
A818
C858
3

216C6   1                   ; SUB:Y #$1 ?
A818
C858
3

70030   A0                  ; LDA:A byte ($A0), Y
A81B
C85A
1

2C47    A2                  ; STA:A byte ($A2), Y
A899
C85A
2

F03     FFF8                ; BNE -8
A818
C858
3