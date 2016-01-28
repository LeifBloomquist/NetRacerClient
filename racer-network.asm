
; Network stuff for racing game

CARD_MAC	 dc.b $00,$80,$10,$0c,$64,$01
CARD_IP		 dc.b 192,168,1,64
CARD_MASK	 dc.b 255,255,255,0
CARD_GATE	 dc.b 192,168,1,1
CARD_GATE_MAC	dc.b $00,$00,$00,$00,$00,$00

SERVER_IP
  .byte 208,79,218,201    ; Public

SERVER_IP_LAN  
  .byte 192,168,7,100     ; Private
  
; Default,  overwritten by ARP
SERVER_MAC
  .byte $01,$02,$03,$04,$05,$06
  

USER_UDP_PORT = 3000
  
UDP_DATA_IN equ INPACKET+$2A  ; Beginning of UDP data buffer

;Various Flags...

PACKET_RECEIVED   ; Flag for incoming data
  .byte $00

NETSETUPFINISHED
  .byte $00

NETWORK_TIMEOUT   ; Reset by packet receive. 
                  ; If this goes above a threshold, means no data received
  .byte $00
  
NET_TIMEDOUT  ; Flag for main game loop
  .byte $00
  
NET_FAILED
  .byte $00

;----------------------------------------------------------------
; Called from main program
NETWORK_SETUP

  PRINT CG_RED
  ; Basic card initialization
  jsr net_init   ; Carry set if failed
  bcc UDPSETUP
  
  ;Failed
  jsr getanykey
  lda #$01
  sta NET_FAILED
  jmp NETWORK_SETUP_x

UDPSETUP
  ; UDP Setup
  lda #<3000   ; This doesn't have to match USER_UDP_PORT, but it does
  ldx #>3000
  jsr UDP_SET_SRC_PORT
  
  lda #<3002
  ldx #>3002
  jsr UDP_SET_DEST_PORT
  
  lda #<SERVER_IP
	ldx #>SERVER_IP
	jsr UDP_SET_DEST_IP

NETWORK_SETUP_x
  lda #$00
  sta PACKET_RECEIVED 
  rts

; -------------------------------------------------------------------------
; Called from IRQ
NETWORK_UPDATE
  jsr NETIRQ
  
  lda NETSETUPFINISHED
  beq NETWORK_UPDATEx
  
  lda NET_FAILED
  bne NETWORK_UPDATEx
    
  jsr SENDUPDATE
  
  ;Network timeouts
  lda NET_TIMEDOUT   ; Timeout in progress
  bne NTIMEOUT
  
  inc NETWORK_TIMEOUT
  lda NETWORK_TIMEOUT
  
  ; Packets are sent every 50 milliseconds (20/sec)
  ; This routine is called every ~17 ms (NTSC)
  ; If we go 30 calls (~0.5 seconds) without a packet, freeze game.
  cmp #30  ;Decimal
  blt NETWORK_UPDATEx
     
  lda #$01
  sta NET_TIMEDOUT
  lda #$00
  sta PACKET_RECEIVED
  jsr NTIMEOUT
  
NETWORK_UPDATEx
  rts

NTIMEOUT 
  lda #$02
  sta $d020

  jsr SOUND_TIMEOUT
  lda PACKET_RECEIVED
  beq NTIMEOUT_x              ; No packet yet

  lda #$00
  sta $d020
  sta NET_TIMEDOUT
  
NTIMEOUT_x
  rts


; -------------------------------------------------------------------------
; Get Gateway MAC
; -------------------------------------------------------------------------

;Only get gateway MAC if the opponent's not on the local subnet	
GATEWAYMAC
	lda #<UDP_DEST_IP
	ldx #>UDP_DEST_IP
	jsr IPMASK
	bcc MAC_SKIP
	
	PRINT CRLF,"RESOLVING GATEWAY MAC..."
  jsr get_macs	
	bcc MAC_OK

  ;Flag errors
  PRINT CRLF,CG_WHT,"ERROR RESOLVING THE GW MAC!",CRLF

nomac jmp nomac     ;Freeze 
 
MAC_OK
   PRINT "OK",CRLF 
MAC_SKIP
   rts

; -------------------------------------------------------------------------
; Get Server MAC (LAN Mode only)
; -------------------------------------------------------------------------

SERVERMAC
	PRINT CRLF,"RESOLVING SERVER MAC..."
  
	;get MAC for server
	lda #<SERVER_IP
	ldx #>SERVER_IP
	jsr GET_ARP
	bcs SMAC_FAILED
	;copy gateway mac
	ldx #$00
gm1_0
	lda ARP_MAC,x
	sta SERVER_MAC,x
	inx
	cpx #$06
	bne gm1_0
	
	jmp MAC_OK
  
SMAC_FAILED
  PRINT CRLF,CG_WHT,"ERROR RESOLVING THE SERVER MAC!",CRLF
  
nomac1 jmp nomac1   ;Freeze  

; -------------------------------------------------------------------------
; Packet Send Routine
; -------------------------------------------------------------------------

SENDUPDATE
  lda #$0e  ; Including zero-term. and checksum
  ldx #$00
  jsr UDP_SET_DATALEN
  
  ; Packet type
  lda #$00      ; Game update
  sta UDP_DATA
  
  ; X Position
  lda MYXPOS+1
  ldx MYXPOS+2     ; High byte, TODO
  sta UDP_DATA+1 
  stx UDP_DATA+2
  
  ; Y Position
  lda REALTRACKPOS+1
  ldx REALTRACKPOS+2
  sta UDP_DATA+3
  stx UDP_DATA+4  

  ;X Speed (include fractional)
  lda MYX_SPEED
  ldx MYX_SPEED+1
  sta UDP_DATA+5
  stx UDP_DATA+6
  
  ;Y Speed (include fractional)
  lda MY_SPEED
  ldx MY_SPEED+1
  sta UDP_DATA+7
  stx UDP_DATA+8
  
  ;Car color
  lda sprite1color
  sta UDP_DATA+9
  
  ;Sprite#
  lda sprite1pnt
  sta UDP_DATA+10

  ; Send!
  jsr UDP_SEND  
  rts 


; -------------------------------------------------------------------------
; Packet Receive + Handling Routines
; -------------------------------------------------------------------------

; Temporary holder of the checksum we received
RCV_CSUM
  dc.b $ff

; ==============================================================
; Master packet receiver.  This occurs inside the interrupt!
; A UDP packet has arrived, and the port matches the one we want.
; ==============================================================

MYUDP_PROCESS SUBROUTINE
  ; Check checksum, and don't ack if bad
;  jsr CHECKSUM
;  jmp BADCSUM

  inc COMMSLED
  
  ; Reset timeout
  lda #$00
  sta NETWORK_TIMEOUT

  ; Display sprites as commanded by the server    
  ;--------------------------------------
  ldx UDP_DATA_IN+1
  ldy UDP_DATA_IN+3  
  stx sprite2x
  stx IN_XPOSLOW+1
  sty sprite2y
  sty IN_YPOS+1
  
  lda UDP_DATA_IN+5
  sta IN_XSPEEDLOW+1
  lda UDP_DATA_IN+6
  sta IN_XSPEEDHIGH+1
  
  lda UDP_DATA_IN+7
  sta IN_YSPEEDLOW+1
  lda UDP_DATA_IN+8
  sta IN_YSPEEDHIGH+1
  
  lda UDP_DATA_IN+9
  sta sprite2color
  lda UDP_DATA_IN+10
  sta sprite2pnt

  ;--------------------------------------
  ldx UDP_DATA_IN+13
  ldy UDP_DATA_IN+15 
  stx sprite3x
  stx IN_XPOSLOW+2
  sty sprite3y
  sty IN_YPOS+2
  
  lda UDP_DATA_IN+17
  sta IN_XSPEEDLOW+2
  lda UDP_DATA_IN+18
  sta IN_XSPEEDHIGH+2
  
  lda UDP_DATA_IN+19
  sta IN_YSPEEDLOW+2
  lda UDP_DATA_IN+20
  sta IN_YSPEEDHIGH+2
  
  lda UDP_DATA_IN+21
  sta sprite3color
  lda UDP_DATA_IN+22
  sta sprite3pnt
  
  ;--------------------------------------
  ldx UDP_DATA_IN+25
  ldy UDP_DATA_IN+27 
  stx sprite4x
  stx IN_XPOSLOW+3
  sty sprite4y
  sty IN_YPOS+3
  
  lda UDP_DATA_IN+29
  sta IN_XSPEEDLOW+3
  lda UDP_DATA_IN+30
  sta IN_XSPEEDHIGH+3
  
  lda UDP_DATA_IN+31
  sta IN_YSPEEDLOW+3
  lda UDP_DATA_IN+32
  sta IN_YSPEEDHIGH+3
  
  lda UDP_DATA_IN+33
  sta sprite4color
  lda UDP_DATA_IN+34
  sta sprite4pnt
  
  ;--------------------------------------
  ldx UDP_DATA_IN+37
  ldy UDP_DATA_IN+39 
  stx sprite5x
  stx IN_XPOSLOW+4
  sty sprite5y
  sty IN_YPOS+4
  
  lda UDP_DATA_IN+41
  sta IN_XSPEEDLOW+4
  lda UDP_DATA_IN+42
  sta IN_XSPEEDHIGH+4
  
  lda UDP_DATA_IN+43
  sta IN_YSPEEDLOW+4
  lda UDP_DATA_IN+44
  sta IN_YSPEEDHIGH+4
  
  lda UDP_DATA_IN+45
  sta sprite5color
  lda UDP_DATA_IN+46
  sta sprite5pnt
  
  ;--------------------------------------
  ldx UDP_DATA_IN+49
  ldy UDP_DATA_IN+51 
  stx sprite6x
  stx IN_XPOSLOW+5
  sty sprite6y
  sty IN_YPOS+5
  
  lda UDP_DATA_IN+53
  sta IN_XSPEEDLOW+5
  lda UDP_DATA_IN+54
  sta IN_XSPEEDHIGH+5
  
  lda UDP_DATA_IN+55
  sta IN_YSPEEDLOW+5
  lda UDP_DATA_IN+56
  sta IN_YSPEEDHIGH+5
  
  lda UDP_DATA_IN+57
  sta sprite6color
  lda UDP_DATA_IN+58
  sta sprite6pnt
  
  ;--------------------------------------
  ldx UDP_DATA_IN+61
  ldy UDP_DATA_IN+63 
  stx sprite7x
  stx IN_XPOSLOW+6
  sty sprite7y
  sty IN_YPOS+6
  
  lda UDP_DATA_IN+65
  sta IN_XSPEEDLOW+6
  lda UDP_DATA_IN+66
  sta IN_XSPEEDHIGH+6
  
  lda UDP_DATA_IN+67
  sta IN_YSPEEDLOW+6
  lda UDP_DATA_IN+68
  sta IN_YSPEEDHIGH+6
  
  lda UDP_DATA_IN+69
  sta sprite7color
  lda UDP_DATA_IN+70
  sta sprite7pnt
  
  ;--------------------------------------
  ldx UDP_DATA_IN+73
  ldy UDP_DATA_IN+75 
  stx sprite8x
  stx IN_XPOSLOW+7
  sty sprite8y
  sty IN_YPOS+7
  
  lda UDP_DATA_IN+77
  sta IN_XSPEEDLOW+7
  lda UDP_DATA_IN+78
  sta IN_XSPEEDHIGH+7
  
  lda UDP_DATA_IN+79
  sta IN_YSPEEDLOW+7
  lda UDP_DATA_IN+80
  sta IN_YSPEEDHIGH+7
  
  lda UDP_DATA_IN+81
  sta sprite8color
  lda UDP_DATA_IN+82
  sta sprite8pnt
  
  ;now, calculate MSB for sprites
  lda #0
  ldx UDP_DATA_IN+2
  stx IN_XPOSHIGH+1
  beq .ahead1
  ora #2
.ahead1
  ldx UDP_DATA_IN+14
  stx IN_XPOSHIGH+2
  beq .ahead2
  ora #4
.ahead2
  ldx UDP_DATA_IN+26
  stx IN_XPOSHIGH+3
  beq .ahead3
  ora #8
.ahead3
  ldx UDP_DATA_IN+38
  stx IN_XPOSHIGH+4
  beq .ahead4
  ora #16
.ahead4
  ldx UDP_DATA_IN+50
  stx IN_XPOSHIGH+5
  beq .ahead5
  ora #32
.ahead5
  ldx UDP_DATA_IN+62
  stx IN_XPOSHIGH+6
  beq .ahead6
  ora #64
.ahead6
  ldx UDP_DATA_IN+74
  stx IN_XPOSHIGH+7
  beq .ahead7
  ora #128
.ahead7
  ;sta .self+1
  ;lda $d010
  ;and #1
;.self
  ;ora #$ff ;self-mod!
  ;sta $d010
  sta IN_XPOS_D010
  
  ;--------------------------------------
MYUDP_PROCESS_x
  lda #$01
  sta PACKET_RECEIVED
  rts


; -------------------------------------------------------------------------
; Do Checksum here
CHECKSUM
 ; lda INPACKET+????   ; A now holds the checksum we received
 ; sta RCV_CSUM  
  
  ;Point x:a to start of received packet
  ;and calculate our own checksum
  ldx #<(INPACKET+$2A)
  lda #>(INPACKET+$2A)
  dey ; So we aren't including the checksum byte itself
 ; jsr DATACHECKSUM
  
  lda CSUM
  ;sta CSUM_SAVE
  
  lda RCV_CSUM
  cmp CSUM
  ; Zero bit now contains whether or not checksum matches, use bne/beq
  rts
