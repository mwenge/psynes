; This is the reverse-engineered source code for the game 'Psychedelia'
; written by Jeff Minter in 1984.
;
; The code in this file was created by disassembling a binary of the game released into
; the public domain by Jeff Minter in 2019.
;
; The original code from which this source is derived is the copyright of Jeff Minter.
;
; The original home of this file is at: https://github.com/mwenge/psychedelia
;
; To the extent to which any copyright may apply to the act of disassembling and reconstructing
; the code from its binary, the author disclaims copyright to this source code.  In place of
; a legal notice, here is a blessing:
;
;    May you do good and not evil.
;    May you find forgiveness for yourself and forgive others.
;    May you share freely, never taking more than you give.

.feature labels_without_colons
.feature loose_char_term

.segment "ZEROPAGE"
pixelXPosition                   .res 1
pixelYPosition                   .res 1
baseLevelForCurrentPixel         .res 1
currentLineInColorRamLoPtr2      .res 1
currentLineInColorRamHiPtr2      .res 1
previousCursorXPositionZP        .res 1
previousPixelYPositionZP         .res 1
currentLineInColorRamLoPtr       .res 1
currentLineInColorRamHiPtr       .res 1
currentColorToPaint              .res 1
xPosLoPtr                        .res 1
xPosHiPtr                        .res 1
currentPatternElement            .res 1
yPosLoPtr                        .res 1
yPosHiPtr                        .res 1
timerBetweenKeyStrokes           .res 1
shouldDrawCursor                 .res 1
currentSymmetrySettingForStep    .res 1
currentSymmetrySetting           .res 1
offsetForYPos                    .res 1
skipPixel                        .res 1
colorBarColorRamLoPtr            .res 1
colorBarColorRamHiPtr            .res 1
currentColorSet                  .res 1
presetSequenceDataLoPtr          .res 1
presetSequenceDataHiPtr          .res 1
currentSequencePtrLo             .res 1
currentSequencePtrHi             .res 1
customPatternLoPtr               .res 1
customPatternHiPtr               .res 1
minIndexToColorValues            .res 1
initialBaseLevelForCustomPresets .res 1
currentIndexToPresetValue        .res 1
lastKeyPressed                   .res 1
presetLoPtr                      .res 1
presetHiPtr                      .res 1
colorRamLoPtr                    .res 1
colorRamHiPtr                    .res 1
screenBufferLoPtr                .RES 1
screenBufferHiPtr                .RES 1
paletteLoPtr                     .RES 1
paletteHiPtr                     .RES 1
playerPressedFire                .res 1
previousFrameButtons             .res 1
buttons                          .res 1
pressedButtons                   .res 1
releasedButtons                  .res 1
inputRateLimit                   .res 1

shiftKey                      = $028D
storageOfSomeKind             = $7FFF

CURSOR_TILE = $10

.include "constants.asm"

.SEGMENT "HEADER"

INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 1 ; 0 = HORIZONTAL MIRRORING, 1 = VERTICAL MIRRORING
INES_SRAM   = 1 ; 1 = BATTERY BACKED SRAM AT $6000-7FFF

.BYTE 'N', 'E', 'S', $1A ; ID
.BYTE $02 ; 16K PRG CHUNK COUNT
.BYTE $01 ; 8K CHR CHUNK COUNT
.BYTE INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $F) << 4)
.BYTE (INES_MAPPER & %11110000)
.BYTE $0, $0, $0, $0, $0, $0, $0, $0 ; PADDING

;
; CHR ROM
;

.SEGMENT "TILES"
.include "tileset.asm"


.SEGMENT "RODATA"
.include "palettes.asm"

;
; VECTORS PLACED AT TOP 6 BYTES OF MEMORY AREA
;

.SEGMENT "VECTORS"
.WORD MainNMIInterruptHandler ; NMI
.WORD InitializeNES        ; Reset
.WORD IRQInterruptHandler ; IRQ interrupt handler

; nmi routine
;

.segment "ZEROPAGE"
NMI_LOCK       .res 1 ; PREVENTS NMI RE-ENTRY
NMI_COUNT      .res 1 ; IS INCREMENTED EVERY NMI
NMI_READY      .res 1 ; SET TO 1 TO PUSH A PPU FRAME UPDATE, 2 TO TURN RENDERING OFF NEXT NMI
NMT_UPDATE_LEN .res 1 ; NUMBER OF BYTES IN NMT_UPDATE BUFFER
SCROLL_X       .res 1 ; X SCROLL POSITION
SCROLL_Y       .res 1 ; Y SCROLL POSITION
SCROLL_NMT     .res 1 ; NAMETABLE SELECT (0-3 = $2000,$2400,$2800,$2C00)
TEMP           .res 1 ; TEMPORARY VARIABLE

.segment "RAM"
NMT_UPDATE .res 256 ; NAMETABLE UPDATE ENTRY BUFFER FOR PPU UPDATE
PALETTE    .res 32  ; PALETTE BUFFER FOR PPU UPDATE

;.segment "OAM"
;OAM .res 256        ; SPRITE OAM DATA TO BE UPLOADED BY DMA

.segment "RODATA"
example_palette
.byte $0F,$15,$26,$37 ; bg0 purple/pink
.byte $0F,$09,$19,$29 ; bg1 green
.byte $0F,$01,$11,$21 ; bg2 blue
.byte $0F,$00,$10,$30 ; bg3 greyscale
.byte $0F,$18,$28,$38 ; sp0 yellow
.byte $0F,$14,$24,$34 ; sp1 purple
.byte $0F,$1B,$2B,$3B ; sp2 teal
.byte $0F,$12,$22,$32 ; sp3 marine

.segment "CODE"
;-------------------------------------------------------
; InitializeNES
;-------------------------------------------------------
InitializeNES
        SEI       ; MASK INTERRUPTS
        LDA #0
        STA $2000 ; DISABLE NMI
        STA $2001 ; DISABLE RENDERING
        STA $4015 ; DISABLE APU SOUND
        ;STA $4010 ; DISABLE DMC IRQ
        LDA #$00
        STA $4017 ; ENABLE APU IRQ
        CLD       ; DISABLE DECIMAL MODE
        LDX #$FF
        TXS       ; INITIALIZE STACK
        ; WAIT FOR FIRST VBLANK
        BIT $2002
        :
          BIT $2002
          BPL :-
        ; CLEAR ALL RAM TO 0
        LDA #0
        LDX #0
        :
          STA $0000, X
          STA $0100, X
          STA $0200, X
          STA $0300, X
          STA $0400, X
          STA $0500, X
          STA $0600, X
          STA $0700, X
          INX
          BNE :-

        ; WAIT FOR SECOND VBLANK
        :
          BIT $2002
          BPL :-
        ; NES IS INITIALIZED, READY TO BEGIN!
        ; ENABLE THE NMI FOR GRAPHICAL UPDATES, AND JUMP TO OUR MAIN PROGRAM
        LDA #%10001000
        STA $2000

        LDA paletteArrayLoPtr
        STA paletteLoPtr
        LDA paletteArrayHiPtr
        STA paletteHiPtr

        JSR MovePresetDataIntoPosition
        JSR WriteTitleText
        CLI
        JMP InitializeProgram

;-------------------------------------------------------
; WriteTitleText
;-------------------------------------------------------
WriteTitleText 
        JSR PPU_Off

        ; first nametable, start by clearing to empty
        lda $2002 ; reset latch
        lda #$21
        sta $2006
        lda #$FD
        sta $2006
        LDX #$00
        :
          LDA demoMessage,X
          STA $2007
          INX 
          CPX #$28
          BNE :-

        RTS 
;-------------------------------------------------------
; MainNMIInterruptHandler
;-------------------------------------------------------
MainNMIInterruptHandler
        ; save registers
        PHA
        TXA
        PHA
        TYA
        PHA

        ; PREVENT NMI RE-ENTRY
        LDA NMI_LOCK
        BEQ :+
          JMP @NMI_END
        :
        LDA #1
        STA NMI_LOCK
        ; INCREMENT FRAME COUNTER
        INC NMI_COUNT
        ;
        LDA NMI_READY
        BNE :+ ; NMI_READY == 0 NOT READY TO UPDATE PPU
          JMP @PPU_UPDATE_END
        :
        CMP #2 ; NMI_READY == 2 TURNS RENDERING OFF
        BNE :+
          LDA #%00000000
          STA $2001
          LDX #0
          STX NMI_READY
          JMP @PPU_UPDATE_END
        :

        ; SPRITE OAM DMA
        LDX #0
        STX $2003
        ; PALETTES
        LDA #%10001000
        STA $2000 ; SET HORIZONTAL NAMETABLE INCREMENT

        LDA $2002
        LDA #$3F
        STA $2006
        STX $2006 ; SET PPU ADDRESS TO $3F00

        LDY #0
        :
          LDA (paletteLoPtr), Y
          STA $2007
          INY
          CPY #16
          BCC :-


        ; NAMETABLE UPDATE
        LDX #0
        CPX NMT_UPDATE_LEN
        BCS @SCROLL

@NMT_UPDATE_LOOP
          LDA NMT_UPDATE, X
          STA $2006
          INX
          LDA NMT_UPDATE, X
          STA $2006
          INX
          LDA NMT_UPDATE, X
          STA $2007
          INX
          CPX NMT_UPDATE_LEN
          BCC @NMT_UPDATE_LOOP
        LDA #0
        STA NMT_UPDATE_LEN

@SCROLL
        LDA SCROLL_NMT
        AND #%00000011 ; KEEP ONLY LOWEST 2 BITS TO PREVENT ERROR
        ORA #%10001000
        STA $2000
        LDA SCROLL_X
        STA $2005
        LDA SCROLL_Y
        STA $2005
        ; ENABLE RENDERING
        LDA #%00011110
        STA $2001
        ; FLAG PPU UPDATE COMPLETE
        LDX #0
        STX NMI_READY

@PPU_UPDATE_END
        ; IF THIS ENGINE HAD MUSIC/SOUND, THIS WOULD BE A GOOD PLACE TO PLAY IT
        ; UNLOCK RE-ENTRY FLAG
        LDA #0
        STA NMI_LOCK

@NMI_END
        ; RESTORE REGISTERS AND RETURN
        PLA
        TAY
        PLA
        TAX
        PLA
        RTI

;-------------------------------------------------------
; ppu_update:
; ppu_update: waits until next NMI, turns rendering on (if not already),
; uploads OAM, palette, and nametable update to PPU
;-------------------------------------------------------
PPU_Update
        LDA #1
        STA NMI_READY
        :
          LDA NMI_READY
          BNE :-
        RTS

;-------------------------------------------------------
; ppu_off: waits until next NMI, turns rendering off (now safe to write PPU
; directly via $2007)
;-------------------------------------------------------
PPU_Off
        LDA #2
        STA NMI_READY
        :
          LDA NMI_READY
          BNE :-
        RTS

.segment "SRAM"
screenBufferLoPtrArray
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00
screenBufferHiPtrArray
        .BYTE $00,$00,$00,$00,$00,$00,$BF,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00
screenBuffer      .RES 960

.segment "CODE"
;-------------------------------------------------------
; InitializeProgram
;-------------------------------------------------------
InitializeProgram
        ; Set border and background to black
        LDA #$00
        STA shouldDrawCursor

        ; Create a Hi/Lo pointer to $2000
        LDA #>COLOR_RAM
        STA colorRamHiPtr
        LDA #<COLOR_RAM
        STA colorRamLoPtr

        ; Populate a table of hi/lo ptrs to the color RAM
        ; of each line on the screen (e.g. $2000,
        ; $02020). Each entry represents a single
        ; line 32 bytes long and there are 30 lines.
        ; The last line is reserved for configuration messages.
        LDX #$00
@Loop   LDA colorRamHiPtr
        STA colorRAMLineTableHiPtrArray,X
        LDA colorRamLoPtr
        STA colorRAMLineTableLoPtrArray,X
        CLC 
        ADC #$20
        STA colorRamLoPtr
        LDA colorRamHiPtr
        ADC #$00
        STA colorRamHiPtr
        INX 
        CPX #$1E
        BNE @Loop

        ; Create a Hi/Lo pointer to  the screen buffer.
        LDA #>screenBuffer
        STA screenBufferHiPtr
        LDA #<screenBuffer
        STA screenBufferLoPtr

        LDX #$00
@Loop2  LDA screenBufferHiPtr
        STA screenBufferHiPtrArray,X
        LDA screenBufferLoPtr
        STA screenBufferLoPtrArray,X
        CLC 
        ADC #$20
        STA screenBufferLoPtr
        LDA screenBufferHiPtr
        ADC #$00
        STA screenBufferHiPtr
        INX 
        CPX #$1E
        BNE @Loop2

        ; JSR InitializeDynamicStorage
        JMP LaunchPsychedelia

.segment "RAM"
colorRAMLineTableLoPtrArray
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00
colorRAMLineTableHiPtrArray
        .BYTE $00,$00,$00,$00,$00,$00,$BF,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00

.segment "ZEROPAGE"
currentPixel .res 1

.segment "CODE"
;-------------------------------------------------------
; InitializeScreenWithInitCharacter
;-------------------------------------------------------
InitializeScreenWithInitCharacter 
        ; Enabling this routine results in stray cursors
        ; being left around.
        RTS

        JSR PPU_Off

        ; first nametable, start by clearing to empty
        lda $2002 ; reset latch
        lda #$20
        sta $2006
        lda #$00
        sta $2006
        ; empty nametable
        lda #0
        ldy #30 ; 30 rows
        :
          ldx #32 ; 32 columns
          :
            sta $2007
            dex
            bne :-
          dey
          bne :--

        RTS 

.segment "RODATA"
presetKeyCodes
        .BYTE KEY_LEFT,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7
        .BYTE KEY_8,KEY_9,KEY_0,KEY_PLUS,KEY_MINUS,KEY_POUND
        .BYTE KEY_CLR_HOME,KEY_INST_DEL


.segment "CODE"
;-------------------------------------------------------
; LoadXAndYPosition
;-------------------------------------------------------
LoadXAndYPosition   
        LDX pixelYPosition

        LDA colorRAMLineTableLoPtrArray,X
        STA currentLineInColorRamLoPtr2
        LDA colorRAMLineTableHiPtrArray,X
        STA currentLineInColorRamHiPtr2

        LDA screenBufferLoPtrArray,X
        STA screenBufferLoPtr
        LDA screenBufferHiPtrArray,X
        STA screenBufferHiPtr

        LDY pixelXPosition
ReturnEarlyFromRoutine   
        RTS 

tempIndex = $FD
;-------------------------------------------------------
; PaintPixel
;-------------------------------------------------------
PaintPixel   
        ; Return early if the index or offset are invalid
        LDA pixelXPosition
        AND #$80
        BNE ReturnEarlyFromRoutine
        LDA pixelXPosition
        CMP #32
        BPL ReturnEarlyFromRoutine
        LDA pixelYPosition
        AND #$80
        BNE ReturnEarlyFromRoutine
        LDA pixelYPosition
        CMP #30
        BPL ReturnEarlyFromRoutine

        JSR LoadXAndYPosition
        LDA skipPixel
        BNE ActuallyPaintPixel

        LDA (screenBufferLoPtr),Y
        AND #$0F

        LDX #$00
GetIndexInPresetsLoop   
        CMP presetColorValuesArray,X
        BEQ FoundMatchingIndex
        INX 
        CPX #$08
        BNE GetIndexInPresetsLoop

FoundMatchingIndex   
        TXA 
        STA tempIndex
        LDX baseLevelForCurrentPixel
        INX 
        CPX tempIndex
        BEQ ActuallyPaintPixel
        BPL ActuallyPaintPixel
        RTS 

        ; Actually paint the pixel to color ram.
ActuallyPaintPixel   
        ;LDX baseLevelForCurrentPixel
        ;LDA presetColorValuesArray,X
        ;STA (currentLineInColorRamLoPtr2),Y
        JSR AddPixelToNMTUpdate
        RTS 

;-------------------------------------------------------
; SetPaletteForPixelPosition
;-------------------------------------------------------
SetPaletteForPixelPosition
        LDA currentColorToPaint
        TAY

        LDA paletteArrayLoPtr,Y
        STA paletteLoPtr
        LDA paletteArrayHiPtr,Y
        STA paletteHiPtr
        RTS

SetColorForPixelPosition
        LDA currentColorToPaint
        BNE:+
          RTS
        :
        LDA pixelXPosition
        AND #$05
        RTS

;-------------------------------------------------------
; AddPixelToNMTUpdate
;-------------------------------------------------------
AddPixelToNMTUpdate
        ; Write to the screen buffer.
        LDY baseLevelForCurrentPixel
        LDA presetColorValuesArray,Y
        STA currentColorToPaint

        ; Don't update a pixel if we're not changing its
        ; color.
        LDY pixelXPosition
        LDA (screenBufferLoPtr),Y
        CMP currentColorToPaint
        BNE:+
          RTS
        :
        LDA currentColorToPaint
        STA (screenBufferLoPtr),Y

        ; Write to the actual screen (the PPU).
        LDX NMT_UPDATE_LEN

        LDA currentLineInColorRamHiPtr2
        STA NMT_UPDATE, X
        INX

        LDA currentLineInColorRamLoPtr2
        CLC
        ADC pixelXPosition
        STA NMT_UPDATE, X
        INX

        LDA currentColorToPaint
        STA NMT_UPDATE, X
        INX

        STX NMT_UPDATE_LEN

        ; If we've got a few to write, let them do that now.
        CPX #$70
        BMI @UpdateComplete
        JSR SetPaletteForPixelPosition
        JSR PPU_Update

@UpdateComplete
        RTS

        
;-------------------------------------------------------
; LoopThroughPixelsAndPaint
;-------------------------------------------------------
LoopThroughPixelsAndPaint   
        JSR PaintPixelForCurrentSymmetry
        LDY #$00
        LDA baseLevelForCurrentPixel
        CMP #$07
        BNE CanLoopAndPaint
        RTS 

CanLoopAndPaint   
        LDA #$07
        STA countToMatchCurrentIndex

        LDA pixelXPosition
        STA previousCursorXPositionZP
        LDA pixelYPosition
        STA previousPixelYPositionZP

        LDX patternIndex
        LDA pixelXPositionLoPtrArray,X
        STA xPosLoPtr
        LDA pixelXPositionHiPtrArray,X
        STA xPosHiPtr
        LDA pixelYPositionLoPtrArray,X
        STA yPosLoPtr
        LDA pixelYPositionHiPtrArray,X
        STA yPosHiPtr

        ; Paint pixels in the sequence until hitting a break
        ; at $55
PixelPaintLoop   
        LDA previousCursorXPositionZP
        CLC 
        ADC (xPosLoPtr),Y
        STA pixelXPosition
        LDA previousPixelYPositionZP
        CLC 
        ADC (yPosLoPtr),Y
        STA pixelYPosition

        ; Push Y to the stack.
        TYA 
        PHA 

        JSR PaintPixelForCurrentSymmetry

        ; Pull Y back from the stack and increment
        PLA 
        TAY 
        INY 

        LDA (xPosLoPtr),Y
        CMP #$55
        BNE PixelPaintLoop

        DEC countToMatchCurrentIndex
        LDA countToMatchCurrentIndex
        CMP baseLevelForCurrentPixel
        BEQ RestorePositionsAndReturn
        CMP #$01
        BEQ RestorePositionsAndReturn
        INY 
        JMP PixelPaintLoop

RestorePositionsAndReturn   
        LDA previousCursorXPositionZP
        STA pixelXPosition
        LDA previousPixelYPositionZP
        STA pixelYPosition
        RTS 

; The pattern data structure consists of up to 7 rows, each
; one defining a stage in the creation of the pattern. Each
; row is assigned a unique color. The X and Y positions given
; in each array refer to the position relative to the cursor
; at the centre. 'Minus' values relative to the cursor are
; given by values such as FF (-1), FE (-2), and so on.
;
; In this illustration the number used represents which row
; the 'pixel' comes from. So for example the first row
; in starOneXPosArray and starOneYPosArray 
; draws the square of 0s at the centre of the star.
;

.segment "RODATA"
starOneXPosArray  .BYTE $00,$01,$01,$01,$00,$FF,$FF,$FF,$55       ;        5       
                  .BYTE $00,$02,$00,$FE,$55                       ;                
                  .BYTE $00,$03,$00,$FD,$55                       ;       4 4      
                  .BYTE $00,$04,$00,$FC,$55                       ;        3       
                  .BYTE $FF,$01,$05,$05,$01,$FF,$FB,$FB,$55       ;        2       
                  .BYTE $00,$07,$00,$F9,$55                       ;        1       
                  .BYTE $55                                       ;   4   000   4  
starOneYPosArray  .BYTE $FF,$FF,$00,$01,$01,$01,$00,$FF,$55       ; 5  3210 0123  5
                  .BYTE $FE,$00,$02,$00,$55                       ;   4   000   4  
                  .BYTE $FD,$00,$03,$00,$55                       ;        1       
                  .BYTE $FC,$00,$04,$00,$55                       ;        2       
                  .BYTE $FB,$FB,$FF,$01,$05,$05,$01,$FF,$55       ;        3       
                  .BYTE $F9,$00,$07,$00,$55                       ;       4 4      
                  .BYTE $55                                       ;                
                                                                  ;        5       

.segment "DATA"
countToMatchCurrentIndex   .BYTE $00
randomByteAddress  .BYTE $AB,$D0

.segment "CODE"
;-------------------------------------------------------
; PutRandomByteInAccumulator
;-------------------------------------------------------
PutRandomByteInAccumulator   
        LDA randomByteAddress
        ORA #$07
        INC randomByteAddress
        RTS 

        .BYTE $00,$00

;-------------------------------------------------------
; PaintPixelForCurrentSymmetry
;-------------------------------------------------------
PaintPixelForCurrentSymmetry   
        ; First paint the normal pattern without any
        ; symmetry.
        LDA pixelXPosition
        PHA 
        LDA pixelYPosition
        PHA 
        JSR PaintPixel

        LDA currentSymmetrySettingForStep
        BNE HasSymmetry

CleanUpAndReturnFromSymmetry   
        PLA 
        STA pixelYPosition
        PLA 
        STA pixelXPosition
        RTS 

HasSymmetry   
        CMP #X_AXIS_SYMMETRY
        BEQ XAxisSymmetry

        ; Has a pattern to paint on the Y axis
        ; symmetry so prepare for that.
        LDA #31
        SEC 
        SBC pixelXPosition
        STA pixelXPosition

        ; If it has X_Y_SYMMETRY then we just 
        ; need to paint that, and we're done.
        LDY currentSymmetrySettingForStep
        CPY #X_Y_SYMMETRY
        BEQ XYSymmetry

        ; If we're here it's either Y_AXIS_SYMMETRY
        ; or QUAD_SYMMETRY so we can paint a pattern
        ; on the Y axis.
        JSR PaintPixel

        ; If it's Y_AXIS_SYMMETRY we're done and can 
        ; return.
        LDA currentSymmetrySettingForStep
        CMP #Y_AXIS_SYMMETRY
        BEQ CleanUpAndReturnFromSymmetry

        ; Has QUAD_SYMMETRY so the remaining steps are
        ; to paint two more: one on our X axis and one
        ; on our Y axis.

        ; First we do the Y axis.
        LDA #29
        SEC 
        SBC pixelYPosition
        STA pixelYPosition
        JSR PaintPixel

        ; Paint one on the X axis.
PaintXAxisPixelForSymmetry    
        PLA 
        TAY 
        PLA 
        STA pixelXPosition
        TYA 
        PHA 
        JSR PaintPixel
        PLA 
        STA pixelYPosition
        RTS 

XAxisSymmetry   
        LDA #29
        SEC 
        SBC pixelYPosition
        STA pixelYPosition
        JMP PaintXAxisPixelForSymmetry

XYSymmetry   
        LDA #29
        SEC 
        SBC pixelYPosition
        STA pixelYPosition
        JSR PaintPixel
        PLA 
        STA pixelYPosition
        PLA 
        STA pixelXPosition
        RTS 

.segment "RAM"
pixelXPositionArray
        .BYTE $00,$00,$FF,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$FF,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
pixelYPositionArray
        .BYTE $00,$00,$FD,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
baseLevelArray
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
initialFramesRemainingToNextPaintForStep
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
framesRemainingToNextPaintForStep
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
patternIndexArray
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
symmetrySettingForStepCount
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

.segment "CODE"
;-------------------------------------------------------
; ReinitializeSequences
;-------------------------------------------------------
ReinitializeSequences
        LDX #$00
        TXA 
@Loop   
        STA pixelXPositionArray,X
        STA pixelYPositionArray,X
        LDA #$FF
        STA baseLevelArray,X
        LDA #$00
        STA initialFramesRemainingToNextPaintForStep,X
        STA framesRemainingToNextPaintForStep,X
        STA patternIndexArray,X
        STA symmetrySettingForStepCount,X
        INX 
        CPX #$40
        BNE @Loop

        STA currentPatternElement
        STA timerBetweenKeyStrokes
        STA shouldDrawCursor
        STA skipPixel
        LDA #$01
        STA currentSymmetrySetting
        RTS 

;-------------------------------------------------------
; LaunchPsychedelia
;-------------------------------------------------------
LaunchPsychedelia    
        JSR SetUpInterruptHandlers

;        LDX #$10
;@Loop   TXA 
;        STA SetUpInterruptHandlers,X
;        DEX 
;        BNE @Loop

        JSR ReinitializeScreen
        JSR ReinitializeSequences
        ;JSR ClearLastLineOfScreen
        ; Falls through

;-------------------------------------------------------
; MainPaintLoop
;-------------------------------------------------------
MainPaintLoop    
        INC currentIndexToPixelBuffers

;        LDA lastKeyPressed
;        CMP #$02 ; Left/Right cursor key
;        BNE HandleAnyCurrentModes

        ; Left/Right cursor key pauses the paint animation.
        ; This section just loops around if the left/right keys
        ; are pressed and keeps looping until they're pressed again.
;@Loop   LDA lastKeyPressed
;        CMP #$40 ;  No key pressed
;        BNE @Loop
;
;@Loop2  LDA lastKeyPressed
;        CMP #$02 ; Left/Right cursor key
;        BNE @Loop2
;
;        ; Keep looping until key pressed again.
;@Loop3  LDA lastKeyPressed
;        CMP #$40 ;No key pressed
;        BNE @Loop3

        ; Check if we can just do a normal paint or if
        ; we have to handle a customer preset mode or
        ; save/prompt mode. 

        JSR CheckPlayerInput

HandleAnyCurrentModes   
        LDA currentModeActive
        BEQ DoANormalPaint

        ; Handle if we're in a specific mode.
        CMP #$17 ; Custom Preset active?
        BNE MaybeInSavePromptMode
        ; Custom Preset active.
        JMP HandleCustomPreset

MaybeInSavePromptMode   
        CMP #$18 ; Current Mode is 'Save/Prompt'
        BNE InitializeScreenAndPaint
        JMP DisplaySavePromptScreen

        ; The main paint work.
InitializeScreenAndPaint   
        JSR ReinitializeScreen

        ; currentIndexToPixelBuffers is our index into the 
        ; pixel buffers. It gets incremented every
        ; pass through MainPaintLoop until it reaches
        ; the value set by bufferLength. So it determines
        ; how much of each pixel buffer we paint.
DoANormalPaint   
        LDA currentIndexToPixelBuffers
        CMP bufferLength
        BNE CheckCurrentBuffer

        ; Reset the index back to the start of the pixel buffers.
        LDA #$00
        STA currentIndexToPixelBuffers
CheckCurrentBuffer   
        LDX currentIndexToPixelBuffers
        LDA baseLevelArray,X
        CMP #$FF
        BNE ShouldDoAPaint

        STX shouldDrawCursor
        JMP MainPaintLoop

ShouldDoAPaint   
        STA baseLevelForCurrentPixel
        DEC framesRemainingToNextPaintForStep,X
        BNE GoBackToStartOfLoop

        ; Actually paint some pixels to the screen.

        ; Reset the delay for this step.
        LDA initialFramesRemainingToNextPaintForStep,X
        STA framesRemainingToNextPaintForStep,X

        ; Get the x and y positions for this pixel.
        LDA pixelXPositionArray,X
        STA pixelXPosition
        LDA pixelYPositionArray,X
        STA pixelYPosition

        LDA patternIndexArray,X
        STA patternIndex

        LDA symmetrySettingForStepCount,X
        STA currentSymmetrySettingForStep

        ; Line Mode sets the top bit of baseLevelForCurrentPixel
        LDA baseLevelForCurrentPixel
        AND #$80
        BNE PaintLineModeAndLoop

        TXA 
        PHA 
        JSR LoopThroughPixelsAndPaint
        PLA 
        TAX 

        DEC baseLevelArray,X
GoBackToStartOfLoop   
        JMP MainPaintLoop

.segment "RAM"
currentIndexToPixelBuffers   .BYTE $00

.segment "CODE"
PaintLineModeAndLoop
        ; Loops back to MainPaintLoop
        JMP PaintLineMode

;-------------------------------------------------------
; SetUpInterruptHandlers
;-------------------------------------------------------
SetUpInterruptHandlers
;        SEI
;        LDA #<IRQInterruptHandler
;        STA $0314    ;IRQ
;        LDA #>IRQInterruptHandler
;        STA $0315    ;IRQ

        LDA #$0A
        STA cursorXPosition
        STA cursorYPosition

;        LDA #$01
;        STA $D015    ;Sprite display Enable
;        STA $D027    ;Sprite 0 Color
;        LDA #<NMIInterruptHandler
;        STA $0318    ;NMI
;        LDA #>NMIInterruptHandler
;        STA $0319    ;NMI
;        CLI 
        RTS 

.segment "DATA"
countStepsBeforeCheckingJoystickInput   .BYTE $02,$00

.segment "CODE"
;-------------------------------------------------------
; IRQInterruptHandler
;-------------------------------------------------------
IRQInterruptHandler

        BIT $4015 ; Clear IRQ

        ; SAVE REGISTERS
        PHA
        TXA
        PHA
        TYA
        PHA

        ; The sequencer is played by the interrupt handler.
        ; Check if it's active.
        LDA stepsRemainingInSequencerSequence
        BEQ SequencerNotActiveCheckJoystickInput
        DEC stepsRemainingInSequencerSequence
        BNE SequencerNotActiveCheckJoystickInput

        ; If the sequencer is active we'll end up here and
        ; load the sequencer data so that it can be played.
        LDA sequencerSpeed
        STA stepsRemainingInSequencerSequence

CalledFromNMI
        JSR LoadDataForSequencer

SequencerNotActiveCheckJoystickInput   
        ; Our counter reaches zero every 256 interrupts,
        ; otherwise we just return early.
        DEC countStepsBeforeCheckingJoystickInput
        BEQ CanUpdatePixelBuffers

        ; No need to do anything so return early.
        JMP CheckKeyboardAndReturnFromInterrupt
        ;Returns?

        ; Once in every 256 interrupts, check the joystick
        ; for input and act on it.
CanUpdatePixelBuffers   

        LDA #$00
        LDA cursorSpeed
        STA countStepsBeforeCheckingJoystickInput


        LDA playerPressedFire
        AND #$01
        BNE PlayerHasPressedFire

        ; Player hasn't pressed fire.
        LDA #$00
        STA stepsSincePressedFire
        JMP CheckKeyboardAndReturnFromInterrupt
        ; Returns

        ; Player has pressed fire.
PlayerHasPressedFire   
        LDA #$00
        STA playerPressedFire
        LDA stepsExceeded255
        BEQ DecrementPulseWidthCounter
        LDA stepsSincePressedFire
        BEQ IncrementStepsSincePressedFire
        JMP CheckKeyboardAndReturnFromInterrupt

IncrementStepsSincePressedFire   
        INC stepsSincePressedFire
DecrementPulseWidthCounter   
        LDA currentPulseWidth
        BEQ DecrementPulseSpeedCounter
        DEC currentPulseWidth
        BEQ DecrementPulseSpeedCounter
        JMP UpdatePixelBuffersForPattern

DecrementPulseSpeedCounter   
        DEC currentPulseSpeedCounter
        BEQ RefreshPulseSpeed
        JMP CheckKeyboardAndReturnFromInterrupt

RefreshPulseSpeed   
        LDA pulseSpeed
        STA currentPulseSpeedCounter
        LDA pulseWidth
        STA currentPulseWidth

        ; Finally, update the pixel buffers with a byte
        ; each for the current pattern.        
UpdatePixelBuffersForPattern    
        INC currentStepCount
        LDA currentStepCount
        CMP bufferLength
        BNE UpdateBaseLevelArray

        LDA #$00
        STA currentStepCount

UpdateBaseLevelArray   
        TAX 
        LDA baseLevelArray,X
        CMP #$FF
        BEQ UpdatePositionArrays
        LDA shouldDrawCursor
        AND trackingActivated
        BEQ CheckKeyboardAndReturnFromInterrupt
        TAX 
        LDA baseLevelArray,X
        CMP #$FF
        BNE CheckKeyboardAndReturnFromInterrupt

        STX currentStepCount
UpdatePositionArrays   
        LDA cursorXPosition
        STA pixelXPositionArray,X
        LDA cursorYPosition
        STA pixelYPositionArray,X

        LDA lineModeActivated
        BEQ LineModeNotActive

        ; Line Mode Active
        LDA #$19
        SEC 
        SBC cursorYPosition
        ORA #$80
        STA baseLevelArray,X
        JMP ApplySmoothingDelay

LineModeNotActive   
        LDA baseLevel
        STA baseLevelArray,X
        LDA currentPatternElement
        STA patternIndexArray,X

ApplySmoothingDelay    
        LDA smoothingDelay
        STA initialFramesRemainingToNextPaintForStep,X
        STA framesRemainingToNextPaintForStep,X
        LDA currentSymmetrySetting
        STA symmetrySettingForStepCount,X

CheckKeyboardAndReturnFromInterrupt    
        JSR CheckKeyboardInput

        ; RESTORE REGISTERS AND RETURN
        PLA
        TAY
        PLA
        TAX
        PLA
        RTI

;-------------------------------------------------------
; LoadXAndYOfCursorPosition
;-------------------------------------------------------
LoadXAndYOfCursorPosition   
        LDX cursorYPosition
        LDA colorRAMLineTableLoPtrArray,X
        STA currentLineInColorRamLoPtr
        LDA colorRAMLineTableHiPtrArray,X
        STA currentLineInColorRamHiPtr
        LDY cursorXPosition
ReturnEarlyFromCursorPaint   
        RTS 

;-------------------------------------------------------
; PaintCursorAtCurrentPosition
;-------------------------------------------------------
PaintCursorAtCurrentPosition   
        LDA displaySavePromptActive
        BNE ReturnEarlyFromCursorPaint
        JSR LoadXAndYOfCursorPosition
        ;LDA currentColorToPaint
        ;STA (currentLineInColorRamLoPtr),Y
        JSR AddCursorPixelToNMTUpdate
        JSR PPU_Update
        RTS 

;-------------------------------------------------------
; AddPixelToNMTUpdate
;-------------------------------------------------------
AddCursorPixelToNMTUpdate
        LDX NMT_UPDATE_LEN

        LDA currentLineInColorRamHiPtr
        STA NMT_UPDATE, X
        INX

        LDA currentLineInColorRamLoPtr
        CLC
        ADC cursorXPosition
        STA NMT_UPDATE, X
        INX

        LDA currentColorToPaint
        STA NMT_UPDATE, X
        INX

        STX NMT_UPDATE_LEN
        RTS

.segment "DATA"
cursorXPosition       .BYTE $0A
cursorYPosition       .BYTE $0A
currentStepCount      .BYTE $00
; FIXME: For some reason these need to be set here, but not on the C64.
stepsSincePressedFire .BYTE $00
stepsExceeded255      .BYTE $00

; This is where the presets get loaded to. It represents
; the data structure for the presets.
; currentVariableMode is an index into this data structure
; when the user adjusts settings.
presetValueArray
unusedPresetByte        .BYTE $00
smoothingDelay          .BYTE $0C
cursorSpeed             .BYTE $02
bufferLength            .BYTE $1F
pulseSpeed              .BYTE $01
indexForColorBarDisplay .BYTE $01
lineWidth               .BYTE $07
sequencerSpeed          .BYTE $04
pulseWidth              .BYTE $01
baseLevel               .BYTE $07
presetColorValuesArray  .BYTE BLACK,BLUE,RED,PURPLE,GREEN,CYAN,YELLOW,WHITE
trackingActivated       .BYTE $FF
lineModeActivated       .BYTE $00
patternIndex            .BYTE $05


.segment "RODATA"

; A pair of arrays together consituting a list of pointers
; to positions in memory containing X position data.
; (i.e. $097C, $0E93,$0EC3, $0F07, $0F23, $0F57, $1161, $11B1)
pixelXPositionLoPtrArray .BYTE <starOneXPosArray,<theTwistXPosArray,<laLlamitaXPosArray
                         .BYTE <starTwoXPosArray,<deltoidXPosArray,<diffusedXPosArray
                         .BYTE <multicrossXPosArray,<pulsarXPosArray

customPatternLoPtrArray  .BYTE <customPattern0XPosArray,<customPattern1XPosArray
                         .BYTE <customPattern2XPosArray,<customPattern3XPosArray
                         .BYTE <customPattern4XPosArray,<customPattern5XPosArray
                         .BYTE <customPattern6XPosArray,<customPattern7XPosArray

pixelXPositionHiPtrArray .BYTE >starOneXPosArray,>theTwistXPosArray,>laLlamitaXPosArray
                         .BYTE >starTwoXPosArray,>deltoidXPosArray,>diffusedXPosArray
                         .BYTE >multicrossXPosArray,>pulsarXPosArray

customPatternHiPtrArray  .BYTE >customPattern0XPosArray,>customPattern1XPosArray
                         .BYTE >customPattern2XPosArray,>customPattern3XPosArray
                         .BYTE >customPattern4XPosArray,>customPattern5XPosArray
                         .BYTE >customPattern6XPosArray,>customPattern7XPosArray

; A pair of arrays together consituting a list of pointers
; to positions in memory containing Y position data.
; (i.e. $097C, $0E93,$0EC3, $0F07, $0F23, $0F57, $1161, $11B1)
pixelYPositionLoPtrArray .BYTE <starOneYPosArray,<theTwistYPosArray,<laLlamitaYPosArray
                         .BYTE <starTwoYPosArray,<deltoidYPosArray,<diffusedYPosArray
                         .BYTE <multicrossYPosArray,<pulsarYPosArray
                         .BYTE <customPattern0YPosArray,<customPattern1YPosArray
                         .BYTE <customPattern2YPosArray,<customPattern3YPosArray
                         .BYTE <customPattern4YPosArray,<customPattern5YPosArray
                         .BYTE <customPattern6YPosArray,<customPattern7YPosArray

pixelYPositionHiPtrArray .BYTE >starOneYPosArray,>theTwistYPosArray,>laLlamitaYPosArray
                         .BYTE >starTwoYPosArray,>deltoidYPosArray,>diffusedYPosArray
                         .BYTE >multicrossYPosArray,>pulsarYPosArray
                         .BYTE >customPattern0YPosArray,>customPattern1YPosArray
                         .BYTE >customPattern2YPosArray,>customPattern3YPosArray
                         .BYTE >customPattern4YPosArray,>customPattern5YPosArray
                         .BYTE >customPattern6YPosArray,>customPattern7YPosArray

; The pattern data structure consists of up to 7 rows, each
; one defining a stage in the creation of the pattern. Each
; row is assigned a unique color. The X and Y positions given
; in each array refer to the position relative to the cursor
; at the centre. 'Minus' values relative to the cursor are
; given by values such as FF (-1), FE (-2), and so on.
; An illustration of the pattern each data structure creates
; is given before it.

theTwistXPosArray .BYTE $00,$55                            ;     1  
                  .BYTE $01,$02,$55                        ;   01   
                  .BYTE $01,$02,$03,$55                    ;  6 222 
                  .BYTE $01,$02,$03,$04,$55                ;  543   
                  .BYTE $00,$00,$00,$55                    ; 5 4 3  
                  .BYTE $FF,$FE,$55                        ;   4  3 
                  .BYTE $FF,$55                            ;       3
                  .BYTE $55
theTwistYPosArray .BYTE $FF,$55
                  .BYTE $FF,$FE,$55
                  .BYTE $00,$00,$00,$55
                  .BYTE $01,$02,$03,$04,$55
                  .BYTE $01,$02,$03,$55
                  .BYTE $01,$02,$55
                  .BYTE $00,$55
                  .BYTE $55

laLlamitaXPosArray  .BYTE $00,$FF,$00,$55                    ;  0       
                    .BYTE $00,$00,$55                        ; 06      
                    .BYTE $01,$02,$03,$00,$01,$02,$03,$55    ;  0      
                    .BYTE $04,$05,$06,$04,$00,$01,$02,$55    ;  1    3 
                    .BYTE $04,$00,$04,$00,$04,$55            ;  12223 3
                    .BYTE $FF,$03,$55                        ;  22223  
                    .BYTE $00,$55                            ;  333 4  
laLlamitaYPosArray  .BYTE $FF,$00,$01,$55                    ;  4   4  
                    .BYTE $02,$03,$55                        ; 54  54  
                    .BYTE $03,$03,$03,$04,$04,$04,$04,$55
                    .BYTE $03,$02,$03,$04,$05,$05,$05,$55
                    .BYTE $05,$06,$06,$07,$07,$55
                    .BYTE $07,$07,$55
                    .BYTE $00,$55

starTwoXPosArray  .BYTE $FF,$55                  ;    1  
                  .BYTE $00,$55                  ;   0  2
                  .BYTE $02,$55                  ;    6  
                  .BYTE $01,$55                  ; 4     
                  .BYTE $FD,$55                  ;     3 
                  .BYTE $FE,$55                  ;  5    
                  .BYTE $00,$55
starTwoYPosArray  .BYTE $FF,$55
                  .BYTE $FE,$55
                  .BYTE $FF,$55
                  .BYTE $02,$55
                  .BYTE $01,$55
                  .BYTE $FC,$55
                  .BYTE $00,$55

deltoidXPosArray  .BYTE $00,$01,$FF,$55           ;       5      
                  .BYTE $00,$55                   ;              
                  .BYTE $00,$01,$02,$FE,$FF,$55   ;       4      
                  .BYTE $00,$03,$FD,$55           ;       3      
                  .BYTE $00,$04,$FC,$55           ;       2      
                  .BYTE $00,$06,$FA,$55           ;      202     
                  .BYTE $00,$55                   ;     20602    
deltoidYPosArray  .BYTE $FF,$00,$00,$55           ;    3     3   
                  .BYTE $00,$55                   ;   4       4  
                  .BYTE $FE,$FF,$00,$00,$FF,$55   ;              
                  .BYTE $FD,$01,$01,$55           ; 5           5
                  .BYTE $FC,$02,$02,$55
                  .BYTE $FA,$04,$04,$55
                  .BYTE $00,$55

diffusedXPosArray .BYTE $FF,$01,$55                  ; 5            
                  .BYTE $FE,$02,$55                  ;            4 
                  .BYTE $FD,$03,$55                  ;   3          
                  .BYTE $FC,$04,$FC,$FC,$04,$04,$55  ;          2   
                  .BYTE $FB,$05,$55                  ; 5   1       5
                  .BYTE $FA,$06,$FA,$FA,$06,$06,$55  ;   3    0  3  
                  .BYTE $00,$55                      ;       6      
diffusedYPosArray .BYTE $01,$FF,$55                  ;   3  0    3  
                  .BYTE $FE,$02,$55                  ; 5       1   5
                  .BYTE $03,$FD,$55                  ;    2         
                  .BYTE $FC,$04,$FF,$01,$FF,$01,$55  ;           3  
                  .BYTE $05,$FB,$55                  ;  4           
                  .BYTE $FA,$06,$FE,$02,$FE,$02,$55  ;             5
                  .BYTE $00,$55


.segment "CODE"
;-------------------------------------------------------
; CheckKeyboardInput
;-------------------------------------------------------
CheckKeyboardInput   
        ; FIXME: Let's return early for now.
        RTS

        LDA currentVariableMode
        BEQ CheckForGeneralKeystrokes
        JMP CheckKeyboardInputForActiveVariable

        ; Allow a bit of time to elapse between detected key strokes.
CheckForGeneralKeystrokes   
        LDA timerBetweenKeyStrokes
        BEQ CheckForKeyStroke
        DEC timerBetweenKeyStrokes
        BNE ReturnFromKeyboardCheck

CheckForKeyStroke   
        LDA lastKeyPressed
        CMP #$40
        BNE ProcessKeyStroke

        ; No key was pressed. Return early.
        LDA #$00
        STA timerBetweenKeyStrokes
        JSR DisplayDemoModeMessage
ReturnFromKeyboardCheck   
        RTS 

        ; A key was pressed. Figure out which one.
ProcessKeyStroke   
        LDY initialTimeBetweenKeyStrokes
        STY timerBetweenKeyStrokes
        LDY shiftKey
        STY shiftPressed

        CMP #KEY_SPACE ; Space pressed?
        BNE MaybeSPressed

        ; Space pressed. Selects a new pattern element. " There are eight permanent ones,
        ; and eight you can define for yourself (more on this later!). The latter eight
        ; are all set up when you load, so you can always choose from 16 shapes."
        INC currentPatternElement
        LDA currentPatternElement
        AND #$0F
        STA currentPatternElement
        AND #$08
        BEQ UpdateCurrentPattern
        ; The first 8 patterns are standard, the rest are custom.
        JMP GetCustomPatternElement

UpdateCurrentPattern   
        JSR ClearLastLineOfScreen
        LDA currentPatternElement
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 

        LDX #$00
txtPresetLoop   
        LDA txtPresetPatternNames,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE txtPresetLoop
        JMP WriteLastLineBufferToScreen
        ; Returns

MaybeSPressed   
        CMP #KEY_S ; 'S' pressed.
        BNE MaybeLPressed

        ; Check if shift was pressed too.
        LDA shiftPressed
        AND #$01
        BEQ JustSPressed

        LDA tapeSavingInProgress
        BNE JustSPressed
        ; Shift + S pressed: Save.
        JMP PromptToSave
        ; Returns

        ; 'S' pressed. "This changes the 'symmetry'. The pattern gets reflected
        ; in various planes, or not at all according to the setting."
        ; Briefly display the new symmetry setting on the bottom of the screen.
JustSPressed   
        INC currentSymmetrySetting
        LDA currentSymmetrySetting
        CMP #$05
        BNE b1005
        LDA #$00
        STA currentSymmetrySetting
b1005   ASL 
        ASL 
        ASL 
        ASL 
        TAY 
        JSR ClearLastLineOfScreen

        ; currentSymmetrySetting is in Y
        LDX #$00
txtSymmLoop   
        LDA txtSymmetrySettingDescriptions,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE txtSymmLoop

        JMP WriteLastLineBufferToScreen
        ;Returns

MaybeLPressed   
        CMP #KEY_L ; 'L' pressed?
        BNE MaybeDPressed

        ; Don't do anything if already saving to tape.
        LDA tapeSavingInProgress
        BNE JustLPressed

        ; Check if shift was pressed too.
        LDA shiftPressed
        AND #$01
        BEQ JustLPressed

        ; Shift + L pressed. Display load message
        JMP DisplayLoadOrAbort
        ; Returns

        ; 'L' pressed. Turn line mode on or off.
JustLPressed   
        LDA lineModeActivated
        EOR #$01
        STA lineModeActivated
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 

        ; Briefly display the new linemode setting on the bottom of the screen.
        JSR ClearLastLineOfScreen
        LDX #$00
@Loop   LDA lineModeSettingDescriptions,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE @Loop
        JMP WriteLastLineBufferToScreen
        ; Returns

MaybeDPressed   
        CMP #KEY_D ; 'D' pressed?
        BNE MaybeCPressed

        ; Smoothing Delay, D to activate: Because of the time taken to draw
        ; larger patterns speed increase/decrease is not linear. You can adjust
        ; the ‘compensating delay’ which often smooths out jerky patterns. Can
        ; be used just for special FX, though. Suck it and see.
        LDA #SMOOTHING_DELAY
        STA currentVariableMode
        RTS 

MaybeCPressed   
        CMP #KEY_C ; C pressed?
        BNE MaybeBPressed
        ; C pressed.
        ; Cursor Speed C to activate: Just that. Gives you a slow r fast little
        ; cursor, according to setting.

        LDA #CURSOR_SPEED
        STA currentVariableMode
        RTS 

MaybeBPressed   
        CMP #KEY_B ; B pressed?
        BNE MaybePPressed

        ; B pressed.
        ; Buffer Length B to activate: Larger patterns flow more smoothly with a
        ; shorter Buffer Length - not so many positions are retained so less
        ; plotting to do. Small patterns with a long Buffer Length are good for
        ; ‘steamer’ effects. N.B. Cannot be adjusted whilst patterns are
        ; actually onscreen.
        LDA #BUFFER_LENGTH
        STA currentVariableMode
        RTS 

MaybePPressed   
        CMP #KEY_P ; P pressed
        BNE MaybeHPressed

        ; P pressed.
        ; Pulse Speed P to activate: Usually if you hold down the button you
        ; get a continuous stream. Setting the Pulse Speed allows you to
        ; generate a pulsed stream, as if you were rapidly pressing and
        ; releasing the FIRE button.
        LDA #PULSE_SPEED
        STA currentVariableMode
        RTS 

MaybeHPressed   
        CMP #KEY_H ; H pressed.
        BNE MaybeTPressed

        ; H pressed. Select a change to the pattern colors.
        ; COLOUR CHANGE H to activate: Allows you to set the colour for each of
        ; the seven pattern steps. Set up the colour you want, press RETURN,
        ; and the command offers the next colour along, up to no. 7, then ends.
        ; Cannot be adjusted while patterns being generated.
        LDA #$01
        STA currentColorSet
        LDA #COLOR_CHANGE
        STA currentVariableMode
        RTS 

MaybeTPressed   
        CMP #KEY_T ; T pressed.
        BNE CheckIfPresetKeysPressed

        ;"T: Controls whether logic-seeking is used in the buffer or not. The upshot of 
        ; this for you is a slightly different feel - continuous but fragmented when ON,
        ; or together-ish bursts when OFF. "
        LDA trackingActivated
        EOR #$FF
        STA trackingActivated
        AND #$01
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 
        JSR ClearLastLineOfScreen

        LDX #$00
txtTrackingLoop   
        LDA txtTrackingOnOff,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE txtTrackingLoop

        JMP WriteLastLineBufferToScreen
        RTS 

        ; Check if one of the presets has been selected.
CheckIfPresetKeysPressed   
        LDX #$00
presetKeyLoop   
        CMP presetKeyCodes,X
        BEQ UpdateDisplayedPreset
        INX 
        CPX #$10
        BNE presetKeyLoop

        JMP MaybeWPressed

UpdateDisplayedPreset   
        JMP DisplayPresetMessage

MaybeWPressed    
        CMP #KEY_W ; W pressed?
        BNE MaybeFunctionKeysPressed

        ; W pressed
        ; Line Width W to activate: Sets the width of the lines produced in
        ; Line Mode.
        LDA #LINE_WIDTH
        STA currentVariableMode
        RTS 

        ; Was one of the function keys pressed?
MaybeFunctionKeysPressed   
        LDX #$00
FnKeyLoop   
        CMP functionKeys,X
        BEQ FunctionKeyWasPressed ; One of them was pressed!
        INX 
        CPX #$04
        BNE FnKeyLoop
        ; Continue checking
        JMP MaybeQPressed

        ; A Function key was pressed, only valid if the sequencer is active.
FunctionKeyWasPressed   
        STX functionKeyIndex
        LDA sequencerActive
        BNE MaybeQPressed
        LDA #SEQUENCER_ACTIVE
        STA currentVariableMode
        JSR UpdateBurstGenerator
        RTS 

MaybeQPressed    
        CMP #KEY_Q ; Q pressed?
        BNE MaybeVPressed

        ; Q was presed. Toggle the sequencer on or off.
        LDA sequencerActive
        BNE TurnSequenceOff
        LDA #SEQUENCER_ACTIVE
        STA currentVariableMode
        JMP ActivateSequencer
        ;Returns

        ;Turn the sequencer off.
TurnSequenceOff   
        LDA #$00
        STA sequencerActive
        STA stepsRemainingInSequencerSequence
        JMP DisplaySequencerState

MaybeVPressed   
        CMP #KEY_V ; V pressed?
        BNE MaybeOPressed

        ; V pressed.
        ; Sequencer Speed V to activate: Controls the rate at which sequencer
        ; feeds in its data. See the SEQUENCER bit.
        LDA #SEQUENCER_SPEED
        STA currentVariableMode
        RTS 

MaybeOPressed   
        CMP #KEY_O ; O pressed.
        BNE MaybeAsteriskPressed

        ; O pressed.
        ; Pulse Width : Sets the length of the pulses in a pulsed
        ; stream output. Don’t worry about what that means - just get in there
        ; and mess with it.
        LDA #PULSE_WIDTH
        STA currentVariableMode
        RTS 

MaybeAsteriskPressed   
        CMP #KEY_ASTERISK ; * pressed?
        BNE MaybeRPressed

        ; * pressed.
        ; BASE LEVEL : Controls how many ‘levels’ of pattern are
        ; plotted.
        LDA #BASE_LEVEL
        STA currentVariableMode
        RTS 

MaybeRPressed   
        CMP #KEY_R ; R pressed?
        BNE MaybeUpArrowPressed
        ; R was pressed. Stop or start recording.
        JMP StopOrStartRecording

MaybeUpArrowPressed   
        CMP #KEY_UP ; Up arrow
        BNE MaybeAPressed
        ; Up arrow pressed. "Press UP-ARROW to change the shape of the little pixels on the screen."
        INC pixelShapeIndex
        LDA pixelShapeIndex
        AND #$0F
        TAY 
        LDA pixelShapeArray,Y

        ; Rewrite the screen using the new pixel.
;        LDX #$00
;@Loop   STA SCREEN_RAM + $0000,X
;        STA SCREEN_RAM + $0100,X
;        STA SCREEN_RAM + $0200,X
;        STA SCREEN_RAM + $02C0,X
;        DEX 
;        BNE @Loop
;        STA currentPixel
        RTS 

MaybeAPressed   
        CMP #KEY_A ; 'A' pressed
        BNE FinalReturnFromKeyboardCheck

        ; Activate demo mode.
        LDA demoModeActive
        EOR #$01
        STA demoModeActive
        RTS 

FinalReturnFromKeyboardCheck   
        RTS 


.segment "DATA"
initialTimeBetweenKeyStrokes   .BYTE $10

.segment "RODATA"
multicrossXPosArray .BYTE $01,$01,$FF,$FF,$55                    ;
                    .BYTE $02,$02,$FE,$FE,$55                    ;   5     5  
                    .BYTE $01,$03,$03,$01,$FF,$FD,$FD,$FF,$55    ;  4       4 
                    .BYTE $03,$03,$FD,$FD,$55                    ; 5 3 2 2 3 5
                    .BYTE $04,$04,$FC,$FC,$55                    ;    1   1   
                    .BYTE $03,$05,$05,$03,$FD,$FB,$FB,$FD,$55    ;   2 0 0 2  
                    .BYTE $00,$55                                ;      6     
multicrossYPosArray .BYTE $FF,$01,$01,$FF,$55                    ;   2 0 0 2  
                    .BYTE $FE,$02,$02,$FE,$55                    ;    1   1   
                    .BYTE $FD,$FF,$01,$03,$03,$01,$FF,$FD,$55    ; 5 3 2 2 3 5
                    .BYTE $FD,$03,$03,$FD,$55                    ;  4       4 
                    .BYTE $FC,$04,$04,$FC,$55                    ;   5     5  
                    .BYTE $FB,$FD,$03,$05,$05,$03,$FD,$FB,$55    ;
                    .BYTE $00,$55


pulsarXPosArray .BYTE $00,$01,$00,$FF,$55       ;
                .BYTE $00,$02,$00,$FE,$55       ;       5      
                .BYTE $00,$03,$00,$FD,$55       ;       4      
                .BYTE $00,$04,$00,$FC,$55       ;       3      
                .BYTE $00,$05,$00,$FB,$55       ;       2      
                .BYTE $00,$06,$00,$FA,$55       ;       1      
                .BYTE $00,$55                   ;       0      
pulsarYPosArray .BYTE $FF,$00,$01,$00,$55       ; 5432106012345
                .BYTE $FE,$00,$02,$00,$55       ;       0      
                .BYTE $FD,$00,$03,$00,$55       ;       1      
                .BYTE $FC,$00,$04,$00,$55       ;       2      
                .BYTE $FB,$00,$05,$00,$55       ;       3      
                .BYTE $FA,$00,$06,$00,$55       ;       4      
                .BYTE $00,$55                   ;       5      

.segment "DATA"
lastLineBufferPtr               .BYTE $FF,$FF,$FF,$FF,$FF,$FF
dataFreeDigitOne                .BYTE $FF
dataFreeDigitTwo                .BYTE $FF
dataFreeDigitThree              .BYTE $FF,$FF,$FF,$FF,$FF
customPatternValueBufferPtr     .BYTE $FF,$FF,$FF
customPatternValueBufferMessage .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
                                .BYTE $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
                                .BYTE $00,$00,$00,$00,$00,$00,$00,$00


.segment "CODE"
;-------------------------------------------------------
; ClearLastLineOfScreen
;-------------------------------------------------------
ClearLastLineOfScreen   
        
        LDX #$20
b121B   LDA #$20
        STA lastLineBufferPtr - $01,X
        STA SCREEN_RAM + $03BF,X
        DEX 
        BNE b121B
        RTS 

;-------------------------------------------------------
; WriteLastLineBufferToScreen
;-------------------------------------------------------
WriteLastLineBufferToScreen    
        LDX #$20
b1229   LDA lastLineBufferPtr - $01,X
        AND #$3F
        STA SCREEN_RAM + $03BF,X
        DEX 
        BNE b1229
        RTS 


.segment "RODATA"
txtPresetPatternNames
        .BYTE "STAR ONE        "
        .BYTE "THE TWIST       "
        .BYTE "LA LLAMITA      "
        .BYTE "STAR TWO        "
        .BYTE "DELTOIDS        "
        .BYTE "DIFFUSED        "
        .BYTE "MULTICROSS      "
        .BYTE "PULSAR          "
txtSymmetrySettingDescriptions 
        .BYTE "NO SYMMETRY     "
        .BYTE "Y-AXIS SYMMETRY "
        .BYTE "X-Y SYMMETRY    "
        .BYTE "X-AXIS SYMMETRY "
        .BYTE "QUAD SYMMETRY   "

.segment "CODE"
;-------------------------------------------------------
; PaintLineMode
;-------------------------------------------------------
PaintLineMode 
        LDA baseLevelForCurrentPixel
        AND #$7F
        STA offsetForYPos
        LDA #$19
        SEC 
        SBC offsetForYPos
        STA pixelYPosition
        DEC pixelYPosition
        LDA #$00
        STA baseLevelForCurrentPixel
        LDA #$01
        STA skipPixel
        JSR PaintPixelForCurrentSymmetry
        INC pixelYPosition
        LDA #$00
        STA skipPixel

        LDA lineWidth
        EOR #$07
        STA baseLevelForCurrentPixel
LineModeLoop   
        JSR PaintPixelForCurrentSymmetry
        INC pixelYPosition
        INC baseLevelForCurrentPixel
        LDA baseLevelForCurrentPixel
        CMP #$08
        BNE ResetLineModeColorValue
        JMP CleanUpAndExitLineModePaint

        INC baseLevelForCurrentPixel
ResetLineModeColorValue   
        STA baseLevelForCurrentPixel
        LDA pixelYPosition
        CMP #$19
        BNE LineModeLoop

CleanUpAndExitLineModePaint    
        LDX currentIndexToPixelBuffers
        DEC baseLevelArray,X
        LDA baseLevelArray,X
        CMP #$80
        BEQ ResetIndexAndExitLineModePaint
        JMP MainPaintLoop

ResetIndexAndExitLineModePaint   
        LDA #$FF
        STA baseLevelArray,X
        STX shouldDrawCursor
        JMP MainPaintLoop

.segment "RODATA"
lineModeSettingDescriptions
        .BYTE "LINE MODE",$BA," OFF  "
        .BYTE "LINE MODE",$BA," ON   "

.segment "CODE"
;-------------------------------------------------------
; DrawColorValueBar
;-------------------------------------------------------
DrawColorValueBar
        ; Shift the pointer from SCREEN_RAM ($0400) to COLOR_RAM ($D800)
        LDA colorBarColorRamHiPtr
        PHA 
        CLC 
        ADC #$D4
        STA colorBarColorRamHiPtr

        ; Draw the colors from the bar to color ram.
        LDY #$00
b138F   LDA colorBarValues,Y
        STA (colorBarColorRamLoPtr),Y
        INY 
        CPY #$10
        BNE b138F

        PLA 
        STA colorBarColorRamHiPtr
        LDA #$00
        STA currentNodeInColorBar
        STA currentCountInDrawingColorBar
        STA offsetToColorBar
        LDA maxToDrawOnColorBar
        BEQ b13D8

b13AC   LDA offsetToColorBar
        CLC 
        ADC currentColorBarOffset
        STA offsetToColorBar
        LDX offsetToColorBar
        LDY currentNodeInColorBar
        LDA nodeTypeArray,X
        STA (colorBarColorRamLoPtr),Y
        CPX #$08
        BNE b13CD
        LDA #$00
        STA offsetToColorBar
        INC currentNodeInColorBar
b13CD   INC currentCountInDrawingColorBar
        LDA currentCountInDrawingColorBar
        CMP maxToDrawOnColorBar
        BNE b13AC
b13D8   RTS 

.segment "DATA"
currentColorBarOffset         .BYTE $FF
currentNodeInColorBar         .BYTE $FF
maxToDrawOnColorBar           .BYTE $FF
currentCountInDrawingColorBar .BYTE $FF
offsetToColorBar              .BYTE $FF

.segment "RODATA"
; Different size of nodes for the color bar, graded from a full cell to an empty cell.
nodeTypeArray                 .BYTE $20,$65,$74,$75,$61,$F6,$EA,$E7
                              .BYTE $A0

.segment "CODE"
ResetSelectedVariableAndReturn
        LDA #$00
        STA currentVariableMode
        RTS 

;-------------------------------------------------------
; CheckKeyboardInputForActiveVariable
;-------------------------------------------------------
CheckKeyboardInputForActiveVariable    
        AND #$80
        BEQ b13F4
        ; The value in currentVariableMode starts with an $8, so is
        ; one of Custom Preset, Save Prompt, Display/Load/Abort,
        JMP CheckKeyboardWhilePromptActive
        ;Returns

        ; The active variable is one with a sliding scale.
        ; Allow a bit of time between detected keystrokes.
b13F4   LDA timerBetweenKeyStrokes
        BEQ b13FD
        DEC timerBetweenKeyStrokes
        JMP DisplayVariableSelection
        ; Returns

b13FD   LDA lastKeyPressed
        CMP #$40
        BNE b1406
        ; No key pressed. Just display the active variable mode and return.
        JMP DisplayVariableSelection
        ; Returns

        ; Display the current active variable
b1406   LDA #$04
        STA timerBetweenKeyStrokes

        LDA currentVariableMode
        CMP #COLOR_CHANGE
        BEQ UpdateColorChange
        CMP #BUFFER_LENGTH
        BNE UpdateVariableDisplay

        ; The active mode is 'Color Change'.
UpdateColorChange   
        LDX #$00
b1417   LDA baseLevelArray,X
        CMP #$FF
        BNE ResetSelectedVariableAndReturn

        INX 
        CPX bufferLength
        BNE b1417

        ; Reset the selected variable if necessary.
        LDA stepsRemainingInSequencerSequence
        BNE ResetSelectedVariableAndReturn
        LDA playbackOrRecordActive
        CMP #$02
        BEQ ResetSelectedVariableAndReturn
        LDA demoModeActive
        BNE ResetSelectedVariableAndReturn

        LDA #$FF
        STA currentModeActive
        LDA #$00
        STA currentStepCount

UpdateVariableDisplay   
        LDA #>$D7D0
        STA colorBarColorRamHiPtr
        LDA #<$D7D0
        STA colorBarColorRamLoPtr

        LDX currentVariableMode
        LDA lastKeyPressed
        CMP #$2C ; > pressed?
        BNE MaybeLeftArrowPressed

        ; > pressed, increase the value bar.
        INC presetValueArray,X
        LDA presetValueArray,X
        ; Make sure we don't exceed the max value.
        CMP maxValueForPresetValueArray,X
        BNE MaybeInColorMode
        DEC presetValueArray,X
        JMP MaybeInColorMode

MaybeLeftArrowPressed   
        CMP #$2F ; < pressed?
        BNE MaybeInColorMode

        ; < pressed, decrease the value bar.
        DEC presetValueArray,X
        LDA presetValueArray,X
        ; Make sure we don't exceed the min value.
        CMP minValueForPresetValueArray,X
        BNE MaybeInColorMode
        INC presetValueArray,X

MaybeInColorMode   
        CPX #$05 ; Color Mode?
        BNE MaybeEnterPressed

        ; For Color Mode update some variables.
        LDX indexForColorBarDisplay
        LDY currentColorSet
        LDA colorValuesPtr,X
        STA presetColorValuesArray,Y

MaybeEnterPressed   
        JSR DisplayVariableSelection
        JMP CheckIfEnterPressed
        ;Returns

;-------------------------------------------------------
; DisplayVariableSelection
;-------------------------------------------------------
DisplayVariableSelection    
        ; Set the pointers to the position on screen for the color bar.
        LDA #>$D7D0
        STA colorBarColorRamHiPtr
        LDA #<$D7D0
        STA colorBarColorRamLoPtr

        LDX currentVariableMode
        CPX #COLOR_CHANGE
        BNE b14AE

        ; Current variable mode is 'color change'
        LDX currentColorSet
        LDA presetColorValuesArray,X
        LDY #$00
b149E   CMP colorValuesPtr,Y
        BEQ b14A8
        INY 
        CPY #$10
        BNE b149E

b14A8   STY indexForColorBarDisplay
        LDX currentVariableMode

b14AE   LDA increaseOffsetForPresetValueArray,X
        STA currentColorBarOffset
        LDA presetValueArray,X
        STA maxToDrawOnColorBar
        TXA 
        PHA 
        LDA enterWasPressed
        BNE b14C9
        LDA #$01
        STA enterWasPressed
        JSR ClearLastLineOfScreen

b14C9   PLA 
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 

        LDX #$00
b14D1   LDA txtVariableLabels,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE b14D1

        LDA currentVariableMode
        CMP #COLOR_CHANGE
        BNE b14EC
        LDA #$30
        CLC 
        ADC currentColorSet
        STA dataFreeDigitTwo
b14EC   JSR WriteLastLineBufferToScreen
        JMP DrawColorValueBar

;-------------------------------------------------------
; CheckIfEnterPressed
;-------------------------------------------------------
CheckIfEnterPressed    
        LDA lastKeyPressed
        CMP #$01 ; Enter Pressed
        BEQ EnterHasBeenPressed
        RTS 

        ; Enter pressed
EnterHasBeenPressed   
        LDA currentVariableMode
        CMP #COLOR_CHANGE
        BNE ReachedLastColor

        ; In Color Change mode, move to the next color set
        ; until you reach the last one.
        INC currentColorSet
        LDA currentColorSet
        CMP #$08
        BEQ ReachedLastColor
        RTS 

        ; Enter was pressed, so exit variable mode.
ReachedLastColor   
        LDA #$00
        STA currentVariableMode
        STA enterWasPressed
        RTS 


.segment "DATA"
maxValueForPresetValueArray       .BYTE $00,$40,$08,$40,$10,$10,$08
                                  .BYTE $20,$10,$08
minValueForPresetValueArray       .BYTE $00,$00,$00,$00,$00
                                  .BYTE $00,$00,$00,$00,$00
increaseOffsetForPresetValueArray .BYTE $00,$01,$08
                                  .BYTE $01,$04,$08,$08,$02,$04,$08
currentVariableMode               .BYTE $00
currentPulseSpeedCounter         .BYTE $01

.segment "RODATA"
txtVariableLabels   
        .BYTE "                "
        .BYTE "SMOOTHING DELAY",$BA
        .BYTE "CURSOR SPEED   ",$BA
        .BYTE "BUFFER LENGTH  ",$BA
        .BYTE "PULSE SPEED    ",$BA
        .BYTE "COLOUR ",$B0," SET   ",$BA
        .BYTE "WIDTH OF LINE  ",$BA
        .BYTE "SEQUENCER SPEED",$BA
        .BYTE "PULSE WIDTH    ",$BA
        .BYTE "BASE LEVEL     ",$BA

.segment "RAM"
colorValuesPtr   
        .BYTE $00

.segment "RODATA"
colorBarValues  .BYTE BLUE,RED,PURPLE,GREEN,CYAN,YELLOW,WHITE,ORANGE
                .BYTE BROWN,LTRED,GRAY1,GRAY2,LTGREEN,LTBLUE,GRAY3

txtTrackingOnOff   

        .BYTE "TRACKING",$BA," OFF   "
        .BYTE "TRACKING",$BA," ON    "


.segment "CODE"
;-------------------------------------------------------
; DisplayPresetMessage
;-------------------------------------------------------
DisplayPresetMessage    
        LDA shiftPressed
        AND #$04
        BEQ SelectNewPreset
        JMP EditCustomPattern

SelectNewPreset
        TXA 
        PHA 
        JSR ClearLastLineOfScreen
        LDX #$00
b1613   LDA txtPreset,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$10
        BNE b1613

        PLA 
        PHA 
        TAX 
        BEQ b1638
b1623   INC dataFreeDigitThree
        LDA dataFreeDigitThree
        CMP #$BA
        BNE b1635
        LDA #$30
        STA dataFreeDigitThree
        INC dataFreeDigitTwo
b1635   DEX 
        BNE b1623

b1638   JMP UpdateCurrentActivePreset

WriteLastLineBufferAndReturn    
        JSR WriteLastLineBufferToScreen
        RTS 

.segment "RODATA"
txtPreset
        .BYTE "PRESET ",$B0,$B0,"      ",$BA
txtPresetActivatedStored
        .BYTE " ACTIVATED       "
        .BYTE "DATA STORED    "

.segment "RAM"
shiftPressed
        .BYTE $00

.segment "CODE"
;-------------------------------------------------------
; UpdateCurrentActivePreset
;-------------------------------------------------------
UpdateCurrentActivePreset    
        LDA shiftPressed
        AND #$01
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 

        LDX #$00
b167C   LDA txtPresetActivatedStored,Y
        STA customPatternValueBufferMessage,X
        INY 
        INX 
        CPX #$10
        BNE b167C

        LDA shiftPressed
        AND #$01
        BNE b1692
        JMP RefreshPresetData

b1692   PLA 
        TAX 
        JSR GetPresetPointersUsingXRegister

        LDY #$00
        LDX #$00
b169B   LDA presetValueArray,X
        STA (presetSequenceDataLoPtr),Y
        INY 
        INX 
        CPX #$15
        BNE b169B

        LDA currentPatternElement
        STA (presetSequenceDataLoPtr),Y
        INY 
        LDA currentSymmetrySetting
        STA (presetSequenceDataLoPtr),Y
        JMP WriteLastLineBufferAndReturn

;-------------------------------------------------------------------------
; RefreshPresetData
;-------------------------------------------------------------------------
RefreshPresetData    
        PLA 
        TAX 
        JSR GetPresetPointersUsingXRegister
        LDY #BUFFER_LENGTH
        LDA (presetSequenceDataLoPtr),Y
        CMP bufferLength
        BEQ b16C6

        JSR ResetCurrentActiveMode
        JMP LoadSelectedPresetSequence
        ; Returns

        ; Check the preset against current data
        ; and reload if different.
b16C6   LDX #$00
        LDY #SEQUENCER_SPEED
b16CA   LDA (presetSequenceDataLoPtr),Y
        CMP presetColorValuesArray,X
        BNE LoadSelectedPresetSequence
        INY 
        INX 
        CPX #$08
        BNE b16CA

        JMP LoadSelectedPresetSequence

;-------------------------------------------------------------------------
; LoadSelectedPresetSequence
;-------------------------------------------------------------------------
LoadSelectedPresetSequence    
        LDA #$FF
        STA currentModeActive

        ; Copy the value from the preset sequence into 
        ; current storage.
        LDY #COLOR_BAR_CURRENT
b16E1   LDA (presetSequenceDataLoPtr),Y
        STA presetValueArray,Y
        INY 
        CPY #$15
        BNE b16E1

        LDA (presetSequenceDataLoPtr),Y
        STA currentPatternElement
        INY 
        LDA (presetSequenceDataLoPtr),Y
        STA currentSymmetrySetting
        JMP WriteLastLineBufferAndReturn
        ; Returns

;-------------------------------------------------------
; GetPresetPointersUsingXRegister
;-------------------------------------------------------
GetPresetPointersUsingXRegister   
        LDA #>presetSequenceData
        STA presetSequenceDataHiPtr
        LDA #<presetSequenceData
        STA presetSequenceDataLoPtr
        TXA 
        BEQ b1712

        ; Skip through the preset data until we get to the position
        ; storing the preset data for the sequence indicated by the X
        ; register.
b1702   LDA presetSequenceDataLoPtr
        CLC 
        ADC #$20
        STA presetSequenceDataLoPtr
        LDA presetSequenceDataHiPtr
        ADC #$00
        STA presetSequenceDataHiPtr
        DEX 
        BNE b1702
b1712   RTS 

;-------------------------------------------------------
; ResetCurrentActiveMode
;-------------------------------------------------------
ResetCurrentActiveMode   
        LDA #$FF
        STA currentModeActive
        LDA #$00
        STA currentStepCount
        RTS 

.segment "RAM"
currentModeActive  .BYTE $00

.segment "CODE"
;-------------------------------------------------------
; ReinitializeScreen
;-------------------------------------------------------
ReinitializeScreen
        LDA #$00
        STA currentIndexToPixelBuffers
        STA shouldDrawCursor

        LDX #$00
        LDA #$FF
b172A   STA baseLevelArray,X
        INX
        CPX #$40
        BNE b172A

        LDA #$00
        STA currentModeActive
        JMP InitializeScreenWithInitCharacter
        ; Returns

.segment "RAM"
enterWasPressed  .BYTE $00
functionKeyIndex .BYTE $00

.segment "CODE"
;-------------------------------------------------------
; UpdateBurstGenerator
;-------------------------------------------------------
UpdateBurstGenerator   
        JSR ClearLastLineOfScreen
        LDA shiftPressed
        AND #$01
        BEQ PointToBurstData

        ; Display data free
        LDX #$00
b1748   LDA txtDataFree,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$10
        BNE b1748
        JSR WriteLastLineBufferToScreen

PointToBurstData   
        LDA #>burstGeneratorF1
        STA currentSequencePtrHi
        LDX functionKeyIndex
        LDA functionKeyToSequenceArray,X
        STA currentSequencePtrLo

        LDA shiftPressed
        AND #$01
        BEQ b177B

        ; Set the current data free to 16
        LDA #$10
        STA currentDataFree

        ; Store the current symmetry setting and smoothing delay
        ; in the storage selected by the function key. 
        LDY #$00
        LDA currentSymmetrySetting
        STA (currentSequencePtrLo),Y
        LDA smoothingDelay
        INY 
        STA (currentSequencePtrLo),Y
        RTS 

b177B   LDA #$FF
        STA sequencerActive
        JMP InitializeSequencer

.segment "RODATA"
functionKeyToSequenceArray   .BYTE <burstGeneratorF1,<burstGeneratorF2
                             .BYTE <burstGeneratorF3,<burstGeneratorF4

.segment "DATA"
txtDataFree
        .BYTE "DATA",$BA," ",$B0,$B0,$B0," FREE  "
functionKeys
        .BYTE $04,$05,$06,$03

currentDataFree   .BYTE $FF,$60

.segment "CODE"
;-------------------------------------------------------
; CheckKeyboardWhilePromptActive
;-------------------------------------------------------
CheckKeyboardWhilePromptActive 
        LDA currentVariableMode
        CMP #CUSTOM_PRESET_ACTIVE
        BNE b17A7
        JMP CheckKeyboardInputForCustomPresets

b17A7   CMP #$84
        BNE b17AE
        JMP CheckKeyboardInputWhileSavePromptActive

b17AE   CMP #$85 ; Display Load/Abort
        BNE b17B5
        JMP CheckKeyboardInputWhileLoadAbortActive
        ;Returns

b17B5   LDA #$30
        STA dataFreeDigitOne
        STA dataFreeDigitTwo
        STA dataFreeDigitThree
        LDX currentDataFree
        BNE b17C8
        JMP ReturnPressed
        ; Returns

b17C8   INC dataFreeDigitThree
        LDA dataFreeDigitThree
        CMP #$3A
        BNE b17E9
        LDA #$30
        STA dataFreeDigitThree
        INC dataFreeDigitTwo
        LDA dataFreeDigitTwo
        CMP #$3A
        BNE b17E9
        LDA #$30
        STA dataFreeDigitTwo
        INC dataFreeDigitOne
b17E9   DEX 
        BNE b17C8

        JSR UpdateDataFreeDisplay
        LDA customPromptsActive
        BEQ b1801
        LDA lastKeyPressed
        CMP #$40
        BEQ b17FB
        RTS 

b17FB   LDA #$00
        STA customPromptsActive
b1800   RTS 

b1801   LDA lastKeyPressed
        CMP #$40
        BEQ b1800
        LDX #$01
        STX customPromptsActive
        CMP #$39
        BEQ b183D
        CMP #$01
        BEQ ReturnPressed
        CMP #$3C
        BNE b183C
        JSR UpdateDataFreeDisplay

        LDA currentDataFree
        STA dataFreeForSequencer

        LDA currentSequencePtrLo
        STA prevSequencePtrLo
        LDA currentSequencePtrHi
        STA prevSequencePtrHi

        LDA #$00
        STA currentVariableMode
        STA customPromptsActive
        STA sequencerActive

        LDY #$02
        LDA #$FF
        STA (currentSequencePtrLo),Y
b183C   RTS 

b183D   LDY #$02
        LDA shiftKey
        AND #$01
        BEQ b184B
        LDA #$C0
        JMP j184E

b184B   LDA cursorXPosition

j184E    
        STA (currentSequencePtrLo),Y
        LDA cursorYPosition
        INY 
        STA (currentSequencePtrLo),Y
        LDA currentPatternElement
        INY 
        STA (currentSequencePtrLo),Y
        LDA currentSequencePtrLo
        CLC 
        ADC #$03
        STA currentSequencePtrLo
        LDA currentSequencePtrHi
        ADC #$00
        STA currentSequencePtrHi
        DEC currentDataFree
        RTS 

;-------------------------------------------------------
; ReturnPressed
;-------------------------------------------------------
ReturnPressed    
        JSR UpdateDataFreeDisplay
        LDA #$FF
        LDY #$02
        STA (currentSequencePtrLo),Y
        LDA #$00
        STA currentVariableMode
        STA customPromptsActive
        STA dataFreeForSequencer
        STA sequencerActive
        RTS 

.segment "RAM"
customPromptsActive   .BYTE $00

.segment "CODE"
;-------------------------------------------------------
; UpdateDataFreeDisplay
;-------------------------------------------------------
UpdateDataFreeDisplay
        LDA dataFreeDigitOne
        STA SCREEN_RAM + $03C6
        LDA dataFreeDigitTwo
        STA SCREEN_RAM + $03C7
        LDA dataFreeDigitThree
        STA SCREEN_RAM + $03C8
        RTS 

;-------------------------------------------------------
; InitializeSequencer
;-------------------------------------------------------
InitializeSequencer    
        LDA #$00
        STA currentVariableMode
        TAY 
        LDA (currentSequencePtrLo),Y
        STA prevSymmetrySetting
        INY 
        LDA (currentSequencePtrLo),Y
        STA burstSmoothingDelay

j18A9    
        LDY #$02
        INC currentStepCount
        LDA currentStepCount
        CMP bufferLength
        BNE b18BB

        LDA #$00
        STA currentStepCount
b18BB   LDX currentStepCount
        LDA baseLevelArray,X
        CMP #$FF
        BEQ b18D7

        LDA shouldDrawCursor
        AND trackingActivated
        BEQ b1901

        STA currentStepCount
        TAX 
        LDA baseLevelArray,X
        CMP #$FF
        BNE b1901

b18D7   LDA baseLevel
        STA baseLevelArray,X
        LDA (currentSequencePtrLo),Y
        CMP #$C0
        BEQ b1901

        STA pixelXPositionArray,X
        INY 
        LDA (currentSequencePtrLo),Y
        STA pixelYPositionArray,X
        INY 
        LDA (currentSequencePtrLo),Y
        STA patternIndexArray,X
        LDA burstSmoothingDelay
        STA initialFramesRemainingToNextPaintForStep,X
        STA framesRemainingToNextPaintForStep,X
        LDA prevSymmetrySetting
        STA symmetrySettingForStepCount,X

b1901   LDA currentSequencePtrLo
        CLC 
        ADC #$03
        STA currentSequencePtrLo
        LDA currentSequencePtrHi
        ADC #$00
        STA currentSequencePtrHi
        LDY #$02
        LDA (currentSequencePtrLo),Y
        CMP #$FF
        BEQ b1919
        JMP j18A9

b1919   LDA #$00
        STA sequencerActive
        RTS 

.segment "RAM"
burstSmoothingDelay   .BYTE $00
prevSymmetrySetting .BYTE $00
sequencerActive     .BYTE $00

.segment "CODE"
;-------------------------------------------------------
; ActivateSequencer
;-------------------------------------------------------
ActivateSequencer 
        LDA #>startOfSequencerData
        STA currentSequencePtrHi
        LDA #<startOfSequencerData
        STA currentSequencePtrLo
        LDA #$FF
        STA sequencerActive
        LDA shiftPressed
        AND #$01
        BNE ShiftPressedSoProgramSequencer

        ; Start Playing the Sequencer
        LDA sequencerSpeed
        STA stepsRemainingInSequencerSequence
        LDA #$00
        STA currentVariableMode
        JSR DisplaySequencerState
        RTS 

ShiftPressedSoProgramSequencer   
        LDA dataFreeForSequencer
        BEQ SetUpNewSequencer
        LDA dataFreeForSequencer
        STA currentDataFree
        LDA prevSequencePtrLo
        STA currentSequencePtrLo
        LDA prevSequencePtrHi
        STA currentSequencePtrHi
        JMP DisplaySequFree
        ;Returns

SetUpNewSequencer   
        LDA #$FF
        STA currentDataFree
        LDA currentSymmetrySetting
        LDY #$00
        STA (currentSequencePtrLo),Y
        LDA smoothingDelay
        INY 
        STA (currentSequencePtrLo),Y

DisplaySequFree    
        JSR ClearLastLineOfScreen

        LDX #$00
SequencerTextLoop   
        LDA txtSequFree,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$10
        BNE SequencerTextLoop

        JSR WriteLastLineBufferToScreen
        RTS 

;-------------------------------------------------------
; LoadDataForSequencer
;-------------------------------------------------------
LoadDataForSequencer   
        INC currentStepCount
        LDA currentStepCount
        CMP bufferLength
        BNE b1992

        LDA #$00
        STA currentStepCount
b1992   TAX 
        LDA baseLevelArray,X
        CMP #$FF
        BEQ LoadValuesFromSequencerData

        LDA shouldDrawCursor
        AND trackingActivated
        BEQ MoveToNextPositionInSequencer
        TAX 
        LDA baseLevelArray,X
        CMP #$FF
        BNE MoveToNextPositionInSequencer

LoadValuesFromSequencerData   
        LDY #$02
        LDA (currentSequencePtrLo),Y
        CMP #$C0
        BEQ MoveToNextPositionInSequencer

        LDA baseLevel
        STA baseLevelArray,X

        LDA startOfSequencerData + $01
        STA initialFramesRemainingToNextPaintForStep,X
        STA framesRemainingToNextPaintForStep,X

        LDA startOfSequencerData
        STA symmetrySettingForStepCount,X

        LDY #$02
        LDA (currentSequencePtrLo),Y
        STA pixelXPositionArray,X
        INY 
        LDA (currentSequencePtrLo),Y
        STA pixelYPositionArray,X
        INY 
        LDA (currentSequencePtrLo),Y
        STA patternIndexArray,X

MoveToNextPositionInSequencer   
        LDA currentSequencePtrLo
        CLC 
        ADC #$03
        STA currentSequencePtrLo
        LDA currentSequencePtrHi
        ADC #$00
        STA currentSequencePtrHi
        LDY #$02
        LDA (currentSequencePtrLo),Y
        CMP #$FF
        BEQ ResetSequencerToStart
        RTS 

ResetSequencerToStart   
        LDA #<startOfSequencerData
        STA currentSequencePtrLo
        LDA #>startOfSequencerData
        STA currentSequencePtrHi
        RTS 

.segment "DATA"
stepsRemainingInSequencerSequence   .BYTE $00
txtSequFree
        .BYTE "SEQU",$BA," ",$B0,$B0,$B0," FREE  "

.segment "CODE"
;-------------------------------------------------------
; DisplaySequencerState
;-------------------------------------------------------
DisplaySequencerState    
        LDA sequencerActive
        AND #$01
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 
        JSR ClearLastLineOfScreen
        LDX #$00
b1A18   LDA txtSequencer,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE b1A18
        JMP WriteLastLineBufferToScreen

.segment "RODATA"
txtSequencer
      .BYTE "SEQUENCER OFF   "
      .BYTE "SEQUENCER ON    "

.segment "RAM"
dataFreeForSequencer
      .BYTE $00
prevSequencePtrLo
      .BYTE $00
prevSequencePtrHi
      .BYTE $00
currentPulseWidth
      .BYTE $00

.segment "CODE"
recordingStorageLoPtr = $1F
recordingStorageHiPtr = $20
;-------------------------------------------------------
; StopOrStartRecording
;-------------------------------------------------------
StopOrStartRecording    
        LDA #>dynamicStorage
        STA recordingStorageHiPtr

        LDA #<dynamicStorage
        STA recordingStorageLoPtr

        LDA #$01
        STA recordingOffset

        LDA shiftPressed
        AND #$01
        STA shiftPressed

        LDA playbackOrRecordActive
        ORA shiftPressed
        EOR #$02
        STA playbackOrRecordActive

        AND #$02
        BNE b1A72

        JMP DisplayStoppedRecording

b1A72   LDA playbackOrRecordActive
        AND #$01
        ASL 
        ASL 
        ASL 
        ASL 
        TAY 
        JSR ClearLastLineOfScreen
        LDX #$00
b1A81   LDA txtPlayBackRecord,Y
        STA lastLineBufferPtr,X
        INY 
        INX 
        CPX #$10
        BNE b1A81

        JSR WriteLastLineBufferToScreen
        LDA playbackOrRecordActive
        CMP #$03
        BNE b1AC5

.segment "ZEROPAGE"
dynamicStorageLoPtr .res 1
dynamicStorageHiPtr .res 1

.segment "CODE"
;-------------------------------------------------------
; InitializeDynamicStorage
;-------------------------------------------------------
InitializeDynamicStorage   
        LDA #<dynamicStorage
        STA dynamicStorageLoPtr
        LDA #>dynamicStorage
        STA dynamicStorageHiPtr
        LDY #$00
        TYA 

        LDX #$50
b1AA4   STA (dynamicStorageLoPtr),Y
        DEY 
        BNE b1AA4
        INC dynamicStorageHiPtr
        DEX 
b1AAC   BNE b1AA4

        LDA #$FF
        STA dynamicStorage
        LDA #$01
        STA dynamicStorage + $01
        LDA cursorXPosition
        STA previousCursorXPosition
        LDA cursorYPosition
        STA previousCursorYPosition
        RTS 

b1AC5   LDA #$00
        STA currentColorToPaint
        JSR PaintCursorAtCurrentPosition
        LDA previousCursorXPosition
        STA cursorXPosition
        LDA previousCursorYPosition
        STA cursorYPosition
        LDA #$FF
        STA displaySavePromptActive
        RTS 

.segment "RODATA"
txtPlayBackRecord
        .BYTE "PLAYING BACK",$AE,$AE,$AE,$AE,"RECORDING",$AE,$AE,$AE,$AE,$AE,$AE,$AE

.segment "CODE"
;-------------------------------------------------------
; DisplayStoppedRecording
;-------------------------------------------------------
DisplayStoppedRecording    
        LDA #$00
        STA playbackOrRecordActive
        STA $D020    ;Border Color
        STA displaySavePromptActive
        TAY 
        JSR ClearLastLineOfScreen
b1B0D   LDA txtStopped,Y
        STA lastLineBufferPtr,Y
        INY 
        CPY #$10
        BNE b1B0D
        JMP WriteLastLineBufferToScreen
        ; Returns

.segment "RODATA"
txtStopped
        .BYTE "STOPPED         "

.segment "RAM"
playbackOrRecordActive
        .BYTE $00

.segment "CODE"

;-------------------------------------------------------
; RecordJoystickMovements
;-------------------------------------------------------
RecordJoystickMovements    
        LDA $DC00    ;CIA1: Data Port Register A
        STA buttons
        LDY #$00
        CMP (recordingStorageLoPtr),Y
        BEQ b1B70
b1B37   LDA recordingStorageLoPtr
        CLC 
        ADC #$02
        STA recordingStorageLoPtr
        LDA recordingStorageHiPtr
        ADC #$00
        STA recordingStorageHiPtr
        CMP #$80
        BNE b1B50
        LDA #$00
        STA storageOfSomeKind
        JMP DisplayStoppedRecording

b1B50   LDY #$01
        TYA 
        STA (recordingStorageLoPtr),Y
        LDA $DC00    ;CIA1: Data Port Register A
        DEY 
        STA (recordingStorageLoPtr),Y
        LDA recordingStorageHiPtr
        SEC 
        SBC #$30
        CLC 
        ROR 
        CLC 
        ROR 
        CLC 
        ROR 
        CLC 
        ROR 
        TAX 
        LDA colorBarValues,X
        STA $D020    ;Border Color
        RTS 

b1B70   INY 
        LDA (recordingStorageLoPtr),Y
        CLC 
        ADC #$01
        STA (recordingStorageLoPtr),Y
        CMP #$FF
        BEQ b1B37
        RTS 

PAD_A      = $01
PAD_B      = $02
PAD_SELECT = $04
PAD_START  = $08
PAD_U      = $10
PAD_D      = $20
PAD_L      = $40
PAD_R      = $80

.segment "CODE"
;-------------------------------------------------------
; GamepadPoll
; gamepad_poll: this reads the gamepad state into the variable labelled
; "gamepad" This only reads the first gamepad, and also if DPCM samples are
; played they can conflict with gamepad reading, which may give incorrect
; results.
;-------------------------------------------------------
GamepadPoll
        ; strobe the gamepad to latch current button state
        LDA #1
        STA $4016
        LDA #0
        STA $4016
        ; READ 8 BYTES FROM THE INTERFACE AT $4016
        LDX #8
        :
          PHA
          LDA $4016
          ; COMBINE LOW TWO BITS AND STORE IN CARRY BIT
          AND #%00000011
          CMP #%00000001
          PLA
          ; ROTATE CARRY INTO GAMEPAD VARIABLE
          ROR
          DEX
          BNE :-
        STA buttons
        RTS

.segment "CODE"
;-------------------------------------------------------
; GetJoystickInput
;-------------------------------------------------------
GetJoystickInput   

        ; Just populate buttons for now.
        ;JSR PerformRandomJoystickMovement
        JSR GamepadPoll

        lda buttons
        eor #%11111111
        and previousFrameButtons
        STA releasedButtons

        lda previousFrameButtons
        eor #%11111111
        and buttons
        STA pressedButtons

        LDA buttons
        STA previousFrameButtons
        RTS

        LDA playbackOrRecordActive
        BEQ b1B8C
        CMP #$03
        BNE b1B89
        JMP RecordJoystickMovements

b1B89   JMP PlaybackRecordedJoystickInputs

b1B8C   LDA demoModeActive
        BEQ b1B94
        JMP PerformRandomJoystickMovement

b1B94   LDA $DC00    ;CIA1: Data Port Register A
        STA buttons
        RTS 

PlaybackRecordedJoystickInputs    
        DEC recordingOffset
        BEQ b1BA6

        LDY #$00
        LDA (recordingStorageLoPtr),Y
        STA buttons
        RTS 

b1BA6   LDA recordingStorageLoPtr
        CLC 
        ADC #$02
        STA recordingStorageLoPtr
        LDA recordingStorageHiPtr
        ADC #$00
        STA recordingStorageHiPtr
        CMP #$80
        BEQ b1BC6
        LDY #$01
        LDA (recordingStorageLoPtr),Y
        BEQ b1BC6

        STA recordingOffset
        DEY 
        LDA (recordingStorageLoPtr),Y
        STA buttons
        RTS 

b1BC6   LDA #>dynamicStorage
        STA recordingStorageHiPtr
        LDA #<dynamicStorage
        STA recordingStorageLoPtr
        LDA #$01
        STA recordingOffset
        LDA #$00
        STA currentColorToPaint
        JSR PaintCursorAtCurrentPosition
        LDA previousCursorXPosition
        STA cursorXPosition
        LDA previousCursorYPosition
        STA cursorYPosition
        RTS 

.segment "DATA"
recordingOffset
        .BYTE $00
previousCursorXPosition
        .BYTE $0C
previousCursorYPosition
        .BYTE $0C
customPatternIndex
        .BYTE $00
displaySavePromptActive
        .BYTE $00
txtDefineAllLevelPixels
        .BYTE "DEFINE ALL LEVEL ",$B2," PIXELS"

.segment "CODE"
;-------------------------------------------------------
; EditCustomPattern
;-------------------------------------------------------
EditCustomPattern 
        TXA
        AND #$08
        BEQ b1C0B
        RTS 

b1C0B   LDA #CUSTOM_PRESET_ACTIVE
        STA currentVariableMode

        ; Custom patterns are stored between $C800 and
        ; $CFFF. See custom_patterns.asm
        LDA #$00
        STA customPatternLoPtr
        STA displaySavePromptActive
        LDA customPatternHiPtrArray,X
        STA customPatternHiPtr

        TXA 
        CLC 
        ADC #$08
        STA customPatternIndex
        JSR ClearLastLineOfScreen

        LDX #$00
b1C28   LDA txtDefineAllLevelPixels,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$19
        BNE b1C28

        JSR WriteLastLineBufferToScreen

        LDA #$06
        STA initialBaseLevelForCustomPresets

        ; Write $00,$55 to the first two bytes
        ; of the custom pattern.
        LDY #$00
        TYA 
        STA (customPatternLoPtr),Y
        INY 
        LDA #$55
        STA (customPatternLoPtr),Y

        ; Write $00,$55 to the last two bytes
        ; of the custom pattern.
        LDY #$81
        STA (customPatternLoPtr),Y
        DEY 
        LDA #$00
        STA (customPatternLoPtr),Y

        LDA #$07
        STA minIndexToColorValues

        LDA #$01
        STA currentIndexToPresetValue

        LDA #$17
        STA currentModeActive

        RTS 

;-------------------------------------------------------
; HandleCustomPreset
;-------------------------------------------------------
HandleCustomPreset    
        LDA #$13
        STA cursorXPosition
        LDA #$0C
        STA cursorYPosition
        JSR ReinitializeScreen

b1C68   LDA customPatternIndex
        STA patternIndex
        LDA initialBaseLevelForCustomPresets
        STA baseLevelForCurrentPixel
        LDA #$00
        STA currentSymmetrySettingForStep
        LDA #$13
        STA pixelXPosition
        LDA #$0C
        STA pixelYPosition
        JSR LoopThroughPixelsAndPaint
        LDA initialBaseLevelForCustomPresets
        BNE b1C68

        JSR ReinitializeScreen
        LDA #$00
        STA currentModeActive
        JMP MainPaintLoop

;-------------------------------------------------------
; CheckKeyboardInputForCustomPresets
;-------------------------------------------------------
CheckKeyboardInputForCustomPresets    
        LDA customPromptsActive
        BEQ b1CA2
        LDA lastKeyPressed
        CMP #$40
        BEQ b1C9C
        RTS 

b1C9C   LDA #$00
        STA customPromptsActive
ReturnFromOtherPrompts   
        RTS 

b1CA2   LDA lastKeyPressed
        CMP #$40
        BEQ ReturnFromOtherPrompts

        LDA #$FF
        STA customPromptsActive

        LDA lastKeyPressed
        CMP #$01 ; Return pressed?
        BEQ EnterPressed

        JMP MaybeLeftArrowPressed2

EnterPressed   
        INC currentIndexToPresetValue
        LDA #$00
        LDY currentIndexToPresetValue
        STA (customPatternLoPtr),Y
        PHA 
        TYA 
        CLC 
        ADC #$80
        TAY 
        PLA 
        STA (customPatternLoPtr),Y
        INY 
        LDA #$55
        STA (customPatternLoPtr),Y
        LDY currentIndexToPresetValue
        INY 
        STA (customPatternLoPtr),Y
        STY currentIndexToPresetValue
        LDA #$07
        STA minIndexToColorValues
        DEC initialBaseLevelForCustomPresets
        BEQ b1CE6
        LDA initialBaseLevelForCustomPresets
        EOR #$07
        CLC 
        ADC #$31
        STA SCREEN_RAM + $03D1
        RTS 

b1CE6   LDA #$00
        STA currentVariableMode
        JSR ClearLastLineOfScreen
b1CEE   RTS 

MaybeLeftArrowPressed2
        CMP #KEY_LEFT ; Left arrow pressed.
        BNE b1CEE

        LDY currentIndexToPresetValue
        LDA cursorXPosition
        SEC 
        SBC #$13
        STA (customPatternLoPtr),Y
        INY 
        LDA #$55
        STA (customPatternLoPtr),Y
        STY currentIndexToPresetValue
        TYA 
        CLC 
        ADC #$7F
        TAY 
        LDA cursorYPosition
        SEC 
b1D0D   SBC #$0C
        STA (customPatternLoPtr),Y
        INY 
        LDA #$55
        STA (customPatternLoPtr),Y
        DEC minIndexToColorValues
        BEQ b1D1B
        RTS 

b1D1B   JMP EnterPressed

;-------------------------------------------------------
; GetCustomPatternElement
;-------------------------------------------------------
GetCustomPatternElement    
        JSR ClearLastLineOfScreen

        LDX #$00
txtPatternLoop   
        LDA txtCustomPatterns,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$0E
        BNE txtPatternLoop

        LDA currentPatternElement
        AND #$07
        CLC 
        ADC #$30
        STA customPatternValueBufferPtr
        JMP WriteLastLineBufferToScreen
        ; Returns

.segment "DATA"
txtCustomPatterns
        .BYTE "USER SHAPE "
        .BYTE $A3,$B0
pixelShapeIndex
        .BYTE $00

.segment "RODATA"
pixelShapeArray
        .BYTE $CF,$51,$53,$5A,$5B,$5F,$57,$7F
        .BYTE $56,$61,$4F,$66,$6C,$EC,$A0,$2A
        .BYTE $47,$4F,$41,$54,$53,$53,$48,$45
        .BYTE $45,$50

.segment "CODE"
presetTempLoPtr                       = $FB
presetTempHiPtr                       = $FC

PRINT = $FFD2
;-------------------------------------------------------
; DisplaySavePromptScreen
;-------------------------------------------------------
DisplaySavePromptScreen 
        LDA #$13
        JSR PRINT
        LDA #$FF
        STA displaySavePromptActive
        JSR InitializeScreenWithInitCharacter
b1D70   LDA tapeSavingInProgress
        BEQ b1D70
        CMP #$01
        BNE b1DA4
        LDA #$01
        LDX #$01
        LDY #$01
        JSR ROM_SETLFS ;$FFBA - set file parameters              
        LDA #$05
        LDX #$59
        LDY #$1D
        JSR ROM_SETNAM ;$FFBD - set file name                    
        LDA #$01
        STA CURRENT_CHAR_COLOR
        LDA #>presetSequenceData
        STA presetHiPtr
        LDA #<presetSequenceData
        STA presetLoPtr
        LDX #$FF
        LDY #$CF
        LDA #$FE
        JSR ROM_SAVE ;$FFD8 - save after call SETLFS,SETNAM    
        JMP j1E08

b1DA4   CMP #$02
        BNE b1DE6
        LDA #$01
        LDX #$01
        LDY #$01
        JSR ROM_SETLFS ;$FFBA - set file parameters              
        LDA #$05
        LDX #$5E
        LDY #$1D
        JSR ROM_SETNAM ;$FFBD - set file name                    
        LDA #$01
        STA CURRENT_CHAR_COLOR
        LDA #$30
        STA presetHiPtr
        STA presetTempHiPtr
        LDA #$00
        STA presetLoPtr
        STA presetTempLoPtr
        LDY #$00
b1DCD   LDA (presetTempLoPtr),Y
        BEQ b1DDA
        INC presetTempLoPtr
        BNE b1DCD
        INC presetTempHiPtr
        JMP b1DCD

b1DDA   LDX presetTempLoPtr
        LDY presetTempHiPtr
        LDA #$FE
        JSR ROM_SAVE ;$FFD8 - save after call SETLFS,SETNAM    
        JMP j1E08

b1DE6   LDA #$01
        LDX #$01
        LDY #$01
        JSR ROM_SETLFS ;$FFBA - set file parameters              
        LDA #$00
        JSR ROM_SETNAM ;$FFBD - set file name                    
        LDA #$01
        STA CURRENT_CHAR_COLOR
        LDA #$00
        JSR ROM_LOAD ;$FFD5 - load after call SETLFS,SETNAM    
        JSR ROM_READST ;$FFB7 - read I/O status byte             
        AND #$10
        BEQ j1E08
        JSR DisplayLoadOrAbort

j1E08    
        LDA #$00
        STA currentModeActive
        STA displaySavePromptActive
        STA tapeSavingInProgress
        JSR ROM_CLALL ;$FFE7 - close or abort all files         
        JSR ReinitializeScreen
        JMP MainPaintLoop

        RTS 

;-------------------------------------------------------
; PromptToSave
;-------------------------------------------------------
PromptToSave    
        LDA stepsRemainingInSequencerSequence
        BNE b1E43
        LDA playbackOrRecordActive
        CMP #$02
        BEQ b1E43

        LDA #SAVING_ACTIVE
        STA currentVariableMode

        LDX #$00
b1E30   LDA txtSavePrompt,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$28
        BNE b1E30

        LDA #$00
        STA tapeSavingInProgress
        JSR WriteLastLineBufferToScreen
b1E43   RTS 

.segment "RODATA"
txtSavePrompt   .BYTE " SAVE (P)ARAMETERS, (M)OTION, (A)BORT?  "

.segment "CODE"
;-------------------------------------------------------
; CheckKeyboardInputWhileSavePromptActive
;-------------------------------------------------------
CheckKeyboardInputWhileSavePromptActive    
        LDA currentVariableMode
        CMP #SAVING_ACTIVE
        BEQ b1E74
        RTS 

b1E74   LDA lastKeyPressed
        CMP #$0A ; 'A' pressed?
        BNE MaybeM_Pressed

        ; 'A' pressed.
        LDA #$00
        STA currentModeActive

j1E7F    
        LDA #$00
        STA currentVariableMode
        JMP ClearLastLineOfScreen

MaybeM_Pressed   
        CMP #$24 ; 'M' pressed?
        BNE MaybeP_Pressed

        ; Selecting MOTION saves the stored sequence of joystick moves used in
        ; the Record option. (Long performances take a little while!). The
        ; parameters are saved as GOATS and the motion as SHEEP (| suggest you
        ; use opposite sides of a short cassette to store these on). 
        LDA #$02
        STA tapeSavingInProgress
        LDA #$18
        STA currentModeActive
        JMP j1E7F

MaybeP_Pressed   
        CMP #$29 ; 'P' pressed?
        BNE b1EA9

        ; Selecting PARAMETERS saves all presets, burst gens and sequencer,
        ; plus all user-defined shapes.
        LDA #$01
        STA tapeSavingInProgress
        LDA #$18
        STA currentModeActive
        JMP j1E7F

b1EA9   RTS 

tapeSavingInProgress   .BYTE $00
;-------------------------------------------------------
; DisplayLoadOrAbort
;-------------------------------------------------------
DisplayLoadOrAbort    
        
        LDA stepsRemainingInSequencerSequence
        BNE b1EA9
        LDA playbackOrRecordActive
        CMP #$02
        BEQ b1EA9
        LDA #LOADING_ACTIVE
        STA currentVariableMode
        LDX #$00
b1EBE   LDA txtContinueLoadOrAbort,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$28
        BNE b1EBE
        LDA #$00
        STA tapeSavingInProgress
        JMP WriteLastLineBufferToScreen

;-------------------------------------------------------
; CheckKeyboardInputWhileLoadAbortActive
;-------------------------------------------------------
CheckKeyboardInputWhileLoadAbortActive    
        LDA lastKeyPressed
        CMP #$0A ; 'A'
        BNE b1EE5
        ; 'A' pressed
        LDA #$00
        STA currentVariableMode
        STA tapeSavingInProgress
        STA currentModeActive
        JMP ClearLastLineOfScreen

b1EE5   CMP #$14 ; 'C'
        BNE b1EFB

        ; 'C' pressed
        LDA #$03
        STA tapeSavingInProgress
        LDA #$00
        STA currentVariableMode
        LDA #$18
        STA currentModeActive
        JMP ClearLastLineOfScreen

b1EFB   RTS 

.segment "RODATA"
txtContinueLoadOrAbort
        .BYTE "{C}ONTINUE LOAD@ OR {A}BORT? "
        .BYTE "           "

.segment "DATA"
demoModeActive          .BYTE $00
joystickInputDebounce   .BYTE $01
joystickInputRandomizer .BYTE $10

.segment "CODE"
;-------------------------------------------------------
; PerformRandomJoystickMovement
;-------------------------------------------------------
PerformRandomJoystickMovement 
;        DEC joystickInputDebounce
;        BEQ b1F2D
;        RTS 

b1F2D   JSR PutRandomByteInAccumulator
;        AND #$1F
;        ORA #$01
;        STA joystickInputDebounce
;        LDA joystickInputRandomizer
;        EOR #$10
;        STA joystickInputRandomizer
;        JSR PutRandomByteInAccumulator
;        AND #$F0
;        ORA joystickInputRandomizer
;        EOR #$1F
        STA buttons
        DEC demoModeCountDownToChangePreset
        BEQ b1F51
        RTS 

b1F51   JSR PutRandomByteInAccumulator
        AND #$07
b1F56   ADC #$20
        STA demoModeCountDownToChangePreset
        JSR PutRandomByteInAccumulator
        AND #$0F
        TAX 
        LDA #$00
        STA shiftPressed
        ;JMP SelectNewPreset
        RTS
        ; Returns

;-------------------------------------------------------
; DisplayDemoModeMessage
;-------------------------------------------------------
DisplayDemoModeMessage   
        LDA demoModeActive
        BNE b1F71
        JMP ClearLastLineOfScreen
        ;Returns

b1F71   LDX #$00
b1F73   LDA demoMessage,X
        STA lastLineBufferPtr,X
        INX 
        CPX #$28
        BNE b1F73
        JMP WriteLastLineBufferToScreen

.segment "RODATA"
demoMessage
        .BYTE "      PSYCHEDELIA BY JEFF MINTER         "

;* = $1FA9
.segment "DATA"
demoModeCountDownToChangePreset
        .BYTE $20

.segment "CODE"
;-------------------------------------------------------
; NMIInterruptHandler
; Not really sure of the purpose of the values being
; pushed to the stack here. Is it all to prevent the
; RESTORE key from resetting things?
;-------------------------------------------------------
NMIInterruptHandler
        LDX #<CalledFromNMI
        TXS
        LDA #>CalledFromNMI
        PHA
        LDA #$30
        PHA
        LDA #$23
        PHA
        RTI

.import __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
;-------------------------------------------------------
; MovePresetDataIntoPosition
;-------------------------------------------------------
MovePresetDataIntoPosition   

        LDY __DATA_SIZE__
_Loop   LDA __DATA_LOAD__,Y
        STA __DATA_RUN__,Y
        DEY 
        BNE _Loop

        RTS 

.segment "CODE"
;-------------------------------------------------------
; CheckPlayerInput
;-------------------------------------------------------
CheckPlayerInput
        JSR GetJoystickInput
        LDA releasedButtons
        AND #PAD_SELECT
        BEQ :++
          INC currentSymmetrySetting
          LDA currentSymmetrySetting
          CMP #$05
          BNE :+
            LDA #$00
            STA currentSymmetrySetting
          :
        :

        LDA releasedButtons
        AND #PAD_B
        BEQ :+
          INC currentPatternElement
          LDA currentPatternElement
          AND #$0F
          STA currentPatternElement
        :

        LDA releasedButtons
        AND #PAD_START
        BEQ :+
          LDA lineModeActivated
          EOR #$01
          STA lineModeActivated
        :

        INC inputRateLimit
        LDA inputRateLimit
        CMP #$60
        BPL @CheckInput
        RTS

@CheckInput
        LDA #$00
        STA inputRateLimit

        LDA buttons
        CMP #$00
        BNE:+
          LDA #CURSOR_TILE
          STA currentColorToPaint
          JSR PaintCursorAtCurrentPosition
          RTS
        :

        LDA #$00
        STA currentColorToPaint
        JSR PaintCursorAtCurrentPosition

        LDA buttons
        AND #PAD_D
        BEQ :++
          INC cursorYPosition
          LDA cursorYPosition
          CMP #$18
          BNE :+
            LDA #$00
            STA cursorYPosition
          :
        :

        LDA buttons
        AND #PAD_U
        BEQ :++
          DEC cursorYPosition
          LDA cursorYPosition
          CMP #$FF
          BNE :+
            LDA #$17
            STA cursorYPosition
          :
        :

        LDA buttons
        AND #PAD_L
        BEQ :++
          DEC cursorXPosition
          LDA cursorXPosition
          CMP #$FF
          BNE :+
            LDA #CURSOR_EXTREME_RIGHT
            STA cursorXPosition
          :
        :

        LDA buttons
        AND #PAD_R
        BEQ :++
          INC cursorXPosition
          LDA cursorXPosition
          CMP #CURSOR_EXTREME_RIGHT
          BCC :+
            LDA #$00
            STA cursorXPosition
          :
        :

        LDA buttons
        AND #PAD_A
        BEQ :+
          LDA #01
          STA playerPressedFire
        :

        LDA #CURSOR_TILE
        STA currentColorToPaint
        JSR PaintCursorAtCurrentPosition
        RTS

.include "presets.asm"
.include "burst_generators.asm"
.include "sequencer_data.asm"
.include "custom_patterns.asm"
