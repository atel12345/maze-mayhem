; ============================================================
;  MAZE MAYHEM  -  NES (mapper 0 / NROM-256), ca65 syntax
;
;  Title screen, random maze generator, shooting enemies,
;  endless levels (kill 5, then 10, then 15, ...).
; ============================================================

; ============================================================
; iNES HEADER
; ============================================================
.segment "HEADER"
    .byte "NES", $1A
    .byte 2              ; 2 x 16 KB PRG-ROM
    .byte 1              ; 1 x 8 KB CHR-ROM
    .byte $00
    .byte $00
    .byte 0,0,0,0,0,0,0,0

; ============================================================
; CONSTANTS
; ============================================================
; --- tile numbers (must match the CHR data at the bottom) ---
; Font tiles use ASCII codes, so .byte "TEXT" draws text directly.
FLOOR        = $00
WALL         = $01
TILE_DOWN    = $02
TILE_UP      = $03
TILE_LEFT    = $04
TILE_RIGHT   = $05
TILE_FIRE    = $06
TILE_ENEMY   = $07
TILE_BULLET  = $08

; --- controller bits ---
BTN_A        = %10000000
BTN_B        = %01000000
BTN_START    = %00010000
BTN_UP       = %00001000
BTN_DOWN     = %00000100
BTN_LEFT     = %00000010
BTN_RIGHT    = %00000001

; --- hitbox: 8x8 sprite, 4x4 box inset 2 px (pixels 2..5) ---
; The maze has one-tile-wide openings. Keep the collision box away from
; diagonal wall corners so those openings remain traversable.
HB_LO        = 2
HB_HI        = 5
HIT_DIST     = 4         ; two boxes overlap when |dx| < 4 and |dy| < 4
FIRE_SPEED   = 4         ; player fireball px/frame (moved 1 px at a time)

; --- maze ---
MAZE_W       = 10        ; cells across
MAZE_H       = 9         ; cells down
EXTRA_COUNT  = 14        ; extra walls knocked out to make loops
MAX_ENEMIES  = 5

; --- fixed RAM buffers (absolute addresses, no linker config needed) ---
OAM          = $0200
MazeRAM      = $0300     ; 960 bytes: 32 cols x 30 rows
VisitedRAM   = $06C0     ; 144 bytes: index = (cy<<4)|cx
CellStack    = $0750     ; 90 bytes

; ============================================================
; ZERO PAGE VARIABLES
; ============================================================
.segment "ZEROPAGE"
frameCnt:    .res 1
lastFrame:   .res 1
rngLo:       .res 1
rngHi:       .res 1
rngCnt:      .res 1
rmN:         .res 1
rmMask:      .res 1
buttons:     .res 1
lastButtons: .res 1

hudDirty:    .res 1
paused:      .res 1
hudK0:       .res 1
hudK1:       .res 1
hudK2:       .res 1
hudHP:       .res 1
decH:        .res 1
decT:        .res 1
decO:        .res 1

tmpA:        .res 1
tmpB:        .res 1
tmpC:        .res 1
tmpD:        .res 1
absB:        .res 1
cpT:         .res 1
cpU:         .res 1
spawnX:      .res 1
spawnY:      .res 1

newX:        .res 1
newY:        .res 1
tileCol:     .res 1
tileRow:     .res 1
tileAddr:    .res 2
boxColL:     .res 1
boxColR:     .res 1
boxRowT:     .res 1
boxRowB:     .res 1
strPtr:      .res 2
hx1:         .res 1
hy1:         .res 1
hx2:         .res 1
hy2:         .res 1

; player
spriteX:     .res 1
spriteY:     .res 1
spriteTile:  .res 1
lastDir:     .res 1      ; 0=up 1=down 2=left 3=right
hp:          .res 1
invuln:      .res 1
fireX:       .res 1
fireY:       .res 1
fireActive:  .res 1
fireDir:     .res 1

; level state
level:       .res 1
goal:        .res 1
kills:       .res 1
active:      .res 1
spawnTimer:  .res 1
enemyMax:    .res 1
enemySpeed:  .res 1
shootBase:   .res 1
shootAccuracy: .res 1
bulletSpeed: .res 1

; audio
musicMode:   .res 1      ; 0=off, 1=title, 2=game-over, 3=gameplay
musicStep:   .res 1
musicTimer:  .res 1
sfxTimer:    .res 1

; maze generator
genX:        .res 1
genY:        .res 1
genDir:      .res 1
stackPtr:    .res 1
nbCount:     .res 1
nbX:         .res 1
nbY:         .res 1
cellTX:      .res 1
cellTY:      .res 1
extraCnt:    .res 1
nbList:      .res 4

; enemies and their bullets (one bullet slot per enemy)
eX:          .res MAX_ENEMIES
eY:          .res MAX_ENEMIES
eDir:        .res MAX_ENEMIES
eAct:        .res MAX_ENEMIES
eTim:        .res MAX_ENEMIES
eAcc:        .res MAX_ENEMIES
eTurn:       .res MAX_ENEMIES
bX:          .res MAX_ENEMIES
bY:          .res MAX_ENEMIES
bAct:        .res MAX_ENEMIES
bDir:        .res MAX_ENEMIES

; ============================================================
; MACROS
; ============================================================
; set the PPU address (also resets the $2005/$2006 write latch)
.macro PPUADDR addr
    BIT $2002
    LDA #>(addr)
    STA $2006
    LDA #<(addr)
    STA $2006
.endmacro

; text-list entry header: PPU address of (row,col) in nametable 0
.macro TEXTAT row, col
    .byte >($2000+(row)*32+(col)), <($2000+(row)*32+(col))
.endmacro

; big (2x2 tile) title letters
.macro BIGTOP ch
    .byte $80+((ch)-'A')*4, $80+((ch)-'A')*4+1
.endmacro
.macro BIGBOT ch
    .byte $80+((ch)-'A')*4+2, $80+((ch)-'A')*4+3
.endmacro

.macro PRINTLIST addr
    LDA #<(addr)
    STA strPtr
    LDA #>(addr)
    STA strPtr+1
    JSR PrintList
.endmacro

; ============================================================
; CODE
; ============================================================
.segment "CODE"

; ------------------------------------------------------------
; NMI  (only enabled while a level is being played)
; OAM DMA, then HUD digits if the main code asked for it.
; ------------------------------------------------------------
NMI:
    PHA
    TXA
    PHA
    TYA
    PHA

    BIT $2002
    LDA #$00
    STA $2003
    LDA #$02
    STA $4014

    LDA hudDirty
    BEQ @nohud
    LDA #0
    STA hudDirty
    LDA #$20             ; kills digits at row 1, col 14 = $202E
    STA $2006
    LDA #$2E
    STA $2006
    LDA hudK0
    STA $2007
    LDA hudK1
    STA $2007
    LDA hudK2
    STA $2007
    LDA #$20             ; hp digit at row 1, col 26 = $203A
    STA $2006
    LDA #$3A
    STA $2006
    LDA hudHP
    STA $2007
@nohud:
    LDA #0
    STA $2005
    STA $2005
    LDA #%10000000
    STA $2000
    INC frameCnt

    PLA
    TAY
    PLA
    TAX
    PLA
    RTI

IRQ:
    RTI

; ------------------------------------------------------------
; RESET
; ------------------------------------------------------------
RESET:
    SEI
    CLD
    LDX #$FF
    TXS

    LDX #0
    STX $2000
    STX $2001
    STX $4010
    LDA #$40
    STA $4017

    BIT $2002
@vb1:
    BIT $2002
    BPL @vb1

    LDA #0
    TAX
@clr:
    STA $0000, X
    STA $0100, X
    STA $0200, X
    STA $0300, X
    STA $0400, X
    STA $0500, X
    STA $0600, X
    STA $0700, X
    INX
    BNE @clr

    LDA #$F0             ; all sprites off-screen
@oam:
    STA OAM, X
    INX
    BNE @oam

@vb2:
    BIT $2002
    BPL @vb2

    LDA #$01             ; RNG state must never be 0
    STA rngLo
    LDA #$A5
    STA rngHi

    JSR AudioInit
    JSR LoadPalettes

; ------------------------------------------------------------
; Main game flow
; ------------------------------------------------------------
GameStart:
    LDX #$FF
    TXS                  ; fresh stack (we may arrive from game over)
    JSR TitleScreen
    JSR NewGame
LevelLoop:
    JSR BuildLevel
    JSR PlayLevel        ; A=1 level cleared, A=0 player died
    BEQ Died
    JSR NextLevel
    JSR LevelClearScreen
    JMP LevelLoop
Died:
    JSR GameOverScreen
    JSR TitleScreen
    JSR NewGame
    JMP LevelLoop

NewGame:
    LDA #1
    STA level
    LDA #5
    STA goal
    LDA #3
    STA hp
    RTS

; level +1, goal +5 (cap 250), +1 hp (cap 5)
NextLevel:
    LDA level
    CMP #255
    BEQ @nolv
    INC level
@nolv:
    LDA goal
    CMP #250
    BCS @nogoal
    CLC
    ADC #5
    STA goal
@nogoal:
    LDA hp
    CMP #5
    BCS @nohp
    INC hp
@nohp:
    RTS

; ------------------------------------------------------------
; Palettes
; ------------------------------------------------------------
LoadPalettes:
    PPUADDR $3F00
    LDX #0
@l:
    LDA PaletteData, X
    STA $2007
    INX
    CPX #32
    BNE @l
    RTS

; A = colour for BG palette 0, colour 2 (the wall colour)
SetWallColor:
    STA tmpA
    PPUADDR $3F02
    LDA tmpA
    STA $2007
    RTS

; ------------------------------------------------------------
; Low-level PPU helpers
; ------------------------------------------------------------
WaitVBlankPoll:
    BIT $2002
@w:
    BIT $2002
    BPL @w
    RTS

ScreenOff:
    LDA #0
    STA $2000            ; NMI off first (avoids an NMI/poll race)
    JSR WaitVBlankPoll
    LDA #0
    STA $2001
    RTS

; text/title screens: NMI stays off
ScreenOnText:
    JSR WaitVBlankPoll
    LDA #0
    STA $2005
    STA $2005
    STA $2000
    LDA #%00011110
    STA $2001
    RTS

; gameplay: NMI on
ScreenOnPlay:
    JSR WaitVBlankPoll
    LDA #0
    STA $2005
    STA $2005
    LDA #%10000000
    STA $2000
    LDA #%00011110
    STA $2001
    LDA frameCnt
    STA lastFrame
    RTS

HideAllSprites:
    LDA #$F0
    LDX #0
@h:
    STA OAM, X
    INX
    BNE @h
DoDMA:
    LDA #0
    STA $2003
    LDA #2
    STA $4014
    RTS

ClearNametable:
    PPUADDR $2000
    LDA #0
    LDX #0
    LDY #4
@l:
    STA $2007
    INX
    BNE @l
    DEY
    BNE @l
    RTS

; A = tile row (0..29): fill that row with brick
DrawBrickRow:
    STA tmpA
    LSR A
    LSR A
    LSR A
    CLC
    ADC #$20
    STA tmpB             ; PPU high byte
    LDA tmpA
    ASL A
    ASL A
    ASL A
    ASL A
    ASL A
    STA tmpC             ; PPU low byte
    BIT $2002
    LDA tmpB
    STA $2006
    LDA tmpC
    STA $2006
    LDA #WALL
    LDX #32
@l:
    STA $2007
    DEX
    BNE @l
    RTS

; strPtr -> list of entries: hiAddr, loAddr, tiles..., $FF  ... ends with hiAddr = 0
PrintList:
    LDY #0
@next:
    LDA (strPtr), Y
    BEQ @done
    STA $2006
    INY
    LDA (strPtr), Y
    STA $2006
    INY
@chars:
    LDA (strPtr), Y
    CMP #$FF
    BEQ @endstr
    STA $2007
    INY
    JMP @chars
@endstr:
    INY
    JMP @next
@done:
    RTS

; A (0..255) -> decH, decT, decO (digits 0..9)
BinToDec3:
    LDX #0
@h:
    CMP #100
    BCC @hd
    SBC #100
    INX
    BNE @h
@hd:
    STX decH
    LDX #0
@t:
    CMP #10
    BCC @td
    SBC #10
    INX
    BNE @t
@td:
    STX decT
    STA decO
    RTS

; write A as 3 digits at the current PPU address
PrintDec3:
    JSR BinToDec3
    LDA decH
    CLC
    ADC #'0'
    STA $2007
    LDA decT
    CLC
    ADC #'0'
    STA $2007
    LDA decO
    CLC
    ADC #'0'
    STA $2007
    RTS

; ------------------------------------------------------------
; Random numbers (16-bit Galois LFSR, 8 steps per call)
; Rand: A = random byte.  Preserves X and Y.
; ------------------------------------------------------------
Rand:
    LDA #8
    STA rngCnt
@loop:
    LSR rngHi
    ROR rngLo
    BCC @skip
    LDA rngHi
    EOR #$B4
    STA rngHi
@skip:
    DEC rngCnt
    BNE @loop
    LDA rngLo
    RTS

; RandMod: A = n (1..255) -> A = random 0..n-1.  Preserves X and Y.
RandMod:
    STA rmN
    CMP #1
    BNE @go
    LDA #0
    RTS
@go:
    SEC
    SBC #1
    STA rmMask           ; build smallest 2^k-1 that is >= n-1
    LSR A
    ORA rmMask
    STA rmMask
    LSR A
    LSR A
    ORA rmMask
    STA rmMask
    LSR A
    LSR A
    LSR A
    LSR A
    ORA rmMask
    STA rmMask
@try:
    JSR Rand
    AND rmMask
    CMP rmN
    BCS @try
    RTS

; A = |A - absB|
AbsDiff:
    SEC
    SBC absB
    BCS @d
    EOR #$FF
    ADC #1               ; carry is clear here
@d:
    RTS

; ------------------------------------------------------------
; Audio
; ------------------------------------------------------------
AudioInit:
    LDA #$00
    STA $4015            ; silence all channels while resetting APU
    STA $4000
    STA $4004
    STA $4008
    STA $400C
    LDA #%11000000
    STA $4017            ; 5-step frame counter, IRQ disabled
    LDA #%00001011       ; pulse 1, pulse 2, and noise enabled
    STA $4015
    LDA #0
    STA musicMode
    STA musicStep
    STA musicTimer
    STA sfxTimer
    RTS

StartTitleMusic:
    LDA #1
    STA musicMode
    LDX #<nes_23_chill_music_data
    LDY #>nes_23_chill_music_data
    LDA #1
    JSR FamiToneInit
    LDA #0
    JSR FamiToneMusicPlay
    LDA #%00001111
    STA $4015
    RTS

StartGameplayMusic:
    LDA #3
    STA musicMode
    LDX #<nes_07_simple_music_data
    LDY #>nes_07_simple_music_data
    LDA #1
    JSR FamiToneInit
    LDA #0
    JSR FamiToneMusicPlay
    LDA #%00001111
    STA $4015
    RTS

StartGameOverMusic:
    LDA #2
    STA musicMode
    LDA #%00000001
    STA $4015
    LDA #0
    STA musicStep
    STA musicTimer
    RTS

StopMusic:
    LDA #0
    STA musicMode
    STA $4015
    RTS

; Advance one note. Call once per video frame.
AudioTick:
    LDA sfxTimer
    BEQ @music
    DEC sfxTimer
    BNE @music
    LDA #$00
    STA $4004            ; stop pulse 2 sound effect
    STA $400C            ; stop noise sound effect
@music:
    LDA musicMode
    BEQ @done
    CMP #2
    BEQ @oldMusic
    JSR FamiToneUpdate
    RTS
@oldMusic:
    LDA musicTimer
    BEQ @next
    DEC musicTimer
    RTS
@next:
    LDX musicStep
    LDA GameOverMusicPeriods, X
    STA $4002
    LDA GameOverMusicPeriodsHi, X
    ORA #$08
    STA $4003
    LDA GameOverMusicDurations, X
    STA musicTimer
    INX
    CPX #8
    BCC @storeChill
    LDX #0
@storeChill:
    STX musicStep
    LDA #%10001111      ; quieter, softer game-over pulse
    STA $4000
@done:
    RTS

PlayShootSfx:
    LDA #%10011110      ; pulse 2, short bright blip
    STA $4004
    LDA #<180
    STA $4006
    LDA #$00            ; shortest hardware length; software timeout also stops it
    STA $4007
    LDA #4
    STA sfxTimer
    RTS

PlayExplosionSfx:
    LDA #%00111111      ; noise, short loud burst
    STA $400C
    LDA #%00000110
    STA $400E
    LDA #%00000000      ; shortest hardware length
    STA $400F
    LDA #5
    STA sfxTimer
    RTS

PlayHurtSfx:
    LDA #%00111010      ; lower-volume noise hit
    STA $400C
    LDA #%00001111
    STA $400E
    LDA #%00000000      ; shortest hardware length
    STA $400F
    LDA #4
    STA sfxTimer
    RTS

StopSfx:
    LDA #0
    STA sfxTimer
    STA $4004
    STA $400C
    RTS

; ------------------------------------------------------------
; Title screen
; ------------------------------------------------------------
TitleScreen:
    JSR ScreenOff
    JSR ClearNametable
    LDA #3
    JSR DrawBrickRow
    LDA #26
    JSR DrawBrickRow
    PRINTLIST TitleList
    LDA #$11
    JSR SetWallColor

    JSR HideAllSprites
    LDX #0
@spr:
    LDA TitleSprites, X
    STA OAM, X
    INX
    CPX #16
    BNE @spr
    JSR DoDMA

    JSR ScreenOnText
    JSR StartTitleMusic
    LDA #0
    STA buttons
@release:
    JSR WaitVBlankPoll
    JSR ReadController
    LDA buttons
    AND #BTN_START
    BNE @release
@loop:
    JSR WaitVBlankPoll
    INC frameCnt

    LDA frameCnt         ; blink PRESS START every 32 frames
    AND #$1F
    BNE @noblink
    PPUADDR $2000+22*32+10
    LDA frameCnt
    AND #$20
    BEQ @blank
    LDX #0
@txt:
    LDA PressStartStr, X
    STA $2007
    INX
    CPX #11
    BNE @txt
    JMP @fix
@blank:
    LDA #0
    LDX #11
@bk:
    STA $2007
    DEX
    BNE @bk
@fix:
    LDA #0
    STA $2005
    STA $2005
@noblink:
    JSR AudioTick
    JSR Rand             ; keeps the RNG state moving while we wait
    JSR ReadController
    LDA buttons
    AND #BTN_START
    BEQ @loop
    LDA lastButtons
    AND #BTN_START
    BNE @loop
    JSR StopMusic
    RTS

LevelClearScreen:
    JSR StopMusic
    JSR StopSfx
    JSR ScreenOff
    JSR HideAllSprites
    JSR ClearNametable
    LDA #8
    JSR DrawBrickRow
    LDA #21
    JSR DrawBrickRow
    PRINTLIST ClearList
    PPUADDR $2000+14*32+19
    LDA level
    JSR PrintDec3
    PPUADDR $2000+16*32+13
    LDA goal
    JSR PrintDec3
    JSR ScreenOnText
    LDX #150
@w:
    JSR WaitVBlankPoll
    DEX
    BNE @w
    RTS

GameOverScreen:
    JSR StopMusic
    JSR StopSfx
    JSR ScreenOff
    JSR HideAllSprites
    JSR ClearNametable
    LDA #8
    JSR DrawBrickRow
    LDA #21
    JSR DrawBrickRow
    PRINTLIST GameOverList
    PPUADDR $2000+14*32+24
    LDA level
    JSR PrintDec3
    JSR StartGameOverMusic
    JSR AudioTick
    JSR ScreenOnText
    LDX #60
@w:
    JSR WaitVBlankPoll
    DEX
    BNE @w
@loop:
    JSR WaitVBlankPoll
    JSR AudioTick
    JSR ReadController
    LDA buttons
    AND #BTN_START
    BEQ @loop
    JSR StopMusic
    RTS

; ------------------------------------------------------------
; BuildLevel: generate the maze, draw everything, start rendering
; ------------------------------------------------------------
BuildLevel:
    JSR ScreenOff
    JSR HideAllSprites
    JSR GenerateMaze
    JSR StartGameplayMusic
    LDA level
    SEC
    SBC #1
    AND #7
    TAX
    LDA WallColors, X
    JSR SetWallColor
    JSR InitLevelVars
    JSR DrawMaze
    JSR DrawHudStatic
    JSR ScreenOnPlay
    RTS

; nametable: 2 blank HUD rows, then maze rows 2..29, then attributes
DrawMaze:
    PPUADDR $2000
    LDA #0
    LDX #64
@b:
    STA $2007
    DEX
    BNE @b
    LDA #<(MazeRAM+64)
    STA strPtr
    LDA #>(MazeRAM+64)
    STA strPtr+1
    LDX #3
    LDY #0
@pg:
    LDA (strPtr), Y
    STA $2007
    INY
    BNE @pg
    INC strPtr+1
    DEX
    BNE @pg
    LDY #0
@rest:
    LDA (strPtr), Y
    STA $2007
    INY
    CPY #128
    BNE @rest
    LDA #0
    LDX #64
@a:
    STA $2007
    DEX
    BNE @a
    RTS

DrawHudStatic:
    PRINTLIST HudList
    PPUADDR $2020+4
    LDA level
    JSR PrintDec3
    PPUADDR $2020+14
    LDA kills
    JSR PrintDec3
    PPUADDR $2020+18
    LDA goal
    JSR PrintDec3
    PPUADDR $2020+26
    LDA hp
    CLC
    ADC #'0'
    STA $2007
    RTS

; A = cell x -> pixel x of a sprite centred in that cell (24*cx+12)
CellPixX:
    STA cpT
    ASL A
    ASL A
    ASL A
    STA cpU
    LDA cpT
    ASL A
    ASL A
    ASL A
    ASL A
    CLC
    ADC cpU
    CLC
    ADC #12
    RTS

; A = cell y -> pixel y (24*cy+28)
CellPixY:
    STA cpT
    ASL A
    ASL A
    ASL A
    STA cpU
    LDA cpT
    ASL A
    ASL A
    ASL A
    ASL A
    CLC
    ADC cpU
    CLC
    ADC #28
    RTS

InitLevelVars:
    LDA #MAZE_W
    JSR RandMod
    JSR CellPixX
    STA spriteX
    LDA #MAZE_H
    JSR RandMod
    JSR CellPixY
    STA spriteY
    LDA #TILE_DOWN
    STA spriteTile
    LDA #1
    STA lastDir

    LDA #0
    STA fireActive
    STA kills
    STA active
    LDA #60
    STA invuln
    LDA #40
    STA spawnTimer

    LDX #(MAX_ENEMIES-1)
    LDA #0
@c:
    STA eAct, X
    STA bAct, X
    DEX
    BPL @c

    ; enemyMax = min(5, 2 + level/2)
    LDA level
    LSR A
    CLC
    ADC #2
    CMP #(MAX_ENEMIES+1)
    BCC @em
    LDA #MAX_ENEMIES
@em:
    STA enemyMax

    ; enemySpeed = 122 + 6*min(level,17)   (fraction of a pixel per frame, /256)
    LDX level
    CPX #17
    BCC @sp
    LDX #17
@sp:
    LDA #122
@spl:
    CLC
    ADC #6
    DEX
    BNE @spl
    STA enemySpeed

    ; shootBase = 104 - 4*min(level,15)   (frames between shots)
    LDX level
    CPX #15
    BCC @sh
    LDX #15
@sh:
    LDA #104
@shl:
    SEC
    SBC #4
    DEX
    BNE @shl
    STA shootBase

    ; shootAccuracy = 32 + 14*(level-1), capped at level 16.
    ; A low value makes most aligned shots deliberately miss their aim.
    LDA #32
    LDX level
    DEX
    BEQ @ac
    CPX #15
    BCC @acLoop
    LDX #15
@acLoop:
    CLC
    ADC #14
    DEX
    BNE @acLoop
@ac:
    STA shootAccuracy

    ; bulletSpeed = 2, or 3 from level 6
    LDA #2
    LDX level
    CPX #6
    BCC @bs
    LDA #3
@bs:
    STA bulletSpeed

    JSR RefreshHud
    RTS

; ------------------------------------------------------------
; Maze generation
; ------------------------------------------------------------
; CalcTileAddr: tileCol, tileRow -> tileAddr (MazeRAM + row*32 + col). Uses Y.
CalcTileAddr:
    LDY tileRow
    LDA RowAddrLo, Y
    CLC
    ADC tileCol
    STA tileAddr
    LDA RowAddrHi, Y
    ADC #0
    STA tileAddr+1
    RTS

; A = value -> MazeRAM[tileRow][tileCol]
SetTile:
    PHA
    JSR CalcTileAddr
    PLA
    LDY #0
    STA (tileAddr), Y
    RTS

; cell (genX,genY) -> top-left tile (cellTX,cellTY) = (1+3*gx, 3+3*gy)
CellOrigin:
    LDA genX
    ASL A
    CLC
    ADC genX
    CLC
    ADC #1
    STA cellTX
    LDA genY
    ASL A
    CLC
    ADC genY
    CLC
    ADC #3
    STA cellTY
    RTS

; mark (genX,genY) visited and carve its 2x2 floor
VisitCell:
    LDA genY
    ASL A
    ASL A
    ASL A
    ASL A
    ORA genX
    TAX
    LDA #1
    STA VisitedRAM, X
    JSR CellOrigin
    LDA cellTX
    STA tileCol
    LDA cellTY
    STA tileRow
    LDA #FLOOR
    JSR SetTile
    INC tileCol
    LDA #FLOOR
    JSR SetTile
    INC tileRow
    LDA #FLOOR
    JSR SetTile
    DEC tileCol
    LDA #FLOOR
    JSR SetTile
    RTS

; knock out the 2 wall tiles between (genX,genY) and its neighbour in genDir
CarvePassage:
    JSR CellOrigin
    LDX genDir
    LDA cellTX
    CLC
    ADC PassDX, X
    STA tileCol
    LDA cellTY
    CLC
    ADC PassDY, X
    STA tileRow
    LDA #FLOOR
    JSR SetTile
    LDX genDir
    LDA tileCol
    CLC
    ADC PassDDX, X
    STA tileCol
    LDA tileRow
    CLC
    ADC PassDDY, X
    STA tileRow
    LDA #FLOOR
    JSR SetTile
    RTS

PushCell:
    LDA genY
    ASL A
    ASL A
    ASL A
    ASL A
    ORA genX
    LDX stackPtr
    STA CellStack, X
    INC stackPtr
    RTS

GenerateMaze:
    LDA #WALL
    LDX #0
@f1:
    STA MazeRAM, X
    STA MazeRAM+$100, X
    STA MazeRAM+$200, X
    INX
    BNE @f1
    LDX #0
@f2:
    STA MazeRAM+$300, X
    INX
    CPX #192
    BNE @f2

    LDA #0
    LDX #0
@v:
    STA VisitedRAM, X
    INX
    CPX #144
    BNE @v

    LDA #MAZE_W
    JSR RandMod
    STA genX
    LDA #MAZE_H
    JSR RandMod
    STA genY
    LDA #0
    STA stackPtr
    JSR VisitCell

@loop:
    LDA #0
    STA nbCount
    LDX #0
@dir:
    LDA genX
    CLC
    ADC DirDX, X
    STA nbX
    LDA genY
    CLC
    ADC DirDY, X
    STA nbY
    LDA nbX
    CMP #MAZE_W
    BCS @nextdir         ; also catches $FF (went negative)
    LDA nbY
    CMP #MAZE_H
    BCS @nextdir
    ASL A
    ASL A
    ASL A
    ASL A
    ORA nbX
    TAY
    LDA VisitedRAM, Y
    BNE @nextdir
    LDY nbCount
    TXA
    STA nbList, Y
    INC nbCount
@nextdir:
    INX
    CPX #4
    BNE @dir

    LDA nbCount
    BEQ @back
    JSR RandMod
    TAY
    LDA nbList, Y
    STA genDir
    JSR PushCell
    JSR CarvePassage
    LDX genDir
    LDA genX
    CLC
    ADC DirDX, X
    STA genX
    LDA genY
    CLC
    ADC DirDY, X
    STA genY
    JSR VisitCell
    JMP @loop

@back:
    LDA stackPtr
    BEQ @done
    DEC stackPtr
    LDX stackPtr
    LDA CellStack, X
    AND #$0F
    STA genX
    LDA CellStack, X
    LSR A
    LSR A
    LSR A
    LSR A
    STA genY
    JMP @loop

@done:
    ; extra random openings so the maze has loops
    LDA #EXTRA_COUNT
    STA extraCnt
@extra:
    LDA #MAZE_W
    JSR RandMod
    STA genX
    LDA #MAZE_H
    JSR RandMod
    STA genY
    JSR Rand
    AND #1
    BEQ @right
    LDA genY
    CMP #(MAZE_H-1)
    BCS @skip
    LDA #1               ; down
    STA genDir
    JSR CarvePassage
    JMP @skip
@right:
    LDA genX
    CMP #(MAZE_W-1)
    BCS @skip
    LDA #3               ; right
    STA genDir
    JSR CarvePassage
@skip:
    DEC extraCnt
    BNE @extra
    RTS

; ------------------------------------------------------------
; Controller
; ------------------------------------------------------------
ReadController:
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016

    LDA buttons
    STA lastButtons

    LDA #$00
    STA buttons

    LDX #8
@rl:
    LDA $4016
    AND #$01
    LSR A
    ROL buttons
    DEX
    BNE @rl
    RTS

; ------------------------------------------------------------
; Collision: ONE routine for every moving thing
;
; BoxHitsWall: newX,newY = candidate top-left of an 8x8 sprite.
;   A=0 (Z set)  -> its 4x4 hitbox (pixels 2..5) is clear
;   A=1 (Z clear)-> some corner touches a wall / leaves the screen
;   Preserves X.
; ------------------------------------------------------------
CheckTileWall:
    JSR CalcTileAddr
    LDY #0
    LDA (tileAddr), Y
    RTS

BoxHitsWall:
    LDA newX
    CMP #(256-8)
    BCS BHW_Wall
    LDA newY
    CMP #(240-8)
    BCS BHW_Wall

    LDA newX
    CLC
    ADC #HB_LO
    LSR A
    LSR A
    LSR A
    STA boxColL
    LDA newX
    CLC
    ADC #HB_HI
    LSR A
    LSR A
    LSR A
    STA boxColR
    LDA newY
    CLC
    ADC #HB_LO
    LSR A
    LSR A
    LSR A
    STA boxRowT
    LDA newY
    CLC
    ADC #HB_HI
    LSR A
    LSR A
    LSR A
    STA boxRowB

    LDA boxColL
    STA tileCol
    LDA boxRowT
    STA tileRow
    JSR CheckTileWall
    CMP #WALL
    BEQ BHW_Wall

    LDA boxColR
    STA tileCol
    JSR CheckTileWall
    CMP #WALL
    BEQ BHW_Wall

    LDA boxRowB
    STA tileRow
    JSR CheckTileWall
    CMP #WALL
    BEQ BHW_Wall

    LDA boxColL
    STA tileCol
    JSR CheckTileWall
    CMP #WALL
    BEQ BHW_Wall

    LDA #0
    RTS
BHW_Wall:
    LDA #1
    RTS

; A = dir (0 up, 1 down, 2 left, 3 right): move newX/newY 1 px
StepByDir:
    CMP #0
    BNE @notUp
    DEC newY
    RTS
@notUp:
    CMP #1
    BNE @notDown
    INC newY
    RTS
@notDown:
    CMP #2
    BNE @right
    DEC newX
    RTS
@right:
    INC newX
    RTS

; Overlap: box1 (hx1,hy1) vs box2 (hx2,hy2), both 6x6 inset boxes.
; A=1 (Z clear) if they overlap, A=0 (Z set) if not.  Preserves X.
Overlap:
    LDA hx1
    SEC
    SBC hx2
    BCS @a
    EOR #$FF
    ADC #1
@a:
    CMP #HIT_DIST
    BCS @no
    LDA hy1
    SEC
    SBC hy2
    BCS @b
    EOR #$FF
    ADC #1
@b:
    CMP #HIT_DIST
    BCS @no
    LDA #1
    RTS
@no:
    LDA #0
    RTS

; ------------------------------------------------------------
; Player
; ------------------------------------------------------------
MoveSprite:
    LDA buttons
    AND #BTN_UP
    BEQ @down
    LDA #0
    JSR TryMovePlayer
@down:
    LDA buttons
    AND #BTN_DOWN
    BEQ @left
    LDA #1
    JSR TryMovePlayer
@left:
    LDA buttons
    AND #BTN_LEFT
    BEQ @right
    LDA #2
    JSR TryMovePlayer
@right:
    LDA buttons
    AND #BTN_RIGHT
    BEQ @done
    LDA #3
    JSR TryMovePlayer
@done:
    RTS

TryMovePlayer:
    STA tmpA
    LDA spriteX
    STA newX
    LDA spriteY
    STA newY
    LDA tmpA
    JSR StepByDir
    JSR BoxHitsWall
    BNE @blocked
    LDA newX
    STA spriteX
    LDA newY
    STA spriteY
    LDA tmpA
    STA lastDir
    TAX
    LDA PlayerTiles, X
    STA spriteTile
@blocked:
    RTS

PlayerTiles:
    .byte TILE_UP, TILE_DOWN, TILE_LEFT, TILE_RIGHT

TryShootFire:
    LDA buttons
    AND #(BTN_A|BTN_B)
    BEQ @done
    LDA lastButtons
    AND #(BTN_A|BTN_B)
    BNE @done            ; already held
    LDA fireActive
    BNE @done
    LDA #1
    STA fireActive
    LDA spriteX
    STA fireX
    LDA spriteY
    STA fireY
    LDA lastDir
    STA fireDir
    JSR PlayShootSfx
@done:
    RTS

; fireball: FIRE_SPEED single-pixel steps per frame
UpdateFire:
    LDA fireActive
    BNE @go
    RTS
@go:
    LDX #FIRE_SPEED
@step:
    LDA fireX
    STA newX
    LDA fireY
    STA newY
    LDA fireDir
    JSR StepByDir
    JSR BoxHitsWall      ; preserves X
    BNE @kill
    LDA newX
    STA fireX
    LDA newY
    STA fireY
    DEX
    BNE @step
    RTS
@kill:
    LDA #0
    STA fireActive
    RTS

DamagePlayer:
    LDA hp
    BEQ @r
    DEC hp
    LDA #90
    STA invuln
    JSR PlayHurtSfx
    JSR RefreshHud
@r:
    RTS

; kills + hp -> digit tiles for the NMI to write
RefreshHud:
    LDA kills
    JSR BinToDec3
    LDA decH
    CLC
    ADC #'0'
    STA hudK0
    LDA decT
    CLC
    ADC #'0'
    STA hudK1
    LDA decO
    CLC
    ADC #'0'
    STA hudK2
    LDA hp
    CLC
    ADC #'0'
    STA hudHP
    LDA #1
    STA hudDirty
    RTS

; ------------------------------------------------------------
; Enemies
; ------------------------------------------------------------
; X = enemy -> tmpA=|dx| tmpB=|dy| tmpC=horizontal dir to player tmpD=vertical dir
AimInfo:
    LDA spriteX
    SEC
    SBC eX, X
    LDY #3
    BCS @a
    EOR #$FF
    CLC
    ADC #1
    LDY #2
@a:
    STA tmpA
    STY tmpC
    LDA spriteY
    SEC
    SBC eY, X
    LDY #1
    BCS @b
    EOR #$FF
    CLC
    ADC #1
    LDY #0
@b:
    STA tmpB
    STY tmpD
    RTS

; X = enemy -> A = new direction (half random, half toward the player)
PickDir:
    JSR Rand
    AND #$01
    BEQ @chase
    JSR Rand
    AND #$03
    RTS
@chase:
    JSR AimInfo
    LDA tmpA
    CMP tmpB
    BCC @vert
    LDA tmpC
    RTS
@vert:
    LDA tmpD
    RTS

; choose a spawn point >= 64 px from the player (X preserved)
PickSpawn:
    LDA #20
    STA tmpD
@try:
    LDA #MAZE_W
    JSR RandMod
    JSR CellPixX
    STA spawnX
    LDA #MAZE_H
    JSR RandMod
    JSR CellPixY
    STA spawnY
    LDA spriteX
    STA absB
    LDA spawnX
    JSR AbsDiff
    CMP #64
    BCS @ok
    LDA spriteY
    STA absB
    LDA spawnY
    JSR AbsDiff
    CMP #64
    BCS @ok
    DEC tmpD
    BNE @try
@ok:
    RTS

SpawnEnemy:
    LDA spawnTimer
    BEQ @try
    DEC spawnTimer
    RTS
@try:
    LDA active
    CMP enemyMax
    BCS @no
    CLC
    ADC kills
    CMP goal             ; never spawn more enemies than the goal needs
    BCS @no
    LDX #0
@find:
    LDA eAct, X
    BEQ @free
    INX
    CPX #MAX_ENEMIES
    BNE @find
@no:
    RTS
@free:
    JSR PickSpawn
    LDA spawnX
    STA eX, X
    LDA spawnY
    STA eY, X
    LDA #1
    STA eAct, X
    LDA #0
    STA eAcc, X
    JSR Rand
    AND #$03
    STA eDir, X
    JSR Rand
    AND #$3F
    CLC
    ADC #30
    STA eTurn, X
    JSR Rand
    AND #$1F
    CLC
    ADC shootBase
    STA eTim, X
    INC active
    LDA #50
    STA spawnTimer
    RTS

UpdateEnemies:
    LDX #0
@next:
    LDA eAct, X
    BEQ @skip
    JSR UpdateOneEnemy
@skip:
    INX
    CPX #MAX_ENEMIES
    BNE @next
    RTS

UpdateOneEnemy:
    ; --- move (fractional speed) ---
    LDA eAcc, X
    CLC
    ADC enemySpeed
    STA eAcc, X
    BCC @nomove
    LDA eX, X
    STA newX
    LDA eY, X
    STA newY
    LDA eDir, X
    JSR StepByDir
    JSR BoxHitsWall
    BNE @blocked
    LDA newX
    STA eX, X
    LDA newY
    STA eY, X
    JMP @nomove
@blocked:
    JSR PickDir
    STA eDir, X
@nomove:
    ; --- turn timer ---
    DEC eTurn, X
    BNE @noturn
    JSR Rand
    AND #$3F
    CLC
    ADC #30
    STA eTurn, X
    JSR PickDir
    STA eDir, X
@noturn:
    ; --- shoot timer ---
    DEC eTim, X
    BNE @done
    JSR AimInfo
    LDA tmpB             ; same row as the player?
    CMP #8
    BCS @notrow
    LDA tmpC
    JMP @shoot
@notrow:
    LDA tmpA             ; same column?
    CMP #8
    BCS @noalign
    LDA tmpD
    JMP @shoot
@noalign:
    LDA #12              ; not lined up: look again soon
    STA eTim, X
    RTS
@shoot:
    LDY bAct, X
    BNE @busy            ; its last bullet is still flying
    STA tmpA             ; direction toward the player
    JSR Rand
    CMP shootAccuracy
    BCS @scatter
    LDA tmpA
    JMP @setDir
@scatter:
    JSR Rand
    AND #$03             ; inaccurate shot: deliberately scatter
@setDir:
    STA bDir, X
    STA eDir, X          ; face the direction of the shot
    LDA #1
    STA bAct, X
    LDA eX, X
    STA bX, X
    LDA eY, X
    STA bY, X
    JSR Rand
    AND #$1F
    CLC
    ADC shootBase
    STA eTim, X
    RTS
@busy:
    LDA #10
    STA eTim, X
@done:
    RTS

UpdateBullets:
    LDX #0
@next:
    LDA bAct, X
    BEQ @skip
    LDA bulletSpeed
    STA tmpD
@step:
    LDA bX, X
    STA newX
    LDA bY, X
    STA newY
    LDA bDir, X
    JSR StepByDir
    JSR BoxHitsWall
    BNE @kill
    LDA newX
    STA bX, X
    LDA newY
    STA bY, X
    DEC tmpD
    BNE @step
    JMP @skip
@kill:
    LDA #0
    STA bAct, X
@skip:
    INX
    CPX #MAX_ENEMIES
    BNE @next
    RTS

CheckCollisions:
    ; --- player fireball vs enemies ---
    LDA fireActive
    BEQ @player
    LDX #0
@fe:
    LDA eAct, X
    BEQ @fnext
    LDA fireX
    STA hx1
    LDA fireY
    STA hy1
    LDA eX, X
    STA hx2
    LDA eY, X
    STA hy2
    JSR Overlap
    BEQ @fnext
    LDA #0               ; hit!
    STA eAct, X
    STA fireActive
    DEC active
    INC kills
    JSR PlayExplosionSfx
    JSR RefreshHud
    JMP @player
@fnext:
    INX
    CPX #MAX_ENEMIES
    BNE @fe

    ; --- enemy bullets and bodies vs player ---
@player:
    LDA invuln
    BNE @done
    LDA spriteX
    STA hx2
    LDA spriteY
    STA hy2
    LDX #0
@pe:
    LDA bAct, X
    BEQ @body
    LDA bX, X
    STA hx1
    LDA bY, X
    STA hy1
    JSR Overlap
    BEQ @body
    LDA #0
    STA bAct, X
    JMP DamagePlayer     ; (tail call) sets invuln, so we are finished
@body:
    LDA eAct, X
    BEQ @pnext
    LDA eX, X
    STA hx1
    LDA eY, X
    STA hy1
    JSR Overlap
    BEQ @pnext
    JMP DamagePlayer
@pnext:
    INX
    CPX #MAX_ENEMIES
    BNE @pe
@done:
    RTS

; ------------------------------------------------------------
; OAM buffer: 0=player 1=fireball 2..6=enemies 7..11=enemy bullets
; Y is written as Y-1 because sprites are drawn one scanline lower.
; ------------------------------------------------------------
WriteOAM:
    LDA invuln
    AND #$04
    BNE @hideP           ; blink while invulnerable
    LDA spriteY
    SEC
    SBC #1
    STA OAM
    LDA spriteTile
    STA OAM+1
    LDA #0
    STA OAM+2
    LDA spriteX
    STA OAM+3
    JMP @fire
@hideP:
    LDA #$F0
    STA OAM
@fire:
    LDA fireActive
    BEQ @hideF
    LDA fireY
    SEC
    SBC #1
    STA OAM+4
    LDA #TILE_FIRE
    STA OAM+5
    LDA #1
    STA OAM+6
    LDA fireX
    STA OAM+7
    JMP @enemies
@hideF:
    LDA #$F0
    STA OAM+4

@enemies:
    LDA frameCnt         ; enemies flip every 16 frames (cheap animation)
    AND #$10
    ASL A
    ASL A
    ORA #$02
    STA tmpA
    LDX #0
    LDY #8
@el:
    LDA eAct, X
    BEQ @eh
    LDA eY, X
    SEC
    SBC #1
    STA OAM, Y
    LDA #TILE_ENEMY
    STA OAM+1, Y
    LDA tmpA
    STA OAM+2, Y
    LDA eX, X
    STA OAM+3, Y
    JMP @en
@eh:
    LDA #$F0
    STA OAM, Y
@en:
    INY
    INY
    INY
    INY
    INX
    CPX #MAX_ENEMIES
    BNE @el

    LDX #0
@bl:
    LDA bAct, X
    BEQ @bh
    LDA bY, X
    SEC
    SBC #1
    STA OAM, Y
    LDA #TILE_BULLET
    STA OAM+1, Y
    LDA #3
    STA OAM+2, Y
    LDA bX, X
    STA OAM+3, Y
    JMP @bn
@bh:
    LDA #$F0
    STA OAM, Y
@bn:
    INY
    INY
    INY
    INY
    INX
    CPX #MAX_ENEMIES
    BNE @bl
    RTS

; ------------------------------------------------------------
; PlayLevel: the frame loop. Returns A=1 level cleared, A=0 dead.
; ------------------------------------------------------------
WaitNMI:
    LDA frameCnt
    CMP lastFrame
    BEQ WaitNMI
    STA lastFrame
    RTS

PlayLevel:
    LDA frameCnt
    STA lastFrame
@frame:
    JSR WaitNMI
    JSR AudioTick
    JSR Rand             ; mixes player timing into the RNG
    JSR ReadController
    LDA buttons
    AND #BTN_START
    BEQ @notPause
    LDA lastButtons
    AND #BTN_START
    BNE @notPause
    JSR PauseGame
@notPause:
    LDA invuln
    BEQ @noinv
    DEC invuln
@noinv:
    JSR MoveSprite
    JSR TryShootFire
    JSR UpdateFire
    JSR SpawnEnemy
    JSR UpdateEnemies
    JSR UpdateBullets
    JSR CheckCollisions
    JSR WriteOAM
    LDA hp
    BEQ @dead
    LDA kills
    CMP goal
    BCS @won
    JMP @frame
@dead:
    JSR Pause
    LDA #0
    RTS
@won:
    JSR Pause
    LDA #1
    RTS

Pause:
    LDX #40
@p:
    JSR WaitNMI
    DEX
    BNE @p
    RTS

; Pause gameplay until Start is released and pressed again.
PauseGame:
    LDA #1
    STA paused
    JSR StopMusic
    JSR StopSfx
    JSR WaitNMI
    PPUADDR $2000+14*32+13
    LDX #0
@show:
    LDA PauseStr, X
    STA $2007
    INX
    CPX #6
    BNE @show
    LDA #0
    STA $2005
    STA $2005
@waitRelease:
    JSR WaitNMI
    JSR ReadController
    LDA buttons
    AND #BTN_START
    BNE @waitRelease
@waitPress:
    JSR WaitNMI
    JSR ReadController
    LDA buttons
    AND #BTN_START
    BEQ @waitPress
    LDA lastButtons
    AND #BTN_START
    BNE @waitPress
    PPUADDR $2000+14*32+13
    LDX #6
    LDA #0
@clear:
    STA $2007
    DEX
    BNE @clear
    LDA #0
    STA $2005
    STA $2005
    STA paused
    JSR StartGameplayMusic
    RTS

; ============================================================
; DATA
; ============================================================
.include "music/famitone5_game.s"
.include "music/nes_07-simple.s"
.include "music/nes_23-chill.s"

; NTSC pulse timer values: 1789773 / (16 * frequency) - 1.
GameOverMusicPeriods:
    .byte $AB,$38,$DE,$FA,$A3,$F6,$AB,$38
GameOverMusicPeriodsHi:
    .byte $01,$02,$01,$01,$02,$02,$01,$02
GameOverMusicDurations:
    .byte 24,24,24,24,24,24,36,36

PaletteData:
    ; background 0: black, (unused), wall mortar, white (text / brick)
    .byte $0F,$01,$11,$30
    ; background 1: title letters (shadow red, text yellow)
    .byte $0F,$16,$27,$38
    .byte $0F,$01,$11,$30
    .byte $0F,$01,$11,$30
    ; sprite 0 player, 1 player fireball, 2 enemy, 3 enemy bullet
    .byte $0F,$0A,$1A,$2A
    .byte $0F,$07,$17,$27
    .byte $0F,$04,$14,$24
    .byte $0F,$06,$16,$26

; wall colour per level (cycles every 8 levels)
WallColors:
    .byte $11,$19,$16,$14,$17,$1C,$15,$18

; cell neighbours: up, down, left, right
DirDX:   .byte $00,$00,$FF,$01
DirDY:   .byte $FF,$01,$00,$00
; first wall tile offset (from cell top-left) and offset of the 2nd tile
PassDX:  .byte $00,$00,$FF,$02
PassDY:  .byte $FF,$02,$00,$00
PassDDX: .byte $01,$01,$00,$00
PassDDY: .byte $00,$00,$01,$01

RowAddrLo:
    .repeat 30, i
        .byte <(MazeRAM + i*32)
    .endrepeat
RowAddrHi:
    .repeat 30, i
        .byte >(MazeRAM + i*32)
    .endrepeat

PressStartStr:
    .byte "PRESS START"
PauseStr:
    .byte "PAUSED"

TitleSprites:               ; Y-1, tile, attribute, X
    .byte 195, TILE_RIGHT, 0,  72
    .byte 195, TILE_FIRE,  1, 104
    .byte 195, TILE_BULLET,3, 152
    .byte 195, TILE_ENEMY, 2, 184

; Text lists: [hiAddr, loAddr, tiles..., $FF] ... 0
TitleList:
    ; Dedicated credit row above the title, separated by two blank rows.
    TEXTAT 5, 5
    .byte "MADE BY TELOUANI AMINE", $FF
    TEXTAT 8, 5
    BIGTOP 'M'
    BIGTOP 'A'
    BIGTOP 'Z'
    BIGTOP 'E'
    .byte 0,0
    BIGTOP 'M'
    BIGTOP 'A'
    BIGTOP 'Y'
    BIGTOP 'H'
    BIGTOP 'E'
    BIGTOP 'M'
    .byte $FF
    TEXTAT 9, 5
    BIGBOT 'M'
    BIGBOT 'A'
    BIGBOT 'Z'
    BIGBOT 'E'
    .byte 0,0
    BIGBOT 'M'
    BIGBOT 'A'
    BIGBOT 'Y'
    BIGBOT 'H'
    BIGBOT 'E'
    BIGBOT 'M'
    .byte $FF
    ; attribute bytes: rows 8-11 use background palette 1 (yellow/red)
    .byte $23, $D0
    .byte $55,$55,$55,$55,$55,$55,$55,$55
    .byte $FF
    TEXTAT 13, 8
    .byte "SURVIVE THE MAZE", $FF
    TEXTAT 15, 3
    .byte "KILL 5 THEN 10 THEN 15...", $FF
    TEXTAT 18, 3
    .byte "D-PAD MOVE   A OR B SHOOT", $FF
    TEXTAT 22, 10
    .byte "PRESS START", $FF
    .byte 0

HudList:
    TEXTAT 1, 1
    .byte "LV", $FF
    TEXTAT 1, 8
    .byte "KILLS", $FF
    TEXTAT 1, 17
    .byte "/", $FF
    TEXTAT 1, 23
    .byte "HP", $FF
    .byte 0

ClearList:
    TEXTAT 11, 10
    .byte "LEVEL CLEAR!", $FF
    TEXTAT 14, 8
    .byte "NEXT LEVEL", $FF
    TEXTAT 16, 8
    .byte "KILL", $FF
    TEXTAT 16, 17
    .byte "ENEMIES", $FF
    .byte 0

GameOverList:
    TEXTAT 11, 11
    .byte "GAME OVER", $FF
    TEXTAT 14, 6
    .byte "YOU REACHED LEVEL", $FF
    TEXTAT 17, 10
    .byte "PRESS START", $FF
    .byte 0

; ============================================================
; VECTORS
; ============================================================
.segment "VECTORS"
    .word NMI
    .word RESET
    .word IRQ

; ============================================================
; CHR DATA: tile numbers = see constants at top (generated by gen_chr.py)
; ============================================================
.segment "CHARS"
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $00
    .byte $FF,$93,$FF,$34,$FF,$93,$FF,$34,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF   ; $01
    .byte $3C,$7E,$5A,$7E,$3C,$7E,$66,$66,$3C,$42,$42,$42,$3C,$00,$00,$00   ; $02
    .byte $66,$66,$7E,$3C,$7E,$5A,$7E,$3C,$00,$00,$00,$3C,$42,$42,$42,$3C   ; $03
    .byte $3C,$7E,$5E,$7E,$FE,$3E,$7C,$70,$3C,$42,$42,$42,$00,$00,$00,$00   ; $04
    .byte $3C,$7E,$7A,$7E,$7F,$7C,$3E,$0E,$3C,$42,$42,$42,$00,$00,$00,$00   ; $05
    .byte $18,$5A,$3C,$FF,$FF,$3C,$5A,$18,$18,$24,$42,$81,$81,$42,$24,$18   ; $06
    .byte $42,$BD,$FF,$DB,$FF,$DB,$BD,$42,$3C,$42,$81,$A5,$A5,$81,$42,$3C   ; $07
    .byte $00,$00,$18,$3C,$3C,$18,$00,$00,$00,$00,$00,$18,$18,$00,$00,$00   ; $08
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $09
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $0A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $0B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $0C
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $0D
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $0E
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $0F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $10
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $11
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $12
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $13
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $14
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $15
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $16
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $17
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $18
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $19
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $1A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $1B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $1C
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $1D
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $1E
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $1F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $20
    .byte $10,$10,$10,$10,$10,$00,$10,$00,$10,$10,$10,$10,$10,$00,$10,$00   ; $21
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $22
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $23
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $24
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $25
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $26
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $27
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $28
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $29
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $2A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $2B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $2C
    .byte $00,$00,$00,$7C,$00,$00,$00,$00,$00,$00,$00,$7C,$00,$00,$00,$00   ; $2D
    .byte $00,$00,$00,$00,$00,$30,$30,$00,$00,$00,$00,$00,$00,$30,$30,$00   ; $2E
    .byte $04,$04,$08,$10,$20,$40,$40,$00,$04,$04,$08,$10,$20,$40,$40,$00   ; $2F
    .byte $38,$44,$4C,$54,$64,$44,$38,$00,$38,$44,$4C,$54,$64,$44,$38,$00   ; $30
    .byte $10,$30,$10,$10,$10,$10,$38,$00,$10,$30,$10,$10,$10,$10,$38,$00   ; $31
    .byte $38,$44,$04,$08,$10,$20,$7C,$00,$38,$44,$04,$08,$10,$20,$7C,$00   ; $32
    .byte $78,$04,$04,$38,$04,$04,$78,$00,$78,$04,$04,$38,$04,$04,$78,$00   ; $33
    .byte $08,$18,$28,$48,$7C,$08,$08,$00,$08,$18,$28,$48,$7C,$08,$08,$00   ; $34
    .byte $7C,$40,$78,$04,$04,$44,$38,$00,$7C,$40,$78,$04,$04,$44,$38,$00   ; $35
    .byte $18,$20,$40,$78,$44,$44,$38,$00,$18,$20,$40,$78,$44,$44,$38,$00   ; $36
    .byte $7C,$04,$08,$10,$20,$20,$20,$00,$7C,$04,$08,$10,$20,$20,$20,$00   ; $37
    .byte $38,$44,$44,$38,$44,$44,$38,$00,$38,$44,$44,$38,$44,$44,$38,$00   ; $38
    .byte $38,$44,$44,$3C,$04,$08,$30,$00,$38,$44,$44,$3C,$04,$08,$30,$00   ; $39
    .byte $00,$30,$30,$00,$30,$30,$00,$00,$00,$30,$30,$00,$30,$30,$00,$00   ; $3A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $3B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $3C
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $3D
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $3E
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $3F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $40
    .byte $38,$44,$44,$7C,$44,$44,$44,$00,$38,$44,$44,$7C,$44,$44,$44,$00   ; $41
    .byte $78,$44,$44,$78,$44,$44,$78,$00,$78,$44,$44,$78,$44,$44,$78,$00   ; $42
    .byte $38,$44,$40,$40,$40,$44,$38,$00,$38,$44,$40,$40,$40,$44,$38,$00   ; $43
    .byte $78,$44,$44,$44,$44,$44,$78,$00,$78,$44,$44,$44,$44,$44,$78,$00   ; $44
    .byte $7C,$40,$40,$78,$40,$40,$7C,$00,$7C,$40,$40,$78,$40,$40,$7C,$00   ; $45
    .byte $7C,$40,$40,$78,$40,$40,$40,$00,$7C,$40,$40,$78,$40,$40,$40,$00   ; $46
    .byte $38,$44,$40,$5C,$44,$44,$3C,$00,$38,$44,$40,$5C,$44,$44,$3C,$00   ; $47
    .byte $44,$44,$44,$7C,$44,$44,$44,$00,$44,$44,$44,$7C,$44,$44,$44,$00   ; $48
    .byte $38,$10,$10,$10,$10,$10,$38,$00,$38,$10,$10,$10,$10,$10,$38,$00   ; $49
    .byte $1C,$08,$08,$08,$08,$48,$30,$00,$1C,$08,$08,$08,$08,$48,$30,$00   ; $4A
    .byte $44,$48,$50,$60,$50,$48,$44,$00,$44,$48,$50,$60,$50,$48,$44,$00   ; $4B
    .byte $40,$40,$40,$40,$40,$40,$7C,$00,$40,$40,$40,$40,$40,$40,$7C,$00   ; $4C
    .byte $44,$6C,$54,$54,$44,$44,$44,$00,$44,$6C,$54,$54,$44,$44,$44,$00   ; $4D
    .byte $44,$44,$64,$54,$4C,$44,$44,$00,$44,$44,$64,$54,$4C,$44,$44,$00   ; $4E
    .byte $38,$44,$44,$44,$44,$44,$38,$00,$38,$44,$44,$44,$44,$44,$38,$00   ; $4F
    .byte $78,$44,$44,$78,$40,$40,$40,$00,$78,$44,$44,$78,$40,$40,$40,$00   ; $50
    .byte $38,$44,$44,$44,$54,$48,$34,$00,$38,$44,$44,$44,$54,$48,$34,$00   ; $51
    .byte $78,$44,$44,$78,$50,$48,$44,$00,$78,$44,$44,$78,$50,$48,$44,$00   ; $52
    .byte $3C,$40,$40,$38,$04,$04,$78,$00,$3C,$40,$40,$38,$04,$04,$78,$00   ; $53
    .byte $7C,$10,$10,$10,$10,$10,$10,$00,$7C,$10,$10,$10,$10,$10,$10,$00   ; $54
    .byte $44,$44,$44,$44,$44,$44,$38,$00,$44,$44,$44,$44,$44,$44,$38,$00   ; $55
    .byte $44,$44,$44,$44,$44,$28,$10,$00,$44,$44,$44,$44,$44,$28,$10,$00   ; $56
    .byte $44,$44,$44,$54,$54,$54,$28,$00,$44,$44,$44,$54,$54,$54,$28,$00   ; $57
    .byte $44,$44,$28,$10,$28,$44,$44,$00,$44,$44,$28,$10,$28,$44,$44,$00   ; $58
    .byte $44,$44,$28,$10,$10,$10,$10,$00,$44,$44,$28,$10,$10,$10,$10,$00   ; $59
    .byte $7C,$04,$08,$10,$20,$40,$7C,$00,$7C,$04,$08,$10,$20,$40,$7C,$00   ; $5A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $5B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $5C
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $5D
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $5E
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $5F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $60
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $61
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $62
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $63
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $64
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $65
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $66
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $67
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $68
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $69
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $6A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $6B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $6C
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $6D
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $6E
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $6F
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $70
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $71
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $72
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $73
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $74
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $75
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $76
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $77
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $78
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $79
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $7A
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $7B
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $7C
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $7D
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $7E
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $7F
    .byte $0F,$0F,$37,$38,$38,$38,$3F,$3F,$0F,$0F,$30,$30,$30,$30,$3F,$3F   ; $80
    .byte $C0,$E0,$F0,$38,$38,$38,$F8,$F8,$C0,$C0,$30,$30,$30,$30,$F0,$F0   ; $81
    .byte $3F,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $82
    .byte $F8,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $83
    .byte $3F,$3F,$3F,$38,$38,$38,$3F,$3F,$3F,$3F,$30,$30,$30,$30,$3F,$3F   ; $84
    .byte $C0,$E0,$F0,$38,$38,$38,$D8,$E0,$C0,$C0,$30,$30,$30,$30,$C0,$C0   ; $85
    .byte $3F,$38,$38,$38,$3F,$3F,$1F,$00,$30,$30,$30,$30,$3F,$3F,$00,$00   ; $86
    .byte $F0,$38,$38,$38,$D8,$E0,$E0,$00,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $87
    .byte $0F,$0F,$37,$38,$38,$38,$38,$38,$0F,$0F,$30,$30,$30,$30,$30,$30   ; $88
    .byte $C0,$E0,$F0,$38,$18,$00,$00,$00,$C0,$C0,$30,$30,$00,$00,$00,$00   ; $89
    .byte $38,$38,$38,$38,$1F,$0F,$07,$00,$30,$30,$30,$30,$0F,$0F,$00,$00   ; $8A
    .byte $00,$00,$30,$38,$D8,$E0,$E0,$00,$00,$00,$30,$30,$C0,$C0,$00,$00   ; $8B
    .byte $3F,$3F,$3F,$38,$38,$38,$38,$38,$3F,$3F,$30,$30,$30,$30,$30,$30   ; $8C
    .byte $C0,$E0,$F0,$38,$38,$38,$38,$38,$C0,$C0,$30,$30,$30,$30,$30,$30   ; $8D
    .byte $38,$38,$38,$38,$3F,$3F,$1F,$00,$30,$30,$30,$30,$3F,$3F,$00,$00   ; $8E
    .byte $38,$38,$38,$38,$D8,$E0,$E0,$00,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $8F
    .byte $3F,$3F,$3F,$38,$38,$38,$3F,$3F,$3F,$3F,$30,$30,$30,$30,$3F,$3F   ; $90
    .byte $F0,$F8,$F8,$00,$00,$00,$C0,$E0,$F0,$F0,$00,$00,$00,$00,$C0,$C0   ; $91
    .byte $3F,$38,$38,$38,$3F,$3F,$1F,$00,$30,$30,$30,$30,$3F,$3F,$00,$00   ; $92
    .byte $E0,$00,$00,$00,$F0,$F8,$F8,$00,$00,$00,$00,$00,$F0,$F0,$00,$00   ; $93
    .byte $3F,$3F,$3F,$38,$38,$38,$3F,$3F,$3F,$3F,$30,$30,$30,$30,$3F,$3F   ; $94
    .byte $F0,$F8,$F8,$00,$00,$00,$C0,$E0,$F0,$F0,$00,$00,$00,$00,$C0,$C0   ; $95
    .byte $3F,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $96
    .byte $E0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $97
    .byte $0F,$0F,$37,$38,$38,$38,$3B,$3B,$0F,$0F,$30,$30,$30,$30,$33,$33   ; $98
    .byte $C0,$E0,$F0,$38,$18,$00,$F0,$F8,$C0,$C0,$30,$30,$00,$00,$F0,$F0   ; $99
    .byte $39,$38,$38,$38,$1F,$0F,$07,$00,$30,$30,$30,$30,$0F,$0F,$00,$00   ; $9A
    .byte $F8,$38,$38,$38,$F8,$F8,$F8,$00,$30,$30,$30,$30,$F0,$F0,$00,$00   ; $9B
    .byte $30,$38,$38,$38,$38,$38,$3F,$3F,$30,$30,$30,$30,$30,$30,$3F,$3F   ; $9C
    .byte $30,$38,$38,$38,$38,$38,$F8,$F8,$30,$30,$30,$30,$30,$30,$F0,$F0   ; $9D
    .byte $3F,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $9E
    .byte $F8,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $9F
    .byte $0F,$0F,$07,$03,$03,$03,$03,$03,$0F,$0F,$03,$03,$03,$03,$03,$03   ; $A0
    .byte $C0,$E0,$E0,$80,$80,$80,$80,$80,$C0,$C0,$00,$00,$00,$00,$00,$00   ; $A1
    .byte $03,$03,$03,$03,$0F,$0F,$07,$00,$03,$03,$03,$03,$0F,$0F,$00,$00   ; $A2
    .byte $80,$80,$80,$80,$C0,$E0,$E0,$00,$00,$00,$00,$00,$C0,$C0,$00,$00   ; $A3
    .byte $03,$03,$01,$00,$00,$00,$00,$00,$03,$03,$00,$00,$00,$00,$00,$00   ; $A4
    .byte $F0,$F8,$F8,$E0,$E0,$E0,$E0,$E0,$F0,$F0,$C0,$C0,$C0,$C0,$C0,$C0   ; $A5
    .byte $00,$00,$30,$38,$1F,$0F,$07,$00,$00,$00,$30,$30,$0F,$0F,$00,$00   ; $A6
    .byte $E0,$E0,$E0,$E0,$60,$80,$80,$00,$C0,$C0,$C0,$C0,$00,$00,$00,$00   ; $A7
    .byte $30,$38,$38,$38,$3B,$3B,$3D,$3E,$30,$30,$30,$30,$33,$33,$3C,$3C   ; $A8
    .byte $30,$38,$D8,$E0,$60,$80,$80,$00,$30,$30,$C0,$C0,$00,$00,$00,$00   ; $A9
    .byte $3F,$3B,$39,$38,$38,$38,$18,$00,$33,$33,$30,$30,$30,$30,$00,$00   ; $AA
    .byte $00,$80,$C0,$E0,$70,$38,$18,$00,$00,$00,$C0,$C0,$30,$30,$00,$00   ; $AB
    .byte $30,$38,$38,$38,$38,$38,$38,$38,$30,$30,$30,$30,$30,$30,$30,$30   ; $AC
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $AD
    .byte $38,$38,$38,$38,$3F,$3F,$1F,$00,$30,$30,$30,$30,$3F,$3F,$00,$00   ; $AE
    .byte $00,$00,$00,$00,$F0,$F8,$F8,$00,$00,$00,$00,$00,$F0,$F0,$00,$00   ; $AF
    .byte $30,$38,$3C,$3E,$3F,$3B,$3B,$3B,$30,$30,$3C,$3C,$33,$33,$33,$33   ; $B0
    .byte $30,$38,$F8,$F8,$78,$B8,$B8,$B8,$30,$30,$F0,$F0,$30,$30,$30,$30   ; $B1
    .byte $39,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $B2
    .byte $B8,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $B3
    .byte $30,$38,$38,$38,$3C,$3E,$3F,$3B,$30,$30,$30,$30,$3C,$3C,$33,$33   ; $B4
    .byte $30,$38,$38,$38,$38,$38,$38,$B8,$30,$30,$30,$30,$30,$30,$30,$30   ; $B5
    .byte $39,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $B6
    .byte $F8,$F8,$78,$38,$38,$38,$18,$00,$F0,$F0,$30,$30,$30,$30,$00,$00   ; $B7
    .byte $0F,$0F,$37,$38,$38,$38,$38,$38,$0F,$0F,$30,$30,$30,$30,$30,$30   ; $B8
    .byte $C0,$E0,$F0,$38,$38,$38,$38,$38,$C0,$C0,$30,$30,$30,$30,$30,$30   ; $B9
    .byte $38,$38,$38,$38,$1F,$0F,$07,$00,$30,$30,$30,$30,$0F,$0F,$00,$00   ; $BA
    .byte $38,$38,$38,$38,$D8,$E0,$E0,$00,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $BB
    .byte $3F,$3F,$3F,$38,$38,$38,$3F,$3F,$3F,$3F,$30,$30,$30,$30,$3F,$3F   ; $BC
    .byte $C0,$E0,$F0,$38,$38,$38,$D8,$E0,$C0,$C0,$30,$30,$30,$30,$C0,$C0   ; $BD
    .byte $3F,$38,$38,$38,$38,$38,$18,$00,$30,$30,$30,$30,$30,$30,$00,$00   ; $BE
    .byte $E0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $BF
    .byte $0F,$0F,$37,$38,$38,$38,$38,$38,$0F,$0F,$30,$30,$30,$30,$30,$30   ; $C0
    .byte $C0,$E0,$F0,$38,$38,$38,$38,$38,$C0,$C0,$30,$30,$30,$30,$30,$30   ; $C1
    .byte $3B,$3B,$39,$38,$1F,$0F,$07,$00,$33,$33,$30,$30,$0F,$0F,$00,$00   ; $C2
    .byte $38,$B8,$D8,$E0,$70,$B8,$98,$00,$30,$30,$C0,$C0,$30,$30,$00,$00   ; $C3
    .byte $3F,$3F,$3F,$38,$38,$38,$3F,$3F,$3F,$3F,$30,$30,$30,$30,$3F,$3F   ; $C4
    .byte $C0,$E0,$F0,$38,$38,$38,$D8,$E0,$C0,$C0,$30,$30,$30,$30,$C0,$C0   ; $C5
    .byte $3F,$3B,$39,$38,$38,$38,$18,$00,$33,$33,$30,$30,$30,$30,$00,$00   ; $C6
    .byte $E0,$80,$C0,$E0,$70,$38,$18,$00,$00,$00,$C0,$C0,$30,$30,$00,$00   ; $C7
    .byte $0F,$0F,$37,$38,$38,$38,$1F,$0F,$0F,$0F,$30,$30,$30,$30,$0F,$0F   ; $C8
    .byte $F0,$F8,$F8,$00,$00,$00,$C0,$E0,$F0,$F0,$00,$00,$00,$00,$C0,$C0   ; $C9
    .byte $07,$00,$00,$00,$3F,$3F,$1F,$00,$00,$00,$00,$00,$3F,$3F,$00,$00   ; $CA
    .byte $F0,$38,$38,$38,$D8,$E0,$E0,$00,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $CB
    .byte $3F,$3F,$1F,$03,$03,$03,$03,$03,$3F,$3F,$03,$03,$03,$03,$03,$03   ; $CC
    .byte $F0,$F8,$F8,$80,$80,$80,$80,$80,$F0,$F0,$00,$00,$00,$00,$00,$00   ; $CD
    .byte $03,$03,$03,$03,$03,$03,$01,$00,$03,$03,$03,$03,$03,$03,$00,$00   ; $CE
    .byte $80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $CF
    .byte $30,$38,$38,$38,$38,$38,$38,$38,$30,$30,$30,$30,$30,$30,$30,$30   ; $D0
    .byte $30,$38,$38,$38,$38,$38,$38,$38,$30,$30,$30,$30,$30,$30,$30,$30   ; $D1
    .byte $38,$38,$38,$38,$1F,$0F,$07,$00,$30,$30,$30,$30,$0F,$0F,$00,$00   ; $D2
    .byte $38,$38,$38,$38,$D8,$E0,$E0,$00,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $D3
    .byte $30,$38,$38,$38,$38,$38,$38,$38,$30,$30,$30,$30,$30,$30,$30,$30   ; $D4
    .byte $30,$38,$38,$38,$38,$38,$38,$38,$30,$30,$30,$30,$30,$30,$30,$30   ; $D5
    .byte $38,$38,$1C,$0E,$07,$03,$01,$00,$30,$30,$0C,$0C,$03,$03,$00,$00   ; $D6
    .byte $38,$38,$D8,$E0,$60,$80,$80,$00,$30,$30,$C0,$C0,$00,$00,$00,$00   ; $D7
    .byte $30,$38,$38,$38,$38,$38,$3B,$3B,$30,$30,$30,$30,$30,$30,$33,$33   ; $D8
    .byte $30,$38,$38,$38,$38,$38,$38,$B8,$30,$30,$30,$30,$30,$30,$30,$30   ; $D9
    .byte $3B,$3B,$3B,$3B,$1D,$0E,$06,$00,$33,$33,$33,$33,$0C,$0C,$00,$00   ; $DA
    .byte $B8,$B8,$B8,$B8,$D8,$E0,$60,$00,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $DB
    .byte $30,$38,$38,$38,$1C,$0E,$07,$03,$30,$30,$30,$30,$0C,$0C,$03,$03   ; $DC
    .byte $30,$38,$38,$38,$D8,$E0,$60,$80,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $DD
    .byte $0D,$0E,$36,$38,$38,$38,$18,$00,$0C,$0C,$30,$30,$30,$30,$00,$00   ; $DE
    .byte $C0,$E0,$70,$38,$38,$38,$18,$00,$C0,$C0,$30,$30,$30,$30,$00,$00   ; $DF
    .byte $30,$38,$38,$38,$1C,$0E,$07,$03,$30,$30,$30,$30,$0C,$0C,$03,$03   ; $E0
    .byte $30,$38,$38,$38,$D8,$E0,$60,$80,$30,$30,$30,$30,$C0,$C0,$00,$00   ; $E1
    .byte $03,$03,$03,$03,$03,$03,$01,$00,$03,$03,$03,$03,$03,$03,$00,$00   ; $E2
    .byte $80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $E3
    .byte $3F,$3F,$1F,$00,$00,$00,$03,$03,$3F,$3F,$00,$00,$00,$00,$03,$03   ; $E4
    .byte $F0,$F8,$F8,$38,$D8,$E0,$60,$80,$F0,$F0,$30,$30,$C0,$C0,$00,$00   ; $E5
    .byte $0D,$0E,$36,$38,$3F,$3F,$1F,$00,$0C,$0C,$30,$30,$3F,$3F,$00,$00   ; $E6
    .byte $80,$00,$00,$00,$F0,$F8,$F8,$00,$00,$00,$00,$00,$F0,$F0,$00,$00   ; $E7
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $E8
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $E9
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $EA
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $EB
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $EC
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $ED
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $EE
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $EF
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F0
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F1
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F2
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F3
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F4
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F5
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F6
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F7
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F8
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $F9
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $FA
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $FB
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $FC
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $FD
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $FE
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00   ; $FF
    .res 4096, $00      ; second 4 KB pattern table (unused)
