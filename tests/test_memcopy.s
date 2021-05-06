
_reset:     LDA:Y   #100
            LDA:A   #$C000
            STA:A   $A0
            LDA:A   #$B000
            STA:A   $A2
_loop:      SUB:Y   #1 ?
            LDA:A   byte ($A0),Y
            STA:A   byte ($A1),Y
            BNE     _loop
            LDA:A   #0
            STA:A   byte $FFFF ; stop the clock
