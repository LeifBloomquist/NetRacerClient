; NetRacer screen/track updates

SCREEN = $0400

DAMAGEBAR = $0789
DAMAGEBARCOLOR = DAMAGEBAR+$D400

SPEEDBAR = $0777
SPEEDBARCOLOR = SPEEDBAR+$D400

SCORELOC = $079F

CARSLOC = DAMAGEBAR+40

GAMEOVERCOLOR =  $0728+$D400

savea = $fc
savex = $fd
savey = $fe

RASTER_GSCREEN_POS = 250  ; 250
RASTER_PANEL_POS   = 205  ; 221
RASTER_PANEL2_POS  = 215  ; 214 230

MY_SPEED
VERTSCROLLRATE       ; Effectively, my speed
	dc.b $00,$00       ; Low/High (high not used, keep at 0 for now)

VERTSCROLLFRACTION   ; Low
	dc.b $00

VERTSCROLL           ; High
	dc.b $00
	
DRAWSCREENFLAG      ;Without this, the screen would constantly be scrolled if VERTSCROLL was 0
  dc.b $00  

DAMAGETEMP
  .byte $00 

SPEEDTEMP
  .byte $00 

raster_idle:	
  dec $d019
	jsr NETWORK_UPDATE
	jmp $ea81

;===========================
; IRQ - Top
;===========================

IRQ	SUBROUTINE
	cld
	sta savea
	stx savex
	sty savey
	
	;Set gamescreen scrolling
rgscr_scrx:
	lda #$18   ; was $17   No scrolling, 40 columns, multicolor
	sta $d016
rgscr_scry:
	lda #$17  
	sta $d011
	
	;Road Color
  lda #$0b  ; Grey
  sta $d021
	
	lda #255
	sta $d015
	;Put sprites back on screen
	lda IN_XPOSLOW+1
	sta $d002
	lda IN_XPOSLOW+2
	sta $d004
	lda IN_XPOSLOW+3
	sta $d006
	lda IN_XPOSLOW+4
	sta $d008
	lda IN_XPOSLOW+5
	sta $d00a
	lda IN_XPOSLOW+6
	sta $d00c
	lda IN_XPOSLOW+7
	sta $d00e
	
	lda MYXPOS+2
	and #1
	ora IN_XPOS_D010
	sta $d010

	;Check for network timeout
	lda NET_TIMEDOUT
	beq checkgame
	jmp .done

checkgame
	;Don't update game just yet
	lda GAMEACTIVE
	bne dotrack
  jmp .done

dotrack
	; Change border color to measure IRQ time
	BORDER $02
	
	;Game Tick
	;jsr GAME_TICK
	
	;Sound Tick
	;jsr SOUND_TICK
	
	; Find the absolute track position
	; 16-bit addition   
  clc
  lda REALTRACKPOS
  adc VERTSCROLLRATE
  sta REALTRACKPOS
  lda REALTRACKPOS+1
  adc VERTSCROLLRATE+1
  sta REALTRACKPOS+1
  lda REALTRACKPOS+2
  adc #$0
  sta REALTRACKPOS+2
  
	; increment smooth scroll counter based on current speed
	; 16-bit addition   
  clc
  lda VERTSCROLLFRACTION
  adc VERTSCROLLRATE
  sta VERTSCROLLFRACTION
  bcc CHECKSCROLL  
  ;lda VERTSCROLL
  ;adc VERTSCROLLRATE+1
  ;sta VERTSCROLL
  inc VERTSCROLL

  ; Animate car sprite when screen scrolls
  lda CAR_DESTROYED
  bne CHECKSCROLL
  inc sprite1pnt
  lda sprite1pnt
  cmp #$26
  bne CHECKSCROLL  
  lda #$23
  sta sprite1pnt

CHECKSCROLL

	lda VERTSCROLL
	cmp #8
	bne set_smooth_scroll ;don't need to shift screen
	
	lda #0
	sta VERTSCROLL ;reset smooth scroll
	
	lda #$00   ; Set that screen can be redrawn now (once)
	sta DRAWSCREENFLAG

set_smooth_scroll
	; Set current scroll
	lda #$10 ;$d011
	and #%11111000
	ora VERTSCROLL
	sta $d011

	lda VERTSCROLL
	bne .done ;screen does not need to be redrawn
	
	;Draw new screen pos - only once per 8 pixels!!
	lda DRAWSCREENFLAG
	bne .done
	jsr DRAWSCREEN
	lda #$01
	sta DRAWSCREENFLAG
	jmp .nonetwork   ; Don't poll network if screen is scrolled - not enough raster time!
	
.done
  BORDER $06
	jsr NETWORK_UPDATE

.nonetwork	
	BORDER $00
	
	lda #<IRQ1              ;Set vector & raster position
	sta $fffe                       ;for next IRQ
	lda #>IRQ1
	sta $ffff
	lda #RASTER_PANEL_POS
	sta $d012
	lda savea
	ldx savex
	ldy savey
	dec $d019                       ;Acknowledge IRQ
nmi:
	rti

;===========================
; IRQ - Bottom
;===========================

IRQ1	SUBROUTINE
 	sta savea
	lda $d011                       ;Are we going to hit a bad
	cmp #$15                        ;line when setting the
	beq rpanel_badline              ;new $d011 & $d018 values?
	lda #$17
	sta $d011
	pha                             ;No, delay
	pla
	pha
	pla
	nop
	nop
	nop
	nop

rpanel_badline:
	stx savex
	lda #$57                        ;Blank screen
	sta $d011
	sty savey
rpanel_direct:
	cld
	;inc rastercount
	lda #$00                        ;Set bg.colors
	sta $d021
	sta $d015                       ;Sprites off
	;lda #PANELMC1
	;sta $d022
	;lda #PANELMC2
	;sta $d023
	lda #$0                        ;All sprites to bottom of
	;sta $d001                       ;screen (so that no "ghosts"
	sta $d002                       ;appear when sprites move
	sta $d004                       ;downwards)
	sta $d006
	sta $d008
	sta $d00a
	sta $d00c
	sta $d00e
	sta $d010
	lda #<IRQ2             ;Set vector & raster position
	sta $fffe                       ;for next IRQ
	lda #>IRQ2
	sta $ffff
	lda #RASTER_PANEL2_POS
	sta $d012
	lda savea
	ldx savex
	ldy savey
	dec $d019
	rti
		
IRQ2
	cld
	sta savea
	stx savex
	sty savey
	lda #$17             ;Screen visible now
	sta $d011
	lda #$08            ; No scrolling, 40 columns, no multicolor        
	sta $d016           ;X-scrolling in place
	lda #$37
	sta $1

;------------------------------------------
; Status Display

;Damage  
  ldx #$00
  ldy DAMAGE
  beq SHOWSPEED  ;Zero
  sty DAMAGETEMP
  
  ;Solid bars
  sec
d1
  lda DAMAGETEMP
  sbc #$08
  bmi d2
  sta DAMAGETEMP
  lda #$80
  sta DAMAGEBAR,x
  inx
  jmp d1
    
d2
  ldy DAMAGETEMP
  lda DAMAGEPORTION,y
  sta DAMAGEBAR,x
	
SHOWSPEED
  ; Clear out bar first
  lda #$20 ;Space
  ldx #$09
sp0
  sta SPEEDBAR-1,x
  dex
  bne sp0

  ldx #$00
  lda MY_SPEED
  beq SHOWSCORE  ;Zero
  lsr
  lsr
  tay  
  sty SPEEDTEMP
  
  ;Solid bars
  sec
sp1
  lda SPEEDTEMP
  sbc #$08
  bmi sp2
  sta SPEEDTEMP
  lda #$80
  sta SPEEDBAR,x
  inx
  jmp sp1
    
sp2
  ldy SPEEDTEMP
  lda DAMAGEPORTION,y
  sta SPEEDBAR,x
	
SHOWSCORE
	jsr DISPLAYSCORE
SHOWCARS
  clc
  lda CARS
  adc #$30  ;Map to screen code
  sta CARSLOC  

STATSDONE  
	;Game Tick
	jsr GAME_TICK
	
	;Sound Tick
	jsr SOUND_TICK
	
	
	lda #$35
	sta $1

	lda #<IRQ            ;Set vector & raster position
	sta $fffe                       ;for next IRQ
	lda #>IRQ
	sta $ffff
	lda #RASTER_GSCREEN_POS
	sta $d012
	lda savea
	ldx savex
	ldy savey
	dec $d019
	rti

;===========================
DISPLAYSCORE ;display BCD score
;===========================

	ldx #0
	ldy #2
	
.loop	lda SCORE,y
	lsr
	lsr
	lsr
	lsr
	clc
	adc #$30
	sta SCORELOC,x
	inx
	
	lda SCORE,y
	and #$0f
	clc
	adc #$30
	sta SCORELOC,x
	inx
	
	dey
	bpl .loop
	
	rts

;===========================
; Screen Draw routine
;===========================

DRAWSCREEN SUBROUTINE

  ; This earns 1 point!
  lda #01
  ldx #00
  jsr INCSCORE

DRAWSCREEN1
	;move position in track - maybe later a camera routine will handle this
	sec
	lda TRACKPOS
	sbc #40
	sta TRACKPOS
	lda TRACKPOS+1
	sbc #0
	sta TRACKPOS+1
  
  ; Check if we're at the start, and reset if so
  lda TRACKPOS
  cmp #<TRACK
  bne PREPSCROLL
  lda TRACKPOS+1
  cmp #>TRACK
  bne PREPSCROLL

; -----------------------------------
; Finished a lap
  
  ; This earns 1000 points!
  ;lda #<1000  ; Decimal
  ;ldx #>1000
  lda #00
  ldx #10 ; BCD 1000
  jsr INCSCORE
  jsr SOUND_LAP
  
  ; And takes off 20 damage
  sec
  lda DAMAGE
  sbc #20       ;Decimal
  bmi damage0 
  
  sta DAMAGE
  jmp rok

damage0
  lda #$00
  sta DAMAGE
  ;drop thru
  
rok  
  jsr RESETDAMAGEBAR
  jsr RESETTRACK

PREPSCROLL
	;prepare to do scroll
	lda TRACKPOS
	sta .sm1+1
	lda TRACKPOS+1
	sta .sm1+2
	
	lda #<SCREEN
	sta .sm2+1
	lda #>SCREEN
	sta .sm2+2
	
	ldy #20 ;rows to draw
.loop1	ldx #39 ;columns
.sm1	lda $ffff,x ;track map data
.sm2	sta $ffff,x ;screen position
	dex
	bpl .sm1

	;set up for next row of screen and track	
	clc
	lda .sm1+1
	adc #40
	sta .sm1+1
	bcc .ahead1
	inc .sm1+2

.ahead1	clc
	lda .sm2+1
	adc #40
	sta .sm2+1
	bcc .ahead2
	inc .sm2+2

.ahead2	dey
	bne .loop1
	rts

;-----------------------------------------
;set start position for track scroll
;-----------------------------------------
RESETTRACK
	lda #<START_POINT
	sta TRACKPOS
	lda #>START_POINT
	sta TRACKPOS+1
	
	lda #$00
	sta REALTRACKPOS
	sta REALTRACKPOS+1
	sta REALTRACKPOS+2    ; Reaches max of 1591 - why?
	rts


;-------------------------
; Clear damage bar
RESETDAMAGEBAR 
  ldy #14
  lda #$20
r1
  sta DAMAGEBAR-1,y
  dey
  bne r1
  rts

;-----------------------------------------
;lookup for damage bar
DAMAGEPORTION
  .byte $20,$81,$82,$83,$84,$85,$86,$87,$88

;-----------------------------------------
; Colors of the damage bar (no multicolor)
DAMAGEBARCOLORS
  .byte 5,5,5,5,5,7,7,7,7,7,2,2,2,2
  
;-----------------------------------------
;Track position in memory
TRACKPOS dc.b 0,0

; Absolute track postion 0-2000, to be be transmitted to server
REALTRACKPOS 
  dc.b 0 ;(fraction, not sent)
  dc.b 0,0

TRACK
   dc.b "LAAAAAB                         JAAAAAAL"
   dc.b "LAAAAB                          JAAAAAAL"
   dc.b "LAAAB                           JAAAAAAL"
   dc.b "LAAB                            JAAAAAAL"
   dc.b "LAB                             JAAAAAAL"
   dc.b "LB                              JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"   
   dc.b "K                               JAAAAAAL"
   dc.b "K                               SPPPPPPP"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"   
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL" ;END  LINE 731
; Above must match from START_POINT onward  - TODO move to a common include file
   dc.b "LIM                            NAAAAAAAL"
   dc.b "LAAM                           JAAAAAAAL"
   dc.b "LAAAM                          JAAAAAAAL"
   dc.b "LAOAAM                         JAAAAAOAL"
   dc.b "LAAAAAM                        JAAAAAAAL"
   dc.b "LAAAAAAM                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       CAAAAAAAL"
   dc.b "LAAAAAAK                        CAAAAAAL"
   dc.b "LAAAAAAK                         CAAAAAL"
   dc.b "LAAAAAAK                          CAAAAL"
   dc.b "LAAAAAAK                           CAAAL"
   dc.b "LAAAAAAK                            JAAL"
   dc.b "LAAAAAAB                            JAAL"
   dc.b "LAAAAAB                             JAAL"
   dc.b "LAAAAK           GIIIIIIH           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           JAAAAAAK           JAAL"
   dc.b "LAAAAK           CAAAAAAB           JAAL"
   dc.b "LAAAAK            CAAAAB            JAAL"
   dc.b "LAAAAK             CAAB             JAAL"
   dc.B "LAAAAAM             CB              JAAL"
   dc.b "LAAAAAAM                            JAAL"
   dc.b "LAAAAAAK                            JAAL"
   dc.b "LAAAAAAAM                           JAAL"
   dc.b "LAAAAAAAAM                          JAAL"
   dc.b "LAAAAAAAAAM                         JAAL"
   dc.b "LAAAAAAAAAAM                        JAAL"
   dc.b "LAAAAAAAAAAAM                       JAOL"
   dc.b "LAAAAAAAAAAAAM                      JAAL"
   dc.b "LAAAAAAAAAAAAAM                     JAAL"
   dc.b "LAAAAAAAAAAAAAAM                    JAAL"
   dc.b "LAAAAAAAAAAAAAAB                    JAAL"
   dc.b "LAAAAAAAAAAAAAB                     JAAL"
   dc.b "LAAAAAAAAAAAAK                      JAAL"
   dc.b "LAAAAAAAAAAAAK                     NAAAL"
   dc.b "LAAAAAAAAAAAAB                     JAAAL"
   dc.b "LAAAAAAAAAAAB                     NAAAAL"
   dc.b "LAAAAAAAAAAB                      JAAAAL"
   dc.b "LAAAAAAAAAB                       JAAAAL"
   dc.b "LAAAAAAAAB                       NAAAAAL"
   dc.b "LAAAAAAAB                       NAAAAAAL"
   dc.b "LAAAAAAK                       NAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAAAK                       JAAAAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOAAOAK                       JAAOAAOAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAAAAAAK                       JAAAAAAAL"
   dc.b "LAOVAAAAIIIM          NIIIIIIIIAAAWAAOAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   Dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAK          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAVAAAAAAAB          JAAAAAAAAAAAWAAAAL"
   dc.b "LAAAAAAAAAB           CAAAAAAAAAAAAAAAAL"
   dc.b "LAAAAAAAAB             CAAAAAAAAAAAAAAAL"
   dc.b "LAAAAAAAB               CAAAAAAAAAAAAAAL"
   dc.b "LAAAAAAK                 CAAAAAAAAAAAAAL"
   dc.b "LAAAAAAK                  CAAAAAAAAAAAAL"
   dc.b "LAAAAAAK                   CAAAAAAAAAAAL"
   dc.b "LAAAAAAK                    CAAAAAAAAAAL"
   dc.b "LAAAAAAK                     CAAAAAAAAAL"
   dc.b "LAAAAAAK                      CAAAAAAAAL"
   dc.b "LAAAAAAB                       JAAAAAAAL"
   dc.b "LAAAAAB                        JAAAAAAAL"
   dc.b "LAAAAB                         JAAAAAAAL"
   dc.b "LAAAB                          JAAAAAAAL"
   dc.b "LAAB                           JAAAAAAAL"
   dc.b "LAK                            JAAAAAAAL"
   dc.b "LAK                            JAAAAAAAL"
   dc.b "LAK         NM                 JAAAAAAAL"
   dc.b "LAK        NAAM                JAAAAAAAL"
   dc.b "LAK       NAAAAM               JAAAAAAAL"
   dc.b "LAK      NAAAAAAM             NAAAAAAAAL"
   dc.b "LAK      JAOAAOAK            NAAAAAAAAAL"
   dc.b "LAK      JAAAAAAK           NAAAAAAAAAAL"
   dc.b "LAK      JAOAAOAK          NAAAAAAAAAAAL"
   dc.b "LAK      CAAAAAAB         NAAAAAAAAAAAAL"
   dc.b "LAK       CAAAAB         NAAAAAAAAAAAAAL"
   dc.b "LAK        CAAB         NAAAAAAAAAAAAAAL"
   dc.b "LAK         CB         NAAAAAAAAAAAAAAAL"
   dc.b "LAK                   NAAAAAAAAAAAAAAAAL"
   dc.b "LAAM                  JAAAAAAAAAAAAAAAAL"
   dc.b "LAAAM                 JAAAAAAAAAAAAAAAAL"
   dc.b "LAAAAM                JAAAAAAAAAAAAAAAAL"
   dc.b "LAAAAAM               CAAAAAAAAAAAAAAAAL"
   dc.b "LAAAAAAM               CAAAAAAAAAAAAAAAL"
   dc.b "LAAAAAAAM               CAAAAAAAAAAAAAAL"
   dc.b "LAAAAAAAAM               CAAAAAAAAAAAAAL"
   dc.b "LAAAAAAAAAM               CAAAAAAAAAAAAL"
   dc.b "LAAAAAAAAAAM               CAAAAAAAAAAAL"
   dc.b "LAAAAAAAAAAAM               CAAAAAAAAAAL"
   dc.b "LAAAAAAAAAAAAM               CAAAAAAAAAL"
   dc.b "LAAAAAAAAAAAAAM               CAAAAAAAAL"
   dc.b "LAAAAAAAAAAAAAK                CAAAAAAAL"
   dc.b "LAAAAAAAAAAAAAK                 CAAAAAAL"
   dc.b "LAAAAAAAAAAAAAK                  CAAAAAL"
   dc.b "LAAAAAAAAAAAAAK                   CAAAAL"
   dc.b "LAAAAAAAAAAAAAK                    CAAAL"
   dc.b "LAAAAAAAAAAAAAB                     JAAL"
   dc.b "LAAAAAAAAAAAAB                      JAAL"
   dc.b "LAAAAAAAAAAAB                       JAAL"
   dc.b "LAAAAAAAAAAB                        JAAL"
   dc.b "LAAAAAAAAAB                        NAAAL"
   dc.b "LAAAAAAAAB                        NAAAAL"
   dc.b "LAAAAAAAB                         JAAAAL"
   dc.b "LAAAAAAK                          JAAAAL"
   dc.b "LAAAAAAK                         NAAAAAL"
   dc.b "LAAAAAAK                         JAAAAAL"
   dc.b "LAAAAAAK                         JAAAAAL"
   dc.b "LAAAAAAK                         JAAAAAL"
   dc.b "LAAAAAAB                        NAAAAAAL"
START_POINT   
   dc.b "LAAAAAB                         JAAAAAAL"
   dc.b "LAAAAB                          JAAAAAAL"
   dc.b "LAAAB                           JAAAAAAL"
   dc.b "LAAB                            JAAAAAAL"
   dc.b "LAB                             JAAAAAAL"
   dc.b "LB                              JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"   
   dc.b "K                               JAAAAAAL"
   dc.b "K                               SPPPPPPP"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"   
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL"
   dc.b "K                               JAAAAAAL" ;END  LINE 737
