; Sound Effects

;------------------------------------------------------------------------------
; Setup - clear sound chip and set maximum volume!

SOUND_SETUP
  ldx #$00
  txa
SETUP1
  sta $d400,x
  inx
  cpx #$19
  bne SETUP1
  
  lda #$0f
  sta $d418
  
  ;Set up sawtooth for Voice 1 (boring)
  lda #$f0
  sta $d406
  lda #$21
  sta $d404
  rts


;------------------------------------------------------------------------------
; Engine Sound - use Voice 1
SOUND_ENGINE
  ldy MY_SPEED
  lda SPEEDHI,y
  sta $d401
  lda SPEEDLO,y  
  sta $d400
  rts

SPEEDHI
  .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
  .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
  .byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
  .byte 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
  .byte 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4
  .byte 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
  .byte 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
  .byte 4,4,4,4,4,4,4,4,4,4,4

SPEEDLO
  .byte 0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57,60,63,66,69  
  .byte 72,75,78,81,84,87,90,93,96,99,102,105,108,111,114,117,120,123,126,129
  .byte 132,135,138,141,144,147,150,153,156,159,162,165,168,171,174,177,180  
  .byte 183,186,189,192,195,198,201,204,207,210,213,216,219,222,225,228,231  
  .byte 234,237,240,243,246,249,252,255,2,5,8,11,14,17,20,23,26,29,32,35,38  
  .byte 41,44,47,50,53,56,59,62,65,68,71,74,77,80,83,86,89,92,95,98,101,104  
  .byte 107,110,113,116,119,122,125,128,131,134,137,140,143,146,149,152,155  
  .byte 158,161,164,167,170,173,176,179,182,185,188,191,194,197,200,203,206  
  .byte 209,212,215,218,221,224,227,230,233,236,239,242,245,248,251,254,1,4  
  .byte 7,10,13,16,19,22,25,28,31,34,37,40,43,46,49,52,55,58,61,64,67,70,73  
  .byte 76,79,82,85,88,91,94,97,100,103,106,109,112,115,118,121,124,127,130  
  .byte 133,136,139,142,145,148,151,154,157,160,163,166,169,172,175,178,181  
  .byte 184,187,190,193,196,199,202,205,208,211,214,217,220,223,226,229,232  
  .byte 235,238,241,244,247,250,253                                                  
        
  
;------------------------------------------------------------------------------
; Called from within the IRQ.  Handles hard restart and retrigger timing.

;Number of frames between hard restart
SOUND_SIDECOUNT
  .byte $02

SOUND_TICK
  rts  ;!!!!
  lda SOUND_SIDECOUNT  ; Already at 0?  If so, leave it.
  beq SOUND_TICK_x
  
  dec SOUND_SIDECOUNT  ; Decrement.
  bne SOUND_TICK_x     ; Are we at 0?  If not yet, exit till next frame.
  
  ; Counter is done.  Trigger the sound.
  jsr SOUND_HITSIDE1
  
SOUND_TICK_x
  rts
  
;------------------------------------------------------------------------------
; Collision with Side - use Voice 2

SOUND_HITSIDE   ;Do hard restart and start timer
;  jsr HARDRESTART2
;  lda #$03
;  sta SOUND_SIDECOUNT
;  rts
  
SOUND_HITSIDE1
  lda #$0f
  sta $d40c  
  lda #$0A
  sta $d40d
  lda #$07    ; Pitch 
  sta $d408
  lda #$00
  sta $d407
  lda #$81
  sta $d40b
  lda #$80
  sta $d40b
  rts
  
;------------------------------------------------------------------------------
; Collision with Car - use Voice 2

SOUND_HITCAR
  lda #$00    ; 0 Attack, 0 Decay
  sta $d40c  
  lda #$09    ; 0 Sustain, ?? release 
  sta $d40d
  lda #$05    ; Pitch (High)
  sta $d408
  lda #$00    ; Pitch (Low)
  sta $d407
  lda #$81    ; Trigger
  sta $d40b
  lda #$80    ; Release
  sta $d40b
  rts

;------------------------------------------------------------------------------
; Hard restart of voice 2 so we can retrigger ADSR

HARDRESTART2
  lda #$00
  sta $d407
  sta $d408
  sta $d409
  sta $d40A
  sta $d40B
  sta $d40C
  sta $d40D
  rts


;------------------------------------------------------------------------------
; Completed a lap - voice 3

SOUND_LAP
  lda #$00
  sta $d413  
  lda #$09
  sta $d414
  lda #$40
  sta $d40F
  lda #$00
  sta $d40E
  lda #$11
  sta $d412
  lda #$10
  sta $d412
  rts

;------------------------------------------------------------------------------
; Network Timeout - voice 3

SOUND_TIMEOUT

  ; Mute engine sound
  lda #$00
  sta $d401 
  sta $d400

  ; Bingy beep
  lda #$00
  sta $d413  
  lda #$02
  sta $d414
  lda #$20
  sta $d40F
  lda #$00
  sta $d40E
  lda #$21
  sta $d412
  lda #$20
  sta $d412
  rts

;------------------------------------------------------------------------------
; Explosion - voice 3

SOUND_KABOOM
  lda #$00
  sta $d413  
  lda #$0B
  sta $d414
  lda #$02
  sta $d40F
  lda #$00
  sta $d40E
  lda #$81
  sta $d412
  lda #$80
  sta $d412
  rts


scrreel 
  .byte $00 
  
SCROLLSTART equ $0798

;------------------------------------------------------------------------------
; Music
INITMUSIC
  jsr $1000

	sei
	lda #$01
	sta $d019
	sta $d01a
	lda #$1b
	sta $d011
	lda #$7f
	sta $dc0d
	lda #$D5
	sta $d012
	lda #<SCROLL
	sta $0314
	lda #>SCROLL
	sta $0315
	cli
	
	; For scroll
  lda #<CREDITS
  sta msg+1     
  lda #>CREDITS 
  sta msg+2     
	rts


;This is the top of the raster split
SCROLL
	inc $d019
	lda #$20
	sta $d012
	lda #<PLAYMUSIC
	sta $0314
	lda #>PLAYMUSIC
	sta $0315
	
	; ------------------
  lda doscroll
  beq SCROLL_x  
  
  ;Scroll routine borrowed from richard bayliss!

  dec scrreel ; smoothness for
  lda scrreel ; our scrolltext
  and #$07    ; message using
  sta $d016   ; the screen x-pos
  cmp #$07    ; and counting 7
  bne SCROLL_x; times else
             ; move to the
             ; control sequence

         ldx #$00
message  lda SCROLLSTART,x   ; pull characters
         sta SCROLLSTART-1,x ; for the scroll
         inx
         cpx #$28
         bne message
       

msg      lda $FFFF   ; Overwritten

         cmp #$00    ;is '@' (wrap mark)
                     ;read? if not then
         bne end     ;jump to end prompt

         lda #<CREDITS ;reset msg+1
         sta msg+1       ;and msg+2 so
         lda #>CREDITS ;that the text
         sta msg+2       ;will restart
         jmp msg         ;then jump msg

end      
         sec
         cmp #$20  ;Spaces are OK
         beq show 
         cmp #$3A  ;Colons too
         beq show 
         sbc #$40  ;Convert all others to screencode

show
         sta SCROLLSTART+$27 ;place character, read from CREDITS

         inc msg+1 ;increment msg+1 by
         lda msg+1 ;one character so
         cmp #$00  ;is the reset counter
                   ;('@') marked? if not
                   ;then jump to control

         bne SCROLL_x
         inc msg+2 ;do the same for the high byte
  
SCROLL_x
  ;Color scroll
  lda #$01 
  ldx #$28
sx
  sta SCROLLSTART-1+$D400,x
  dex
  bne sx
	jmp $ea81

;This is the bottom of the raster split
PLAYMUSIC	
	inc $d019
	lda #$DC
	sta $d012
	lda #<SCROLL
	sta $0314
	lda #>SCROLL
	sta $0315
	
	lda #$c8 
	sta $d016  ;End horiz scroll
	
	;Using a PAL tune.  Skip every 6th frame if NTSC
	lda $2A6
  bne MUSIC_OK
	
	dec NTSCCOUNT
	bne MUSIC_OK
	lda #$07
	sta NTSCCOUNT
	jmp MUSIC_x
	
MUSIC_OK	
	jsr $1003
MUSIC_x
	jmp $ea31
	
NTSCCOUNT
  .byte $07

CREDITS
  .byte " CONCEPT AND FRAMEWORK: LEIF BLOOMQUIST   "
  .byte "NETWORK CODE: OLIVER VIEBROOKS   "
  .byte "DISPLAY CODE: ROBIN HARBRON AND LASSE OORNI   "  
  .byte "GRAPHICS: RAYMOND LEJUEZ   "
  .byte "MUSIC: ALEXANDER ROTZSCH   "
  .byte "SERVER HOSTING: IAN COLQUHOUN   "
  .byte "PLAYTESTERS: ROBIN HARBRON  DAVE MCMURTRIE  DAVE HARTMAN  "   
  .byte "              ", 0
  
  
  

doscroll
  .byte $01
