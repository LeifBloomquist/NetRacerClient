; Network game - Game-related logic and variables

; Game stats
DAMAGE
  .byte $00
  
CARS
  .byte $00  ; Set in racer-main

SCORE  ; stored in BCD
  .byte $00,$00,$00

MYXPOS
  .byte $00,$80,$00   ; First byte is "fraction", second byte is "integer", 3rd byte is "high bit"

MYX_SPEED
  .byte $00,$00   ; First byte is "fraction", second byte is "integer"

;--------------------------------------------------------------------
; Game logic
GAME_TICK
  ;Check for Run/Stop - Reset game if pressed!
  
  LDA #$7F
  STA $DC00
  LDA $DC01
  CMP #$7F
  BNE CHECKNET
  
  jmp GAME_OVER

CHECKNET
  ;If network timed out, don't update
  lda NET_TIMEDOUT
  beq NET_OK
  jmp GAME_TICK_x

  ; If game over, don't update
NET_OK
  lda GAMEOVER_FLAG
  beq GAME_OK1
  jmp GAME_OVER

GAME_OK1
  ; If car was wrecked, only update animation (no controls)
  lda CAR_DESTROYED
  beq GAME_OK2
  jmp DESTROY_ANIM   ;Skip game update entirely

GAME_OK2
  ; Joystick input
  jsr READJOYSTICK
	
CHECKCARS
  ; Check for collision with other cars - note: this is collision based on previous
  ; frame's movement!  takes 1 frame for sprites to be redrawn and collision to be
  ; registered.
  lda $d01e
  sta D01ETEMP
  and #$01
  beq CHECK  ;zero, meaning no collision
  jsr HITCAR

  ; Check for collision with background 
CHECK	  
 
  jsr UPDATECARX  ; Update my X position based on X speed
  jsr HITSIDE     ; no longer uses h/w collision, always does lookup now
 
    ; Sounds
SOUNDS
  jsr SOUND_ENGINE
  
  ; Friction
  jsr SLOWX
  
  lda JOYUP
  bne CHECKDAMAGE

  lda MY_SPEED
  beq CHECKDAMAGE     ; Already at 0

  dec MY_SPEED
 
CHECKDAMAGE 
  ; Check if damage > 100
  ldx DAMAGE
  cpx #100  ;Decimal
  blt GAME_TICK_x
  
  ;Damage excedeed 100!  Kaboom!
  jsr INIT_EXPLOSION
  
GAME_TICK_x  
  rts
  
  
  
  
; ----------------------------------------------------------
; Update car X position  (Y is done in screen update)
; 16-bit addition	in case we use fractions in future
UPDATECARX
  ;ADD16 MYXPOS, MYX_SPEED  ; NOW 24-BIT!
  
  ;figure out implied high-byte of MYX_SPEED
  lda #0
  sta .temp
  lda MYX_SPEED+1
  bpl .done
  lda #255
  sta .temp
.done
  clc
  lda MYXPOS
  adc MYX_SPEED
  sta MYXPOS
  lda MYXPOS+1
  adc MYX_SPEED+1
  sta MYXPOS+1
  lda MYXPOS+2
  adc .temp
  sta MYXPOS+2
  
  ; And update sprite
  lda MYXPOS+1
  sta sprite1x
  lda MYXPOS+2
  cmp #0
  bne .ahead1
  ;zero out 9th bit of xpos
  ;lda $d010
  ;and #254
  ;sta $d010
  rts
.ahead1
  ;set 9th bit
  ;lda $d010
  ;ora #1
  ;sta $d010
  rts

.temp
  .byte $00
; ----------------------------------------------------------
; Check if collided with the side of the track!

BOUNCE
   .byte $A0, $01  ; First byte is "fraction", second byte is "integer"

HITSIDE SUBROUTINE

CHECKTRACK
  ; 1. Look around to see what we hit.
  
  ; Left corner
  lda MYXPOS+2
  ror
  lda MYXPOS+1
  ror
  clc
  adc #1 ; to make up for 2 pixel space at left at sprite (divided by two)
  tax
  lda XTOCHAR,x
  tax
  lda $05e0,x 
  cmp #$20          ; Blank space
  beq CHECKRIGHT
  cmp #"K"	    ; flat wall
  bne .next1a
  NEGATE16 MYX_SPEED
  jmp DOBOUNCE
.next1a
  cmp #"B"  ;diagonal wall
  bne .next1b
  jmp MOVERIGHT
.next1b
  cmp #"M"	    ; diagonal away... bounce for now
  bne .next1c
  jmp MOVERIGHT
.next1c
  cmp #"L"	    ; sometimes can look past edge tiles into this...
  bne .next1d
  jmp MOVERIGHT
.next1d
  cmp #"A"	    ; sometimes can look past edge tiles into this...
  bne .next1e
  jmp MOVERIGHT
.next1e
  jmp CHECKRIGHT
  
MOVERIGHT
  lda #0
  sta MYX_SPEED  ;set speed to 1 pixel/frame right
  lda #1
  sta MYX_SPEED+1
  jmp DOBOUNCE

CHECKRIGHT 
  ;Right corner
  lda MYXPOS+2
  ror
  lda MYXPOS+1
  ror
  clc
  adc #11 ; to make up for 2 pixel gap at right (divided by 2)
  tax
  lda XTOCHAR,x
  tax
  lda $05e0,x
  
  cmp #$20          ; Blank space
  beq .exit
  cmp #"J"
  bne .next2a
  NEGATE16 MYX_SPEED
  jmp DOBOUNCE
.next2a
  cmp #"C"
  bne .next2b
  jmp MOVELEFT
.next2b
  cmp #"N"	    ; diagonal away... bounce for now
  bne .next2c
  jmp MOVELEFT
.next2c
  cmp #"L"	    ; sometimes can look past edge tiles into this...
  bne .next2d
  jmp MOVELEFT
.next2d
  cmp #"A"	    ; sometimes can look past edge tiles into this...
  bne .next2e
  jmp MOVELEFT
.next2e
  jmp .exit
  
MOVELEFT
  lda #0
  sta MYX_SPEED  ;set speed to 1 pixel/frame left
  lda #$ff
  sta MYX_SPEED+1
  jmp DOBOUNCE  

DOBOUNCE
HITSIDE_x  
  jsr SOUND_HITSIDE
  lda #3  ; Decimal
  jsr INCDAMAGE
  
  lda #10 ;Decimal
  jsr DECSPEED

  jsr UPDATECARX
.exit
  rts

; ----------------------------------------------------------
; Collided with another car!

D01ETEMP
  .byte $00

HITCAR SUBROUTINE
  ; Determine which car we hit.  
  ldy #$01  ; Start at sprite #1 ($d002)

CHECKMORE
  jsr CHECKCAR
  
  lda CARFOUND
  bne FOUND
  
  ; Not found, next car
  iny
  cpy #$08
  bne CHECKMORE
  
NOTFOUND
  ; If we reached here, no valid collision was found (bug?), so don't do any more  
  lda #0
  sta $7e6
  
  rts
 
  ; Found which car we hit.
FOUND 
  tya
  clc     ;display sprite num in bottom right corner for debugging
  adc #$30
  sta $7e6
  
  ;Y now contains sprite# of car we hit (starting at 1, since player car is sprite 0)
  
  ;Based on 1st year physics, if two objects of equal mass collide, they simply
  ;exchange velocities.  We take on the other player's velocity (assume that other
  ;client is doing same.)
  
  ;lda IN_XSPEEDLOW,y
  ;sta MYX_SPEED
  ;lda IN_XSPEEDHIGH,y
  ;sta MYX_SPEED+1
  
  ;lda IN_YSPEEDLOW,y
  ;sta MY_SPEED
  ;lda IN_YSPEEDHIGH,y
  ;sta MY_SPEED+1
 
  ; if collision on right, move left... if on left, move right
  sec
  lda     MYXPOS+1     ; 16-bit subtraction
  sbc     IN_XPOSLOW,y
  lda     MYXPOS+2     ;  High byte - reserve for future
  sbc     IN_XPOSHIGH,y
  bcc     .ahead1

  ; move right  
  lda #0
  sta MYX_SPEED  ;set speed to 1 pixel/frame right
  lda #1
  sta MYX_SPEED+1
  jmp HITCAR_x

.ahead1
  ; move left
  lda #0
  sta MYX_SPEED  ;set speed to 1 pixel/frame left
  lda #$ff
  sta MYX_SPEED+1
  
HITCAR_x
  jsr SOUND_HITCAR
  lda #02  ; Decimal
  jsr INCDAMAGE
  
  lda #10 ;Decimal
  jsr DECSPEED
  
  rts
  
; ---------------------------------------------------------
; Decrease X (lateral) speed if joystick released

FRICTION
  .byte 20, 0      ; Tweak this!  Decimal

SLOWX    
  ; If X speed is already zero, do nothing.
  clc
  lda MYX_SPEED
  adc MYX_SPEED+1
  beq SLOWX_x
  
  ; Constantly move the speed towards zero - need direction by checking sign
  lda MYX_SPEED+1 ; High byte
  bmi XSNEG       ; Negative  
  jmp XSPOS       ; Positive
  
XSNEG
  lda JOYLEFT
  bne SLOWX_x
  ADD16 MYX_SPEED, FRICTION	
	bcs STOPX       ;Crossed to positive?
	rts
   
XSPOS
  lda JOYRIGHT
  bne SLOWX_x
  SUBTRACT16 MYX_SPEED, FRICTION
	bcc STOPX       ;Crossed to negative?
	rts
  
; Stop X motion completely.
STOPX
  lda #$00
  sta MYX_SPEED
  sta MYX_SPEED+1
  
SLOWX_x
  rts
  

; ---------------------------------------------------------
; Increment score by A,X (two bytes, decimal mode... max of 9999)
INCSCORE
  sed
  
  sta SCOREUP
  stx SCOREUP+1
  clc				  
	lda SCORE
	adc SCOREUP
	sta SCORE	
	lda SCORE+1
	adc SCOREUP+1
	sta SCORE+1  
	lda SCORE+2
	adc #0
	sta SCORE+2
	
  cld
  
  rts
 
SCOREUP
  .byte $00,$00

; ---------------------------------------------------------
; Increment damage by A (one byte)
INCDAMAGE
  sta DAMAGEUP
  clc				  
	lda DAMAGE
	adc DAMAGEUP
	sta DAMAGE
  rts

DAMAGEUP
  .byte $00
 
; ---------------------------------------------------------
; Decrement speed by A (one byte), keep positive
DECSPEED
  sta SPEED_DEC

  sec
  lda MY_SPEED
  beq DESCSPEED_x   ; Already at 0
  
  sbc SPEED_DEC
  sta MY_SPEED
  bcs DESCSPEED_x   ; Result still positive (no carry)
  
  lda #$00
  sta MY_SPEED      ; Was negative, limit to 0

DESCSPEED_x
  rts
  
SPEED_DEC
  .byte $00
  
; ---------------------------------------------------------
; Check if we hit a particular car.  Use y to point to sprite regs.
; Thanks Jorma Oksanen!
; Sets CARHIT to 1 if hit.

CHECKCAR

  lda #$00
  sta CARFOUND
        
  sec
  lda     MYXPOS+1     ; 16-bit subtraction
  sbc     IN_XPOSLOW,y
  sta     dx
  lda     MYXPOS+2     ;  High byte - reserve for future
  sbc     IN_XPOSHIGH,y
  bcc     .dxneg

; dx positive
  bne     .skip        ; dx in [0,23] ?
  lda     dx
  cmp     #24
  bcc     .xok         ; yes
  bcs     .skip

.dxneg  
  cmp     <#-1         ; dx in [-23,-1] ?
  bne     .skip        ; no
  lda     dx
  cmp     <#-23
  bcc     .skip        ; no
  eor     #$ff
  adc     #0
  
.xok    

 ; Y check ---------------------------  
  sec                             ; repeat with dy, range [-20,20]
  lda     sprite1y                ; a bit easier, as we
  sbc     IN_YPOS,y                   ; don't have high byte
  sta     dy
  bcc     .dyneg
  cmp     #21
  bcc     .yok
  bcs     .skip

.dyneg  cmp     <#-21
        bcc     .skip
        eor     <#-1
        adc     #0
.yok  
  ; A collision!
  lda #$01
  sta CARFOUND
  rts
  
.skip  
  ; Not a collision?
  lda #$00
  sta CARFOUND
  rts

CARFOUND
  .byte $00
  
dx
  .byte $00

dy
  .byte $00


; --------------------------------------------------------------------
; Damage exceeded 100, set up explosion animation sequence
INIT_EXPLOSION
  lda #$01
  sta CAR_DESTROYED
  
  lda #$08   ;and below
  sta FIREBALL_ANIM_COUNT 
  
  lda #$26
  sta sprite1pnt
  
  ;Set explosion to light red
  lda #$0a
  sta sprite1color
  
  ; Boom!
  jsr SOUND_KABOOM
  rts


; --------------------------------------------------------------------
; Animate explosion sprite but don't allow any user control

DESTROY_ANIM
  ;Slow me down
  lda MY_SPEED
  beq slow
  dec MY_SPEED
  
slow
  ; Slow down the animation of the fireball
  dec FIREBALL_ANIM_COUNT
  lda FIREBALL_ANIM_COUNT
  bne DESTROY_ANIM_x
  
  ;Restart counter
  lda #$08  ; and above
  sta FIREBALL_ANIM_COUNT

  inc sprite1pnt
  lda sprite1pnt
  cmp #$2F
  bne DESTROY_ANIM_x
  
  lda #$2F
  sta sprite1pnt  

  ; Decrease num cars remaining
  dec CARS
  beq GAME_OVER
  
  ;Start again at beginning of track -----------
RESETCAR
  lda MY_COLOR  
  sta sprite1color
  
  ldy PLAYERNUM
	lda STARTPOSITIONS,y
	sta MYXPOS+1
	lda #$00  
  sta MYXPOS
  sta MYXPOS+2
  
  lda #$00
  sta DAMAGE
  sta CAR_DESTROYED
  sta MYX_SPEED
  sta MYX_SPEED+1
  sta MY_SPEED
  sta MY_SPEED+1
  
  lda #$23
  sta sprite1pnt
  
  jsr RESETDAMAGEBAR
  jsr RESETTRACK
  jsr DRAWSCREEN1

DESTROY_ANIM_x
  rts
  
CAR_DESTROYED
  .byte $00

GAMEOVER_FLAG
  .byte $00

FIREBALL_ANIM_COUNT
  .byte $FF  ;Overwritten

; --------------------------------------------------------------------
; Game over!  Note this is still called repeatedly by the IRQ.

GAME_OVER
  lda #$01
  sta GAMEOVER_FLAG
  
  lda #$00
  sta $d418
  sta MY_SPEED
  sta MY_SPEED+1
  
  lda #$03
  ldx #$10
go1  
  sta GAMEOVERCOLOR,x
  dex
  bne go1

  lda $dc00    
  cmp #$6f  ; Fire button
  beq RESET_GAME
  rts

RESET_GAME
  lda #$00
  sta GAMEOVER_FLAG
  
  lda #$0f
  sta $d418
  
  lda #$00
  ldx #$10
go2 
  sta GAMEOVERCOLOR,x
  dex
  bne go2

  lda #$04
  sta CARS
  
  lda #$00
  sta SCORE
  sta SCORE+1
  sta SCORE+2
  
  jmp RESETCAR
   
; --------------------------------------------------------------------
; Sprite X to character cell lookup
XTOCHAR
  .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4
  .byte 5,5,5,5,6,6,6,6,7,7,7,7,8,8,8,8,9,9,9,9,10,10,10,10,11,11,11,11,12
  .byte 12,12,12,13,13,13,13,14,14,14,14,15,15,15,15,16,16,16,16,17,17,17,17
  .byte 18,18,18,18,19,19,19,19,20,20,20,20,21,21,21,21,22,22,22,22,23,23,23,23
  .byte 24,24,24,24,25,25,25,25,26,26,26,26,27,27,27,27,28,28,28,28,29,29,29,29
  .byte 30,30,30,30,31,31,31,31,32,32,32,32,33,33,33,33,34,34,34,34,35,35,35,35
  .byte 36,36,36,36,37,37,37,37,38,38,38,38,39,39,39,39

  

; --------------------------------------------------------------------
; Speeds received from other players - first byte is a dummy in all cases

IN_XSPEEDLOW
  .byte $FF,$00,$00,$00,$00,$00,$00,$00
  
IN_XSPEEDHIGH
  .byte $FF,$00,$00,$00,$00,$00,$00,$00
  
IN_YSPEEDLOW
  .byte $FF,$00,$00,$00,$00,$00,$00,$00

IN_YSPEEDHIGH
  .byte $FF,$00,$00,$00,$00,$00,$00,$00

IN_XPOSLOW
  .byte $FF,$00,$00,$00,$00,$00,$00,$00

IN_XPOSHIGH
  .byte $FF,$00,$00,$00,$00,$00,$00,$00
  
IN_YPOS
  .byte $FF,$00,$00,$00,$00,$00,$00,$00
  
IN_XPOS_D010
  .byte $0
