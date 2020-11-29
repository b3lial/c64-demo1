#import "vic.asm"
#import "kernal.asm"
#import "util.asm"
#import "colors.asm"
#import "cia.asm"

#define PLAY_MUSIC

.const SPRITE_OFFSET     = 200
.const MOVE_DELAY        = 2
.const PICSWAP_DELAY     = 10
.const COLOR_DELAY       = PICSWAP_DELAY * 8
.const SPEED_CHANGE_DELAY = 100
.const TEXT_DELAY        = 3
.const SCROLLER_DELAY    = 7
.const MOVE_STEP         = 4
.const BACKGROUND_COLOR  = BLACK
.const BORDER_COLOR      = BLUE

.struct SpriteStart {x, y, color}

.const Sprite0 = SpriteStart( 50, 130, RED)
.const Sprite1 = SpriteStart(120, 140, BLUE)
.const Sprite2 = SpriteStart( 90, 150, GREEN)
.const Sprite3 = SpriteStart( 60, 130, YELLOW)
.const Sprite4 = SpriteStart(190, 140, GREY)
.const Sprite5 = SpriteStart(220, 150, CYAN)
.const Sprite6 = SpriteStart( 30, 140, ORANGE)
.const Sprite7 = SpriteStart(150, 130, BLACK)

.macro setupStar(num, xstart, ystart, startcolor, offset) {
    set vic.SP0X+num*2 : #xstart
    set vic.SP0Y+num*2 : #ystart
    set vic.DEFAULT_SPRITE_POINTER_BASE+num : #offset
    set vic.SP0COL+num : #startcolor
}

.macro swapSpriteData(num, offset, counter) {
    ldx counter
    inx
    txa
    and #$7
    sta counter
    clc
    adc #offset
    sta vic.DEFAULT_SPRITE_POINTER_BASE+num
}

.macro nextColor(reg) {
    inc reg
    lda reg
    and #$F
    tax
    cpx #BACKGROUND_COLOR
    bne end
    inc reg
end:
}

.macro addSineToY(num, ystart) {
    ldx sine_index+num
    lda sine_table, X
    clc
    adc #ystart
    sta vic.SP0Y+num*2
    inx
    txa
    and #31
    sta sine_index+num
}

.macro moveSpriteHoriz(num) {
    // compute speed value as base(sprite index) + current modifier
    ldx speed_index
    lda speed_table, X
    clc
    adc base_speed+num
    // add speed to register
    clc
    adc vic.SP0X+num*2
    sta vic.SP0X+num*2
    // invert MSB if overflow occured in addition
    bcc no_overflow
    lda #1<<num
    eor vic.MSIGX
    sta vic.MSIGX
no_overflow:
    // check if X >= 320. If so, wrap around to 0 
    lda #1<<num
    bit vic.MSIGX
    beq end
    lda #320-255
    cmp vic.SP0X+num*2
    bpl end
    lda #1<<num
    eor vic.MSIGX
    sta vic.MSIGX
    set vic.SP0X+num*2 : #0
end:
}

//overwrite the character scanine with an empty string
.macro clearScanLine(lineOffset) {
    ldx #00
    lda empty_char 
clear_next_char:
    sta vic.DEFAULT_SCREEN_BASE+lineOffset,X
    inx 
    cpx #END_OF_LINE
    bne clear_next_char
}

//load colors for single character scanline
.macro loadColorTable(lineOffset) {
    ldx #00
load_next_char_color:
    lda color,X 
    sta COLOR_RAM+lineOffset,X
    inx 
    cpx #END_OF_LINE
    bne load_next_char_color
}


.label SEGMENT_START_ADDRESS = $1000
.label MUSIC_INIT = SEGMENT_START_ADDRESS
.label MUSIC_PLAY = SEGMENT_START_ADDRESS + $3

.label COLOR_RAM = $d800 
.var message1 = "c64 coding session rocks"
.var message2 = "although vx rulez as well!!!"
.label END_OF_LINE = $28
.label MSG1_X_POS = (END_OF_LINE - message1.size())/2
.label MSG2_X_POS = (END_OF_LINE - message2.size())/2

.var message3 = "demo by flex and chris"
.label INCREMENT_MODE = 1
.label DECREMENT_MODE = 0
.label CHARACTER_PER_LINE = 40
.label LINE_NUMBER = 24
.label MAX_X = CHARACTER_PER_LINE - message3.size()

.var music = LoadSid("music.sid")

.print ""
.print "SID Data"
.print "--------"
.print "location=$"+toHexString(music.location)
.print "init=$"+toHexString(music.init)
.print "play=$"+toHexString(music.play)
.print "songs="+music.songs
.print "startSong="+music.startSong
.print "size=$"+toHexString(music.size)
.print "name="+music.name
.print "author="+music.author
.print "copyright="+music.copyright
.print ""
.print "Additional tech data"
.print "--------------------"
.print "header="+music.header
.print "header version="+music.version
.print "flags="+toBinaryString(music.flags)
.print "speed="+toBinaryString(music.speed)
.print "startpage="+music.startpage
.print "pagelength="+music.pagelength

:BasicUpstart2(main)

* = SEGMENT_START_ADDRESS "Main"
.segmentout [sidFiles="music.sid"]

main:
    sei

    :setupStar(0, Sprite0.x, Sprite0.y, Sprite0.color, SPRITE_OFFSET+0)
    :setupStar(1, Sprite1.x, Sprite1.y, Sprite1.color, SPRITE_OFFSET+0)
    :setupStar(2, Sprite2.x, Sprite2.y, Sprite2.color, SPRITE_OFFSET+0)
    :setupStar(3, Sprite3.x, Sprite3.y, Sprite3.color, SPRITE_OFFSET+0)
    :setupStar(4, Sprite4.x, Sprite4.y, Sprite4.color, SPRITE_OFFSET+0)
    :setupStar(5, Sprite5.x, Sprite5.y, Sprite5.color, SPRITE_OFFSET+0)
    :setupStar(6, Sprite6.x, Sprite6.y, Sprite6.color, SPRITE_OFFSET+0)
    :setupStar(7, Sprite7.x, Sprite7.y, Sprite7.color, SPRITE_OFFSET+0)

    // set background color, clear screen
    set vic.EXTCOL : #BORDER_COLOR
    set vic.BGCOL0 : #BACKGROUND_COLOR
    jsr kernal.CLRSCR
    
    :loadColorTable(0)
    :loadColorTable(LINE_NUMBER*CHARACTER_PER_LINE)
    jsr loadMsg1
    jsr loadMsg2   

    // define color mode (multi color / single color) and expansion. Enable sprites then.
    set vic.SPMC   : #%00000000
//    set vic.XXPAND : #%11111111
//    set vic.YXPAND : #%11111111
    set vic.SPENA  : #%11111111

    :callEveryRaster(rasterFunc)

#if PLAY_MUSIC
    jsr MUSIC_INIT
#endif

    cli
    jmp *

rasterFunc:
#if PLAY_MUSIC
    jsr MUSIC_PLAY
#endif
    :callEveryXTime(MOVE_DELAY, moveSprite)
    :callEveryXTime(COLOR_DELAY, colorSprite)
    :callEveryXTime(PICSWAP_DELAY, swapSpritePics)
    :callEveryXTime(TEXT_DELAY, shiftText)
    :callEveryXTime(SCROLLER_DELAY, bottomScroller)
    :callEveryXTime(SPEED_CHANGE_DELAY, changeSpeed)
    rts
    
moveSprite:
    :moveSpriteHoriz(0)
    :moveSpriteHoriz(1)
    :moveSpriteHoriz(2)
    :moveSpriteHoriz(3)
    :moveSpriteHoriz(4)
    :moveSpriteHoriz(5)
    :moveSpriteHoriz(6)
    :moveSpriteHoriz(7)
    
    addSineToY(0, Sprite0.y)
    addSineToY(1, Sprite1.y)
    addSineToY(2, Sprite2.y)
    addSineToY(3, Sprite3.y)
    addSineToY(4, Sprite4.y)
    addSineToY(5, Sprite5.y)
    addSineToY(6, Sprite6.y)
    addSineToY(7, Sprite7.y)
    rts
    
colorSprite:
    :nextColor(vic.SP1COL)
    :nextColor(vic.SP2COL)
    :nextColor(vic.SP3COL)
    :nextColor(vic.SP4COL)
    :nextColor(vic.SP5COL)
    :nextColor(vic.SP6COL)
    :nextColor(vic.SP7COL)
    rts
    
swapSpritePics:
    :swapSpriteData(0, SPRITE_OFFSET, sprite_frame+0)
    :swapSpriteData(1, SPRITE_OFFSET, sprite_frame+1)
    :swapSpriteData(2, SPRITE_OFFSET, sprite_frame+2)
    :swapSpriteData(3, SPRITE_OFFSET, sprite_frame+3)
    :swapSpriteData(4, SPRITE_OFFSET, sprite_frame+4)
    :swapSpriteData(5, SPRITE_OFFSET, sprite_frame+5)
    :swapSpriteData(6, SPRITE_OFFSET, sprite_frame+6)
    :swapSpriteData(7, SPRITE_OFFSET, sprite_frame+7)
    rts
    
changeSpeed:
    inc speed_index
    lda speed_index
    and #15
    sta speed_index    
    rts

shiftText:
    //shift first line color bytes
    ldx #$27
    lda color+$27
cycle1:   
    ldy color-1,x
    sta color-1,x
    sta COLOR_RAM,x
    tya 
    dex
    bne cycle1 
    sta color+$27 
    sta COLOR_RAM

    //shift clors of second line           
    ldx #$00 
    lda color2+$27 
cycle2:   
    ldy color2,x 
    sta color2,x  
    sta COLOR_RAM+END_OF_LINE,x 
    tya 
    inx 
    cpx #$26 
    bne cycle2 
    sta color2+$27 
    sta COLOR_RAM+END_OF_LINE+$27 
    rts
    
//load static text
loadMsg1:
    ldx #$00
    ldy #MSG1_X_POS
load_next_char:
    lda msg1,X
    sta vic.DEFAULT_SCREEN_BASE,Y
    inx
    iny
    cpx #message1.size()
    bne load_next_char
    rts

msg1: .text message1

loadMsg2:
    ldx #$00
    ldy #MSG2_X_POS
load_next_char2:
    lda msg2,X
    sta vic.DEFAULT_SCREEN_BASE+END_OF_LINE,Y
    inx
    iny
    cpx #message2.size()
    bne load_next_char2
    rts

msg2: .text message2

//load colors for single character scanline
//y == row
loadColorTables:
    ldx #00
load_next_char_color:
    lda color,X 
    sta COLOR_RAM,Y
    inx 
    iny 
    cpx #END_OF_LINE
    bne load_next_char_color
    rts 
    
bottomScroller:
    :clearScanLine(LINE_NUMBER*CHARACTER_PER_LINE) //clear scanline in video ram

    //calculate next xpos of text
    ldy xpos
    cpy #0
    beq switch_increment_mode
    cpy #MAX_X
    beq switch_decrement_mode
    jmp move_x_pos
switch_increment_mode:
    lda #INCREMENT_MODE
    sta xdir
    jmp move_x_pos
switch_decrement_mode:
    lda #DECREMENT_MODE
    sta xdir
move_x_pos:
    ldx xpos 
    ldy xdir 
    cpy #INCREMENT_MODE
    beq move_x_pos_right
move_x_pos_left:
    dex
    jmp prepare_to_print
move_x_pos_right:
    inx
prepare_to_print:
    stx xpos

    //print text on screen
    ldx #$00
    ldy xpos
printmsg:
    lda msg,X
    sta vic.DEFAULT_SCREEN_BASE+(LINE_NUMBER*CHARACTER_PER_LINE),Y
    inx
    iny
    cpx #message3.size()
    bne printmsg
    rts

msg: .text message3
xpos: .byte 0
xdir: .byte 0

color:       .byte $09,$09,$02,$02,$08 
             .byte $08,$0a,$0a,$0f,$0f 
             .byte $07,$07,$01,$01,$01 
             .byte $01,$01,$01,$01,$01 
             .byte $01,$01,$01,$01,$01 
             .byte $01,$01,$01,$07,$07 
             .byte $0f,$0f,$0a,$0a,$08 
             .byte $08,$02,$02,$09,$09

color2:      .byte $09,$09,$02,$02,$08 
             .byte $08,$0a,$0a,$0f,$0f 
             .byte $07,$07,$01,$01,$01 
             .byte $01,$01,$01,$01,$01 
             .byte $01,$01,$01,$01,$01 
             .byte $01,$01,$01,$07,$07 
             .byte $0f,$0f,$0a,$0a,$08 
             .byte $08,$02,$02,$09,$09


empty_char: .byte ' '



sprite_frame: .byte 0, 1, 2, 3, 4,  5,  6,  7

// Current index in sine table. Start with equally distributed values.
sine_index:   .byte 0, 4, 8, 12, 16, 20, 24, 28

sine_table:
// 32 entry sine table with amplitude 40
.byte $00, $08, $0F, $16, $1C, $21, $25, $27, $28, $27, $25, $21, $1C, $16, $0F, $08
.byte $00, $F8, $F1, $EA, $E4, $DF, $DB, $D9, $D8, $D9, $DB, $DF, $E4, $EA, $F1, $F8

base_speed:
.byte MOVE_STEP+4
.byte MOVE_STEP+3
.byte MOVE_STEP+2
.byte MOVE_STEP+1
.byte MOVE_STEP+4
.byte MOVE_STEP+2
.byte MOVE_STEP+3
.byte MOVE_STEP+1

speed_index:  .byte 0
speed_table:  .byte 0, 1, 3, 6, 6, 6, 3, 1, 0, -1, -3, -4, -4, -4, -3, -1

*= SPRITE_OFFSET * 64

// Sprites

spr_img0:

.byte $00,$66,$00,$01,$e7,$80,$07,$e7,$e0,$0f,$e7,$f0,$1f,$e7,$f8,$1f
.byte $c7,$fc,$3f,$04,$fc,$3e,$04,$7c,$7e,$04,$7e,$7c,$04,$3e,$7c,$04
.byte $3e,$7c,$04,$3e,$7e,$00,$3e,$3e,$00,$7c,$3f,$00,$fc,$3f,$c3,$fc
.byte $1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

spr_img1:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$0f,$ff,$c0,$1f,$ff,$88,$1f
.byte $c3,$1c,$3f,$00,$3c,$3e,$00,$7c,$7e,$00,$fe,$7c,$01,$3e,$7c,$02
.byte $3e,$7c,$04,$3e,$7e,$00,$3e,$3e,$00,$7c,$3f,$00,$fc,$3f,$c3,$fc
.byte $1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

spr_img2:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$0f,$ff,$f0,$1f,$ff,$f8,$1f
.byte $c3,$fc,$3f,$00,$fc,$3e,$00,$7c,$7e,$00,$7e,$7c,$00,$3e,$7c,$00
.byte $00,$7c,$00,$00,$7e,$1f,$fe,$3e,$00,$7c,$3f,$00,$fc,$3f,$c3,$fc
.byte $1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

spr_img3:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$0f,$ff,$f0,$1f,$ff,$f8,$1f
.byte $c3,$fc,$3f,$00,$fc,$3e,$00,$7c,$7e,$00,$7e,$7c,$00,$3e,$7c,$00
.byte $3e,$7c,$10,$3e,$7e,$08,$3e,$3e,$04,$7c,$3f,$02,$3c,$3f,$c3,$1c
.byte $1f,$ff,$88,$0f,$ff,$c0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

spr_img4:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$0f,$ff,$f0,$1f,$ff,$f8,$1f
.byte $c3,$fc,$3f,$00,$fc,$3e,$00,$7c,$7e,$00,$7e,$7c,$00,$3e,$7c,$20
.byte $3e,$7c,$20,$3e,$7e,$20,$3e,$3e,$20,$7c,$3f,$20,$fc,$3f,$e3,$fc
.byte $1f,$e7,$f8,$0f,$e7,$f0,$07,$e7,$e0,$01,$e7,$c0,$00,$66,$00,$00

spr_img5:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$0f,$ff,$f0,$1f,$ff,$f8,$1f
.byte $c3,$fc,$3f,$00,$fc,$3e,$00,$7c,$7e,$00,$7e,$7c,$20,$3e,$7c,$40
.byte $3e,$7c,$80,$3e,$7f,$00,$3e,$3e,$00,$7c,$3c,$00,$fc,$38,$43,$fc
.byte $11,$ff,$f8,$03,$ff,$f0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

spr_img6:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$0f,$ff,$f0,$1f,$ff,$f8,$1f
.byte $c3,$fc,$3f,$00,$fc,$3e,$00,$7c,$7e,$00,$7e,$7f,$f0,$3e,$00,$00
.byte $3e,$00,$00,$3e,$7e,$00,$3e,$3e,$00,$7c,$3f,$00,$fc,$3f,$c3,$fc
.byte $1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

spr_img7:

.byte $00,$7e,$00,$01,$ff,$80,$07,$ff,$e0,$07,$ff,$f0,$03,$ff,$f8,$11
.byte $c3,$fc,$38,$80,$fc,$3c,$40,$7c,$7e,$20,$7e,$7c,$10,$3e,$7c,$08
.byte $3e,$7c,$00,$3e,$7e,$00,$3e,$3e,$00,$7c,$3f,$00,$fc,$3f,$c3,$fc
.byte $1f,$ff,$f8,$0f,$ff,$f0,$07,$ff,$e0,$01,$ff,$c0,$00,$7e,$00,$00

