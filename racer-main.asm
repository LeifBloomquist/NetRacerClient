	processor 6502
	org $0801

	;"Net Spy Hunter" scroll test code
	;by Leif Bloomquist, Robin Harbron, some IRQ code stolen from Lasse Oorni

	include "macros.asm"	

BASIC ;6 sys 2064
	dc.b $0c,$08,$06,$00,$9e,$20,$32,$30
	dc.b $36,$34,$00,$00,$00,$00,$00

START	SUBROUTINE
  lda #$00
  sta $d020
  sta $d021
  sta GAMEACTIVE
  sta LANMODE
  jsr INITMUSIC
  jmp GO

  ; A few wasted bytes here	
  
	; Sprites!
  org $08c0               ;Sprite offsets $23 to $25
  incbin "sprites/racecar_black.spr"
  
  ;Sprite offset $26 to $2F
  incbin "sprites/duel-explosions.spr"
  
  ;Sprite offset $30 - blank
  ds.b 64,0
  
GO
  ;Charset
  lda #$18
  sta $d018
  
  jsr TITLESCREEN
  
  
WAITFORBUTTON  
  lda $dc00
  cmp #$6f
  bne CHECKKEYS
  
  jmp STARTGAME
 
CHECKKEYS 
  jsr $ffe4
  
  cmp #$4E    ; N
  bne kg
  jmp GETNEWIP

kg  
  cmp #$47    ; G
  bne kl  
  jmp GETNEWGW 

kl
  cmp #$4C    ; L
  bne ks 
  jmp SETLANMODE
  
ks  
  cmp #$53    ; S
  bne WAITFORBUTTON  
  jmp GETNEWSERVER
  
   
  ; Ask for opponent's IP address and redisplay.
GETNEWIP	 
	PRINT CG_CLR,CG_BLU,"NEW IP ADDRESS? ",CG_YEL
	jsr getip
	lda IP_OK
	beq GETNEWIP   ;Zero if IP was invalid

  lda gotip
  sta CARD_IP
	lda gotip+1
  sta CARD_IP+1
	lda gotip+2
  sta CARD_IP+2
  sta CARD_GATE+2
	lda gotip+3
  sta CARD_IP+3
  jmp GO

  ; Ask for gateway IP address and redisplay.
GETNEWGW	 
	PRINT CG_CLR,CG_BLU,"NEW GATEWAY ADDRESS? ",CG_YEL
	jsr getip
	lda IP_OK
	beq GETNEWGW   ;Zero if IP was invalid

  lda gotip
  sta CARD_GATE
	lda gotip+1
  sta CARD_GATE+1
	lda gotip+2
  sta CARD_GATE+2
	lda gotip+3
  sta CARD_GATE+3
  jmp GO
 
LANMODE
  .byte $00
  
SETLANMODE
  lda #$01
  sta LANMODE
  lda SERVER_IP_LAN
  sta SERVER_IP
  lda SERVER_IP_LAN+1
  sta SERVER_IP+1
  lda SERVER_IP_LAN+2
  sta SERVER_IP+2
  lda SERVER_IP_LAN+3
  sta SERVER_IP+3
  jmp GO  

  ; Ask for server IP address and redisplay.
GETNEWSERVER	 
	PRINT CG_CLR,CG_BLU,"NEW SERVER ADDRESS? ",CG_YEL
	jsr getip
	lda IP_OK
	beq GETNEWSERVER   ;Zero if IP was invalid

  lda gotip
  sta SERVER_IP
	lda gotip+1
  sta SERVER_IP+1
	lda gotip+2
  sta SERVER_IP+2
	lda gotip+3
  sta SERVER_IP+3
  jmp GO


STARTGAME
 ; Pick car type
  jsr SETUPSPRITES
  jsr PICKCAR
  
  PRINT CRLF  
  jsr NETWORK_SETUP
  jsr irq_init
  jsr SOUND_SETUP
     
  lda NET_FAILED
  bne wait1x
  
  jsr GATEWAYMAC   ; Automatically determines if GW is on LAN or not
  
  ; If we're in LAN  mode, we need the server's MAC instead of the GW's MAC.
  lda LANMODE
  beq SETUPDONE
  
  jsr SERVERMAC

SETUPDONE  
  lda #$01
  sta NETSETUPFINISHED
    
  PRINT CG_WHT, CRLF,CRLF, "WAITING FOR SERVER...(FIRE BUTTON SKIPS)"
  
wait1
  lda $dc00
  cmp #$6f
  beq wait1x

  lda PACKET_RECEIVED
  beq wait1
  
wait1x

	jsr RESETTRACK
	jsr SETUPSPRITES   ; Resets default positions
	
	;Default position and speed
	ldy PLAYERNUM
	lda STARTPOSITIONS,y
  sta MYXPOS+1
	lda #$00  
  sta MYXPOS
  sta MYXPOS+2
  sta MYX_SPEED
  sta MYX_SPEED+1 
  sta MY_SPEED
  sta MY_SPEED+1
  sta DAMAGE
  sta sprite2x
  sta sprite2y
  sta sprite3x
  sta sprite3y
  sta sprite4x
  sta sprite4y
  sta sprite5x
  sta sprite5y
  sta sprite6x
  sta sprite6y
  sta sprite7x
  sta sprite7y
  sta sprite8x
  sta sprite8y
  
  lda MY_COLOR
  sta sprite1color
	
;---------------------------------
; Screen setup

  jsr RESETTRACK
  jsr DRAWSCREEN1

	;Paint screen  (+$08 = multicolor)
	lda #$01+$08
	sta $0286
	PRINT CG_CLR
	lda #$01+$08
	
	; Explicitly paint screen color, for older kernals
  ldx #$00  
SCREENCOLOR	
  sta $d800,x
  sta $d900,x
  sta $da00,x
  sta $dae7,x 
  inx
  bne SCREENCOLOR	
	
	;Multicolors
	lda #$0e
	sta $d022
	lda #$06
	sta $d023

  ; Logo
  PLOT 0,20 
  PRINT CG_YEL,"NET",CG_RED,"RACER",CG_BLK,"        GAME OVER!"

	; Status Lines
	PLOT 0,22
	PRINT CG_WHT,"SPEED: ", CG_BLU, "        "
	PLOT 0,23
	PRINT CG_WHT,"SCORE:        "
	PLOT 17,22
	PRINT "DAMAGE:"
	PLOT 17,23
	PRINT "  CARS:     "
	
	jsr RESETDAMAGEBAR
	
	ldy #$00
s1
  lda DAMAGEBARCOLORS,y
  sta DAMAGEBARCOLOR,y
  iny
  cpy #13 ; Decimal
  bne s1
	
	; Start rest of IRQ
  lda #$01
  sta GAMEACTIVE	

  ; Comms "LED"
  lda #$51
  sta $07bf

	lda #$35                        ;Set all ROM off, IO on.
	sta $01
	
	lda #$04
	sta CARS
	
LOOP
	jmp LOOP
	
	;This part ends around 0f35, so a few wasted bytes here.
	
; =================================================================
; Binary Includes
; =================================================================
  ;Include music here
  org $0ffe  ; $1000-2, because of the load address
  incbin "music/Speedroad.dat"  
  
  ;Include charset here
  org $1ffe  ; $2000-2, because of the load address
  incbin "charset/netracer.font" 
	

; -----------------------------------------------------------------
 
irq_init SUBROUTINE
	sei
	lda #<raster_idle               ;Set an idle-IRQ which will
	sta $0314                       ;be used when KERNAL is on
	lda #>raster_idle
	sta $0315

	lda #<IRQ                       ;Set vector & raster position
	sta $fffe                       ;for next IRQ
	lda #>IRQ
	sta $ffff
	lda #RASTER_GSCREEN_POS
	sta $d012
	lda #$10                        ;Set high bit of raster
	sta $d011                       ;position (0) but don't blank screen
	lda #$7f                        ;Set timer interrupt off
	sta $dc0d
	lda #$01                        ;Set raster interrupt on
	sta $d01a
	lda $dc0d                       ;Acknowledge timer interrupt
	cli
	rts


; ----------------------------------------------------------
; Choose car design.
PICKCAR
  PRINT CG_CLR,CRLF,CG_WHT,"CHOOSE CAR:", CRLF, CRLF
  
  PRINT "  1   2   3   4   5   6   7   8", CRLF
  PRINT CG_RVS, CG_GR1, "                                 ", CRLF
  PRINT CG_RVS, CG_GR1, "                                 ", CRLF
  PRINT CG_RVS, CG_GR1, "                                 ", CRLF

  lda #$53
  sta sprite1y
  sta sprite2y
  sta sprite3y
  sta sprite4y
  sta sprite5y
  sta sprite6y
  sta sprite7y
  sta sprite8y
    
  ldy #$01   ; car#
  ldx #$00   ; sprite pointer
cloop
  lda STARTPOSITIONS,y
  sta sprite1x,x
  inx
  inx
  iny
  cpy #$09
  bne cloop
  
WAITFORCAR
  jsr $ffe4
  beq WAITFORCAR
  
c1
  cmp #$31
  bne c2
  ldy #$00 
  jmp PICKCAR_x
c2
  cmp #$32
  bne c3
  ldy #$01
  jmp PICKCAR_x
c3
  cmp #$33
  bne c4
  ldy #$02
  jmp PICKCAR_x
c4
  cmp #$34
  bne c5
  ldy #$03
  jmp PICKCAR_x
c5
  cmp #$35
  bne c6
  ldy #$04
  jmp PICKCAR_x
c6
  cmp #$36
  bne c7
  ldy #$05
  jmp PICKCAR_x
c7
  cmp #$37
  bne c8
  ldy #$06
  jmp PICKCAR_x
c8  
  cmp #$38
  bne WAITFORCAR
  ldy #$07
  jmp PICKCAR_x
  
PICKCAR_x
  lda CARCOLORS,y
  sta MY_COLOR   ; My color   
  iny
  sty PLAYERNUM
  
; For private LAN, also set the last octet of IP address and MAC with this.
  lda LANMODE
  beq PICKCAR_rts
  
  clc
  tya
  adc #100
  tay
  sty CARD_IP+3
  sta CARD_MAC+5
  
  PRINT CRLF, CG_BLU, "CHANGED IP ADDRESS TO ", CG_YEL
  PRINT_IP CARD_IP
  
PICKCAR_rts 
  rts

;---------------------------------------------------------------
TITLESCREEN

  PRINT CG_CLR,CG_DCS,CG_YEL,"NET",CG_RED,"RACER ", CG_LBL, "1.1",CRLF,CRLF
  
  PRINT CG_LGN,"USE JOYSTICK IN PORT 2",CRLF
  PRINT CG_LGN,"RUN/STOP KEY RESETS GAME",CRLF,CRLF
  
  PRINT CG_BLU,"MY ADDRESS IS ", CG_YEL
  PRINT_IP CARD_IP

  PRINT CG_BLU, "MY NETMASK IS ", CG_YEL
  PRINT_IP CARD_MASK  

  PRINT CG_BLU, "MY GATEWAY IS ", CG_YEL 
  PRINT_IP CARD_GATE
  
  PRINT CRLF,CG_LBL, "SERVER ADDRESS IS ", CG_YEL 
  PRINT_IP SERVER_IP
  PRINT CRLF
  
  lda LANMODE
  beq NOTLAN
  
  PRINT CG_RED, "LAN MODE SET",CRLF,CRLF
  jmp SHOWIRC

NOTLAN  
  PRINT CG_RED, "FORWARD UDP PORT 3000 IN YOUR ROUTER!", CRLF,CRLF

SHOWIRC
  PRINT CG_LGN, "IRC CHANNEL: NEWNET #NETRACER",CRLF,CRLF  
  
  PRINT CG_GR2,"PRESS ",CG_WHT,"N",CG_GR2," TO CHANGE NETWORK ADDRESS", CRLF
  PRINT CG_GR2,"PRESS ",CG_WHT,"G",CG_GR2," TO CHANGE GATEWAY ADDRESS", CRLF
  PRINT CG_GR2,"PRESS ",CG_WHT,"S",CG_GR2," TO CHANGE SERVER ADDRESS", CRLF
  PRINT CG_GR2,"PRESS ",CG_WHT,"L",CG_GR2," FOR LAN MODE", CRLF
  PRINT CRLF,  "PRESS ",CG_WHT,"FIRE BUTTON",CG_GR2, " TO START GAME"
  rts

;Initial car positions - note decimal  (0=dummy since no car 0)
STARTPOSITIONS
  .byte 0,32,64,96,128,160,192,224,255

PLAYERNUM
  .byte 0
 
 ; Flags  
GAMEACTIVE
  .byte 0 
  
; Includes
   include "joystick.asm"
   include "ipaddress.asm"                    
   include "racer-game.asm"
   include "racer-screen.asm"
   include "racer-graphics.asm"
   include "racer-soundfx.asm"
   include "racer-utils.asm"
   include "racer-network.asm"            
   include "SIXNET.ASM"   ; Must always be last so buffer is at end!
