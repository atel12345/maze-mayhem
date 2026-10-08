;FamiTone5.1 generated song data
;edited by Doug Fraker, 2025, to add volume column, all notes, 
;duty envelopes, and effects 1xx,2xx,3xx,4xx,Qxx,Rxx


nes_23_chill_music_data:
	.byte 1
	.word @instruments
	.word @samples-3
	.word @song0ch0,@song0ch1,@song0ch2,@song0ch3,@song0ch4,307,256 ; chill (23)

@instruments:
	.word @env1,@env0,@env0,@env7
	.word @env2,@env6,@env0,@env8
	.word @env3,@env0,@env0,@env0
	.word @env4,@env0,@env0,@env0
	.word @env5,@env0,@env3,@env0

@samples:
@env0:
	.byte $c0,$00,$00
@env1:
	.byte $c2,$c3,$c5,$c7,$cb,$cd,$cb,$c7,$c5,$c3,$c2,$03,$c2,$00,$09
@env2:
	.byte $c8,$cc,$cd,$02,$cc,$cb,$ca,$c9,$00,$07
@env3:
	.byte $cf,$00,$00
@env4:
	.byte $cf,$cf,$ce,$cd,$ca,$c6,$c3,$c0,$00,$07
@env5:
	.byte $cc,$03,$cb,$cb,$ca,$c9,$c7,$c5,$c2,$c0,$0b,$c0,$00,$0b
@env6:
	.byte $b4,$c0,$00,$01
@env7:
	.byte $c0,$c3,$00,$01
@env8:
	.byte $c1,$c0,$c2,$00,$02


; chill (23)
@song0ch0:
	.byte $fb,$04
@song0ch0loop:
@ref0:
	.byte $80,$2a,$a5,$27,$ad,$2c,$81
@ref1:
	.byte $ab,$25,$ad
@ref2:
	.byte $2a,$a5,$27,$ad,$2c,$81
@ref3:
	.byte $ab,$25,$ad
	.byte $ff,$06
	.word @ref2
@ref5:
	.byte $ab,$25,$ad
	.byte $ff,$06
	.word @ref2
@ref7:
	.byte $ab,$25,$ad
	.byte $ff,$06
	.word @ref2
@ref9:
	.byte $ab,$25,$ad
	.byte $ff,$06
	.word @ref2
@ref11:
	.byte $ab,$25,$ad
	.byte $fd
	.word @song0ch0loop

; chill (23)
@song0ch1:
@song0ch1loop:
@ref12:
	.byte $00,$d9
@ref13:
	.byte $db
@ref14:
	.byte $00,$d9
@ref15:
	.byte $db
@ref16:
	.byte $74,$83,$73,$83,$72,$83,$71,$83,$7a,$82,$25,$79,$81,$78,$81,$77
	.byte $81,$76,$83,$75,$83,$7a,$20,$79,$81,$78,$81,$77,$81,$76,$83,$75
	.byte $83,$74,$81,$73,$81,$72,$81,$71,$81,$7a,$22,$79,$81,$78,$81,$77
	.byte $81,$76,$83,$75,$83,$7a,$1e,$79,$81,$78,$81,$77,$81,$76,$83,$75
	.byte $83,$74,$81,$73,$81
@ref17:
	.byte $72,$81,$71,$81,$7a,$27,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83
	.byte $7a,$22,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83,$74,$81,$73,$81
	.byte $72,$81,$71,$81,$7a,$20,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83
	.byte $7a,$22,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83,$74,$81,$73,$81
	.byte $72,$81,$71,$81,$7a,$20,$79,$81,$78,$81,$77,$81
@ref18:
	.byte $76,$83,$75,$83,$7a,$22,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83
	.byte $74,$81,$73,$81,$72,$81,$71,$81,$7a,$25,$79,$81,$78,$81,$77,$81
	.byte $76,$83,$75,$83,$7a,$22,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83
	.byte $74,$81,$73,$81,$72,$81,$71,$81,$7a,$25,$79,$81,$78,$81,$77,$81
	.byte $76,$83,$75,$83,$7a,$20,$79,$81
@ref19:
	.byte $78,$81,$77,$81,$76,$83,$75,$83,$74,$81,$73,$81,$72,$81,$71,$81
	.byte $7a,$27,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83,$7a,$20,$79,$81
	.byte $78,$81,$77,$81,$76,$83,$75,$83,$74,$81,$73,$81,$72,$81,$71,$81
	.byte $7a,$1e,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83,$7a,$22,$79,$81
	.byte $78,$81,$77,$81,$76,$83,$75,$83
@ref20:
	.byte $74,$83,$73,$83,$72,$83,$71,$83,$7a,$25,$79,$81,$78,$81,$77,$81
	.byte $76,$83,$75,$83,$7a,$20,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83
	.byte $74,$81,$73,$81,$72,$81,$71,$81,$7a,$22,$79,$81,$78,$81,$77,$81
	.byte $76,$83,$75,$83,$7a,$1e,$79,$81,$78,$81,$77,$81,$76,$83,$75,$83
	.byte $74,$81,$73,$81
	.byte $ff,$26
	.word @ref17
	.byte $ff,$24
	.word @ref18
	.byte $ff,$24
	.word @ref19
	.byte $fd
	.word @song0ch1loop

; chill (23)
@song0ch2:
@song0ch2loop:
@ref24:
	.byte $84,$20,$85,$23,$85,$27,$85,$2a,$85,$2e,$85,$23,$85,$20,$85,$23
	.byte $85,$27,$85,$2a,$85,$2e,$85,$23,$81
@ref25:
	.byte $83,$20,$85,$23,$85,$27,$85,$2a,$85,$2e,$85,$23,$85,$20,$85,$23
	.byte $85,$27,$85,$2a,$85,$2e,$85
@ref26:
	.byte $20,$85,$23,$85,$27,$85,$2a,$85,$2e,$85,$23,$85,$20,$85,$23,$85
	.byte $27,$85,$2a,$85,$2e,$85,$23,$81
	.byte $ff,$17
	.word @ref25
	.byte $ff,$18
	.word @ref26
	.byte $ff,$17
	.word @ref25
	.byte $ff,$18
	.word @ref26
	.byte $ff,$17
	.word @ref25
	.byte $ff,$18
	.word @ref26
	.byte $ff,$17
	.word @ref25
	.byte $ff,$18
	.word @ref26
	.byte $ff,$17
	.word @ref25
	.byte $fd
	.word @song0ch2loop

; chill (23)
@song0ch3:
@song0ch3loop:
@ref36:
	.byte $88,$05,$8d,$86,$01,$8d,$01,$85,$88,$05,$85,$86,$01,$8d,$01,$8d
	.byte $01,$85,$88,$05,$81
@ref37:
	.byte $83,$86,$01,$8d,$01,$8d,$01,$85,$88,$05,$85,$86,$01,$8d,$01,$8d
	.byte $01,$85
@ref38:
	.byte $88,$05,$85,$86,$01,$8d,$01,$8d,$88,$05,$8d,$86,$01,$8d,$01,$8d
	.byte $88,$05,$81
@ref39:
	.byte $8b,$86,$01,$8d,$01,$8d,$88,$05,$8d,$86,$01,$8d,$01,$8d
	.byte $ff,$10
	.word @ref36
	.byte $ff,$0f
	.word @ref37
	.byte $ff,$0e
	.word @ref38
	.byte $ff,$0b
	.word @ref39
	.byte $ff,$10
	.word @ref36
	.byte $ff,$0f
	.word @ref37
	.byte $ff,$0e
	.word @ref38
	.byte $ff,$0b
	.word @ref39
	.byte $fd
	.word @song0ch3loop

; chill (23)
@song0ch4:
@song0ch4loop:
@ref48:
	.byte $db
@ref49:
	.byte $db
@ref50:
	.byte $db
@ref51:
	.byte $db
@ref52:
	.byte $db
@ref53:
	.byte $db
@ref54:
	.byte $db
@ref55:
	.byte $db
@ref56:
	.byte $db
@ref57:
	.byte $db
@ref58:
	.byte $db
@ref59:
	.byte $db
	.byte $fd
	.word @song0ch4loop
