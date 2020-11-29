.pseudocommand set target:value {
    lda value
    sta target
}

.pseudocommand add value {
    clc
    adc value
}

.pseudocommand addm m:value {
    clc
    lda m
    adc value
    sta m
}

.macro callEveryXTime(count, function) {
    inc counter
    lda counter
    cmp #count
    bne skip
    set counter : #0
    jsr function
    jmp skip
    
counter: .byte 0
skip:
}

.macro callEveryRaster(function) {
    ldy #$7f            // $7f = %01111111
    sty cia.CIAICR      // Turn off CIAs Timer interrupts
    sty cia.CI2ICR      // Turn off CIAs Timer interrupts
    lda cia.CIAICR      // cancel all CIA-IRQs in queue/unprocessed
    lda cia.CI2ICR      // cancel all CIA-IRQs in queue/unprocessed

    lda #$01            // Set Interrupt Request Mask...
    sta vic.IRQMSK      // ...we want IRQ by Rasterbeam

    lda #<customInterrupt // point IRQ Vector to our custom irq routine
    ldx #>customInterrupt 
    sta $314            // store in $314/$315
    stx $315 

    lda #$00            // trigger first interrupt at row zero
    sta vic.RASTER
    lda vic.SCROLY      // Bit#0 of $d011 is basically...
    and #$7f            // ...the 9th Bit for $d012
    sta vic.SCROLY      // we need to make sure it is set to zero    

    jmp end
    
customInterrupt:
    jsr function   
    dec vic.VICIRQ
    jmp $ea81   
    
end:    
}
