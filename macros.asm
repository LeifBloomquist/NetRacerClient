
; ==============================================================
; Additional macros by LB
; ==============================================================

  include "equates.asm"
  include "six-macros.asm"

; ==============================================================
; Macro to position the cursor
; ==============================================================

  MAC PLOT
  ldy #{1}
  ldx #{2}
  clc
  jsr $E50A  ; PLOT 
  ENDM

; ==============================================================
; Macro to print a string
; ==============================================================

  MAC PRINTSTRING
  ldy #>{0}
  lda #<{0}
  jsr $ab1e ; STROUT 	
  ENDM

; ==============================================================
; Macro to print a byte
; ==============================================================

	MAC PRINTBYTE
  ldx #$00
  ldy #$0a
  lda {0}
  jsr printnum
  ENDM

; ==============================================================
; Macro to print a word (direct)
; ==============================================================

  MAC PRINTWORD
  lda #<{0}
  ldx #>{0}
  ldy #$0a
  jsr printnum
  ENDM

; ==============================================================
; Macro to print an IP address
; ==============================================================
  MAC PRINT_IP
  ldx #>({0})
  lda #<({0})
  jsr printip
  PRINT CRLF
  ENDM

; ==============================================================
; Macro for border color changes (raster time measure) - erase for no debug
; ==============================================================

  MAC BORDER
  ;lda #{1}
  ;sta $d020
  ENDM

; ==============================================================
; Macro for 16-bit subtraction - Subtract 2 from 1
; ==============================================================

  MAC SUBTRACT16
  sec
	lda {1} 
	sbc {2}
	sta {1} 
	lda {1}+1
	sbc {2}+1
	sta {1}+1
	ENDM
	
; ==============================================================
; Macro for 16-bit addition - Add 2 to 1
; ==============================================================

  MAC ADD16
	clc				      
	lda {1}  
	adc {2}  
	sta {1}  
	lda {1}+1
	adc {2}+1
	sta {1}+1
  ENDM 

; ==============================================================
; Macro for 16-bit negation
; ==============================================================

  MAC NEGATE16
	sec				      
	lda #$00  
	sbc {1} 
	sta {1}  
	lda #$00
	sbc {1}+1
	sta {1}+1
  ENDM 