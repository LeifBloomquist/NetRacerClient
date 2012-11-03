; Sprites and graphics

COMMSLED = $DBBF

sprite1x = $D000
sprite1y = $D001
sprite2x = $D002
sprite2y = $D003
sprite3x = $D004
sprite3y = $D005
sprite4x = $D006
sprite4y = $D007
sprite5x = $D008
sprite5y = $D009
sprite6x = $D00A
sprite6y = $D00B
sprite7x = $D00C
sprite7y = $D00D
sprite8x = $D00E
sprite8y = $D00F

sprite1pnt = $07f8
sprite2pnt = $07f9
sprite3pnt = $07fa
sprite4pnt = $07fb
sprite5pnt = $07fc
sprite6pnt = $07fd
sprite7pnt = $07fe
sprite8pnt = $07ff

sprite1color = $D027
sprite2color = $D028
sprite3color = $D029
sprite4color = $D02A
sprite5color = $D02B
sprite6color = $D02C
sprite7color = $D02D
sprite8color = $D02E

MY_COLOR
  .byte $00

;------------------------------------------------------------------------------
; We are using these sprites:
; #1    = My Car
; #2-#7 = Other cars, as defined by server
; #8    = Repair points

SETUPSPRITES
  lda #$FF   ; All
  sta $D015
  
  ; My default location
  ldx MYXPOS
  ldy #150
  stx sprite1x
  sty sprite1y
   
  ;This also uses sprite multicolors, so set them here
  lda #$01
  sta $d025
  lda #$00
  sta $d026  
  
  ;Sprite pointers
  lda #$23
  sta sprite1pnt
  sta sprite2pnt
  sta sprite3pnt
  sta sprite4pnt
  sta sprite5pnt
  sta sprite6pnt
  sta sprite7pnt
  sta sprite8pnt
      
  ;Set Multicolors
  lda #$FF
  sta $d01c
  
  ;Sprite Colors
  ldy #$00
col1
  lda CARCOLORS,y
  sta sprite1color,y
  iny
  cpy #$09
  bne col1
  
  ; Clear sprite collision registers by reading them
  lda $d01e ; sprite-sprite
  lda $d01f ; background
  
  rts 
      
; ---------------------
; Car colors
CARCOLORS
  .byte $02,$03,$04,$05  
  .byte $06,$07,$08,$0e   
