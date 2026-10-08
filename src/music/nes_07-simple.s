;FamiTone5.1 generated song data
;edited by Doug Fraker, 2025, to add volume column, all notes, 
;duty envelopes, and effects 1xx,2xx,3xx,4xx,Qxx,Rxx


nes_07_simple_music_data:
	.byte 1
	.word @instruments
	.word @samples-3
	.word @song0ch0,@song0ch1,@song0ch2,@song0ch3,@song0ch4,307,256 ; simple track

@instruments:
	.word @env1,@env5,@env0,@env6
	.word @env2,@env0,@env0,@env0
	.word @env3,@env0,@env0,@env0
	.word @env4,@env0,@env0,@env0

@samples:
@env0:
	.byte $c0,$00,$00
@env1:
	.byte $c8,$cc,$cd,$02,$cc,$cb,$ca,$c9,$00,$07
@env2:
	.byte $cf,$00,$00
@env3:
	.byte $cf,$cf,$ce,$cd,$ca,$c6,$c3,$c0,$00,$07
@env4:
	.byte $ce,$ce,$cd,$ca,$c6,$c0,$c0,$c0,$00,$07
@env5:
	.byte $b4,$c0,$00,$01
@env6:
	.byte $c1,$c0,$c2,$00,$02


; simple track
@song0ch0:
	.byte $fb,$03
@song0ch0loop:
@ref0:
	.byte $f9,$ad
@ref1:
	.byte $f9,$ad
@ref2:
	.byte $f9,$ad
@ref3:
	.byte $f9,$ad
@ref4:
	.byte $f9,$ad
@ref5:
	.byte $f9,$ad
	.byte $fd
	.word @song0ch0loop

; simple track
@song0ch1:
@song0ch1loop:
@ref6:
	.byte $5f,$00,$f9,$ab
@ref7:
	.byte $5f,$00,$f9,$ab
@ref8:
	.byte $85,$00,$83,$7a,$5f,$80,$2d,$89,$7a,$2b,$b3,$6c,$03,$85,$5f,$28
	.byte $bf,$6c,$03,$85,$6c,$04,$85,$6c,$05,$85
@ref9:
	.byte $5f,$00,$89,$2d,$89,$2f,$b3,$6c,$03,$85,$5f,$2b,$a1,$6c,$03,$85
	.byte $5f,$26,$8f,$6c,$03,$85,$5f,$27,$89,$6b,$03,$85
@ref10:
	.byte $85,$00,$83,$7a,$5f,$2d,$89,$7a,$2b,$b3,$6c,$03,$85,$5f,$28,$bf
	.byte $6c,$03,$85,$6c,$04,$85,$6c,$05,$85
	.byte $ff,$10
	.word @ref9
	.byte $fd
	.word @song0ch1loop

; simple track
@song0ch2:
@song0ch2loop:
@ref12:
	.byte $82,$28,$89,$1c,$89,$1f,$8f,$28,$89,$1c,$89,$1f,$8f,$28,$89,$1c
	.byte $89,$1f,$8f,$28,$89,$1c,$89,$1f,$89,$26,$83
@ref13:
	.byte $28,$89,$1c,$89,$1f,$8f,$28,$89,$1c,$89,$1f,$8f,$28,$89,$1c,$89
	.byte $1f,$8f,$28,$89,$1c,$89,$1f,$89,$26,$83
	.byte $ff,$1a
	.word @ref13
	.byte $ff,$1a
	.word @ref13
	.byte $ff,$1a
	.word @ref13
	.byte $ff,$1a
	.word @ref13
	.byte $fd
	.word @song0ch2loop

; simple track
@song0ch3:
@song0ch3loop:
@ref18:
	.byte $84,$01,$89,$01,$89,$86,$05,$8f,$84,$01,$89,$01,$83,$01,$89,$86
	.byte $05,$89,$84,$01,$89,$01,$89,$01,$89,$86,$05,$83,$84,$01,$89,$01
	.byte $89,$01,$89,$01,$83
@ref19:
	.byte $01,$89,$01,$89,$86,$05,$8f,$84,$01,$89,$01,$83,$01,$89,$86,$05
	.byte $89,$84,$01,$89,$01,$89,$01,$89,$86,$05,$83,$84,$01,$89,$01,$89
	.byte $01,$89,$01,$83
	.byte $ff,$1e
	.word @ref19
	.byte $ff,$1e
	.word @ref19
	.byte $ff,$1e
	.word @ref19
	.byte $ff,$1e
	.word @ref19
	.byte $fd
	.word @song0ch3loop

; simple track
@song0ch4:
@song0ch4loop:
@ref24:
	.byte $f9,$ad
@ref25:
	.byte $f9,$ad
@ref26:
	.byte $f9,$ad
@ref27:
	.byte $f9,$ad
@ref28:
	.byte $f9,$ad
@ref29:
	.byte $f9,$ad
	.byte $fd
	.word @song0ch4loop
