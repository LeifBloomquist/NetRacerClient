
;Flag that the joystick may be used for input
JOYOK
   .byte $01

;This holds the joystick button state
JOYBUTTON
  .byte $00
  
;Flags for directions
JOYLEFT
  .byte $00
JOYRIGHT
  .byte $00
JOYUP
  .byte $00
JOYDOWN
  .byte $00

STEERRATE
  .byte #100

  
; ---------------------------------------------------------------------
; This is called from inside the interrupt!
READJOYSTICK     ; Thanks Jason aka TMR/C0S
  lda JOYOK      ; Joystick input is allowed
  bne JOYSTART
  rts

JOYSTART
  lda #$00
  sta JOYLEFT
  sta JOYRIGHT
  sta JOYUP
  sta JOYDOWN  
  sta JOYBUTTON
  
  lda MY_SPEED
  lsr
  lsr
  lsr
  sta STEERRATE
  
; ---------------------------------------------------------------------
; Check joystick bits.
  lda $dc00  ; Port 2
up     
  lsr
  bcs down
  inc JOYUP
down  
  lsr
  bcs left
  inc JOYDOWN
left 
  lsr
  bcs right
  inc JOYLEFT
right  
  lsr
  bcs fire
  inc JOYRIGHT
fire
  lsr
  bcs JOY_DONE
  inc JOYBUTTON

; ---------------------------------------------------------------------
; Process movements.  Can use A again.
JOY_DONE
  lda JOYUP
  beq DODOWN

  ; UP
  clc
  lda MY_SPEED  
  cmp #$FF
  beq DODOWN    ; Already at max
  adc #$01
  sta MY_SPEED

; ---------------------------------------------------------------------
DODOWN
  lda JOYDOWN
  beq DOLEFT
  
  lda #$04
  jsr DECSPEED

; ---------------------------------------------------------------------
DOLEFT
  lda JOYLEFT
  beq DORIGHT
  
  sec				       ; set carry for borrow purpose
	lda MYX_SPEED
	sbc STEERRATE    ; perform subtraction on the LSBs
	sta MYX_SPEED
	lda MYX_SPEED+1	 ; do the same for the MSBs, with carry
	sbc #$00			   ; set according to the previous result
	sta MYX_SPEED+1	
	
	; Limit Speed if less than -3
	cmp #$FC
	bpl DORIGHT
  
  lda #$FD
  sta MYX_SPEED+1	
	lda #$00
	sta MYX_SPEED
  
; ---------------------------------------------------------------------
DORIGHT
  lda JOYRIGHT
  beq JOY_x

  clc				       ; clear carry
	lda MYX_SPEED
	adc STEERRATE
	sta MYX_SPEED	   ; store sum of LSBs
	lda MYX_SPEED+1
	adc #$00		     ; add the MSBs using carry from
	sta MYX_SPEED+1	 ; the previous calculation

	; Limit Speed if more than +3
	cmp #$04
	bne JOY_x
  
  lda #$03
  sta MYX_SPEED+1	
	lda #$00
	sta MYX_SPEED


; ---------------------------------------------------------------------
JOY_x
  rts

