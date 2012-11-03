;Source by Six of Style (Oliver VieBrooks)              _,.-------.,_

net_init
	jsr CARD_DETECT
	bcs detect_ERROR
	cmp #$01
	bne f_RR
	PRINT CG_GRN,"ETH64 DETECTED",CRLF
	jmp init
f_RR	PRINT "RR-NET COMPATIBLE CARD DETECTED",CRLF
init	jsr CARD_INIT
	bcs init_ERROR
	PRINT "CARD INITIALIZED",CRLF
	clc
	rts
	
detect_ERROR
	PRINT CG_RED, "NO CARD WAS DETECTED!", CRLF
	sec
	rts
init_ERROR
	PRINT CG_RED, "ERROR DURING INITIALIZATION!", CRLF
	sec
	rts

get_macs ;returns carry clear if success, set if error
	;get MAC for gateway
	lda #<CARD_GATE
	ldx #>CARD_GATE
	jsr GET_ARP
	bcs getmacs_ERR
	;copy gateway mac
	ldx #$00
gm_0
	lda ARP_MAC,x
	sta CARD_GATE_MAC,x
	inx
	cpx #$06
	bne gm_0
	clc
	rts
getmacs_ERR
	sec
	rts
	
initTOD
	lda $dc0f
	and #$7f
	sta $dc0f
	lda #$00
	sta $dc08
	rts

irq_init_old
	sei
	lda #$01
	sta $d019
	sta $d01a
	lda #$1b
	sta $d011
	lda #$7f
	sta $dc0d
	lda #$31
	sta $d012
	lda #<IRQ
	sta $0314
	lda #>IRQ
	sta $0315
	cli
	rts
	
;===========================
; Several changes by (LB)
;===========================

NETIRQ
  ;This is now called from elsewhere, and IRQ is acked and so on there 
		
	jsr CARD_POLL
	beq IRQx
	
  jsr IRQ_PACKET
IRQx
	rts

;==================
	
IRQ_PACKET
	jsr CARD_READ
	jsr MAC_PROCESS	
	rts
	

killirq
	sei
	inc $d019 ;ack any pending vic irq
	jsr $ff81
	lda #$31
	sta $0314
	lda #$ea
	sta $0315
	cli
	PRINT "NETIRQ KILLED", CRLF
	rts
;=============================================================================
;MAIN MENU - Removed by (LB)
;=============================================================================

;=============================================================================
;VARIABLES AND DATA

pingcount	dc.b $00	
TIMEOUT	dc.b $00
TICKER  dc.b $00
;=============================================================================
;INCLUDES
	include "checksum.asm"
	include "utils.asm"
	
	include "ETH64.ASM"
	include "RRNET.ASM"
	include "CARD.ASM"
	include "MAC.ASM"
	include "ARP.ASM"
	include "IP.ASM"
	include "ICMP.ASM"
	include "UDP.ASM"
	include "TCP.ASM"

	include "DHCP.ASM"
	include "DNS.ASM"
	include "PING.ASM"
	
	include "PACKET.ASM" ;(LB) - moved

;BUFFER=======================================================================

BUFSTART
	org $cfff
BUFFEND
