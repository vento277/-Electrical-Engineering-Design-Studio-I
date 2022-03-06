; LCD_test_4bit.asm: Initializes and uses an LCD in 4-bit mode
; using the most common procedure found on the internet.
$NOLIST
$MODLP51
$LIST

org 0000H
    ljmp myprogram

; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns

;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
Wait40uSec:
    push AR0
    mov R0, #177
L0:
    nop
    nop
    djnz R0, L0 ; 1+1+3 cycles->5*45.21123ns*177=40us
    pop AR0
    ret
    

;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
WaitmilliSec:
    push AR0
    push AR1
L3: mov R1, #45
L2: mov R0, #166
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*45=1.013ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret
    
WaitSec:
    push AR0
    push AR1
L6: mov R1, #255
L5: mov R0, #255
L4: djnz R0, L4 
    djnz R1, L5
    djnz R2, L6 ; number passed in R2
    pop AR1
    pop AR0
    ret

;---------------------------------;
; Toggles the LCD's 'E' pin       ;
;---------------------------------;
LCD_pulse:
    setb LCD_E
    lcall Wait40uSec
    clr LCD_E
    ret

;---------------------------------;
; Writes data to LCD              ;
;---------------------------------;
WriteData:
    setb LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes command to LCD           ;
;---------------------------------;
WriteCommand:
    clr LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
    ; Write high 4 bits first
    mov c, ACC.7
    mov LCD_D7, c
    mov c, ACC.6
    mov LCD_D6, c
    mov c, ACC.5
    mov LCD_D5, c
    mov c, ACC.4
    mov LCD_D4, c
    lcall LCD_pulse

    ; Write low 4 bits next
    mov c, ACC.3
    mov LCD_D7, c
    mov c, ACC.2
    mov LCD_D6, c
    mov c, ACC.1
    mov LCD_D5, c
    mov c, ACC.0
    mov LCD_D4, c
    lcall LCD_pulse
    ret

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_4BIT:
    clr LCD_E   ; Resting state of LCD's enable is zero
    ; clr LCD_RW  ; Not used, pin tied to GND

    ; After power on, wait for the LCD start up time before initializing
    ; NOTE: the preprogrammed power-on delay of 16 ms on the AT89LP51RC2
    ; seems to be enough.  That is why these two lines are commented out.
    ; Also, commenting these two lines improves simulation time in Multisim.
    ; mov R2, #40
    ; lcall WaitmilliSec

    ; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x32 ; change to 4-bit mode
    lcall WriteCommand

    ; Configure the LCD
    mov a, #0x28
    lcall WriteCommand
    mov a, #0x0e ;  Turn cursor on
    lcall WriteCommand
    mov a, #0x01 ;  Clear screen command (takes some time)
    lcall WriteCommand

    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    mov R2, #2
    lcall WaitmilliSec
    ret
    
hacked_0:
	mov a, #0x0c
	lcall WriteCommand

	mov a, #'H'
	lcall WriteData
	mov a, #'a'
	lcall WriteData
	mov a, #'c'
	lcall WriteData
	mov a, #'k'
	lcall WriteData
	mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	mov R2, #40	;Wait 
    lcall WaitSec
    
    mov a, #0x80
	lcall WriteCommand
	ret
	
hacked_5:
	mov a, #0x0c
	lcall WriteCommand

	mov a, #'H'
	lcall WriteData
	mov a, #'a'
	lcall WriteData
	mov a, #'c'
	lcall WriteData
	mov a, #'k'
	lcall WriteData
	mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	mov R2, #40	;Wait 
    lcall WaitSec
    
    mov a, #0x84
	lcall WriteCommand
	ret
	
dekcaH:
	mov a, #0x0c
	lcall WriteCommand

	mov a, #'d'
	lcall WriteData
	
	mov R2,#40	;Wait 
    lcall WaitSec
    
    mov a, #0x04
    lcall WriteCommand
    lcall space
    mov a, #0x06
    lcall WriteCommand
    
    mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	
	mov R2,#40	;Wait 
    lcall WaitSec
    
    mov a, #0x04
    lcall WriteCommand
   	lcall space
   	lcall space
    mov a, #0x06
    lcall WriteCommand
    
    mov a, #'k'
	lcall WriteData
	mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	
	mov R2,#40	;Wait 
    lcall WaitSec
    
    mov a, #0x04
    lcall WriteCommand
   	lcall space
   	lcall space
   	lcall space
    mov a, #0x06
    lcall WriteCommand
    
    mov a, #'c'
	lcall WriteData
	mov a, #'k'
	lcall WriteData
	mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	
	mov R2,#40	;Wait 
    lcall WaitSec
    
    mov a, #0x04
    lcall WriteCommand
   	lcall space
   	lcall space
   	lcall space
   	lcall space 
    mov a, #0x06
    lcall WriteCommand
    
    mov a, #'a'
	lcall WriteData
	mov a, #'c'
	lcall WriteData
	mov a, #'k'
	lcall WriteData
	mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	
	mov R2,#40	;Wait 
    lcall WaitSec
    
    mov a, #0x04
    lcall WriteCommand
   	lcall space
   	lcall space
   	lcall space
   	lcall space 
   	lcall space 
    mov a, #0x06
    lcall WriteCommand
    
    mov a, #'H'
	lcall WriteData
	mov a, #'a'
	lcall WriteData
	mov a, #'c'
	lcall WriteData
	mov a, #'k'
	lcall WriteData
	mov a, #'e'
	lcall WriteData
	mov a, #'d'
	lcall WriteData
	ret

space:
	mov a, #' '
	lcall WriteData
	ret
	
space_5:
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	ret
	
space_10:
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	mov a, #' '
	lcall WriteData
	ret

scroll:
	lcall hacked_5
	lcall space
	
	lcall hacked_5
	lcall space
	lcall space
	
	lcall hacked_5
	lcall space
	lcall space
	lcall space
	
	lcall hacked_5
	lcall space
	lcall space
	lcall space
	lcall space
	
	lcall hacked_5
	lcall space_5
	
	lcall hacked_5
	lcall space_5
	lcall space
	
	lcall hacked_5
	lcall space_5
	lcall space
	lcall space
	
	lcall hacked_5
	lcall space_5
	lcall space
	lcall space
	lcall space
	
	lcall hacked_5
	lcall space_5
	lcall space
	lcall space
	lcall space
	lcall space
	
	lcall hacked_5
	lcall space_10
	
	lcall hacked_5
	lcall space_10
	lcall space
	
	lcall hacked_5
	lcall space_10
	lcall space
	lcall space
	ret
;---------------------------------;
; Main loop.  Initialize stack,   ;
; ports, LCD, and displays        ;
; letters on the LCD              ;
;---------------------------------;
myprogram:
    mov SP, #7FH
    lcall LCD_4BIT
    
    ;------------------------------------------------------------------
    mov a, #0x80 	; Move cursor to line 1 column 1
    lcall WriteCommand
	mov a, #'P'
    lcall WriteData
    mov a, #'e'
    lcall WriteData
    mov a, #'t'
    lcall WriteData
    mov a, #'e'
    lcall WriteData
    mov a, #'r'
    lcall WriteData
    mov a, #' '
    lcall WriteData
    mov a, #'K'
    lcall WriteData
    mov a, #'i'
    lcall WriteData
    mov a, #'m'
    lcall WriteData
    
    
    mov a, #0xC0 	; Move cursor to line 2 column 1
    lcall WriteCommand
    mov a, #'1'
    lcall WriteData
    mov a, #'8'
    lcall WriteData
    mov a, #'6'
    lcall WriteData
    mov a, #'9'
    lcall WriteData
    mov a, #'3'
    lcall WriteData
    mov a, #'0'
    lcall WriteData
    mov a, #'0'
    lcall WriteData
    mov a, #'2'
    lcall WriteData
    
    mov R2, #255	;Wait about 3 seconds
    lcall WaitSec
	;------------------------------------------------------------------
    ;Display Timer
    mov a, #0x01	;Clear screen
    lcall WriteCommand
    mov R2, #100	;Wait 
    lcall WaitSec
    
    mov a, #0x80	;Cursor at line 1 pos 1
	lcall WriteCommand
	
	mov a, #'T'
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec
	
	mov a, #'i'
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec
	
	mov a, #'m'
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec

	mov a, #'e'
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec

	mov a, #'r'
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec
	
	mov a, #':'
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec
	
	mov a, #' '
	lcall WriteData
	mov R2, #40		;Wait 
    lcall WaitSec
	
	mov a, #0x0c
	lcall WriteCommand
	
	mov a, #'5'
	lcall WriteData
	mov R2, #150	;Wait 
    lcall WaitSec
    
    mov a, #0x04
	lcall WriteCommand
	
	mov a, #' '
	lcall WriteData
	mov a, #'4'
	lcall WriteData
	mov R2, #150	;Wait 
    lcall WaitSec
    
    mov a, #0x06
	lcall WriteCommand

	mov a, #' '
	lcall WriteData
	mov a, #'3'
	lcall WriteData
	mov R2, #200	;Wait 
    lcall WaitSec
    
 	;---------------------------------------------------
    ;Display Error
    mov a, #0x01	;Clear screen
    lcall WriteCommand
    
    mov R2, #5		;Wait
    lcall WaitSec
    
    mov a, #0x84	;cursor at line 1 pos 1
	lcall WriteCommand
	mov a, #'E'
	lcall WriteData
	mov a, #'r'
	lcall WriteData
	mov a, #'r'
	lcall WriteData
	mov a, #'o'
	lcall WriteData
	mov a, #'r'
	lcall WriteData
    mov a, #'!'
	lcall WriteData
	mov a, #'.'
	lcall WriteData
	mov a, #'.'
	lcall WriteData
	
	mov R2, #120	;Wait
    lcall WaitSec
	;---------------------------------------------------
	;Wall
	mov a, #0x0c
	lcall WriteCommand
	mov a, #0xC7
	lcall WriteCommand
	mov a, #255
	lcall WriteData
	mov a, #255
	lcall WriteData
	
	mov R2, #30	;Wait
    lcall WaitSec
    
	;Bullet
    mov a, #0xC0
    lcall WriteCommand
	mov a, #165
	lcall WriteData
	mov R2, #60	;Wait 
	lcall WaitSec	    
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData		
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData	
	mov a, #165
	lcall WriteData
	mov R2, #60	;Wait 
	lcall WaitSec   
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData	
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	mov a, #165
	lcall WriteData
	mov R2, #60	;Wait 
	lcall WaitSec   
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData	
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	mov a, #165
	lcall WriteData
	mov R2, #60	;Wait 
	lcall WaitSec   
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData	
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
    mov a, #165
	lcall WriteData
	mov R2, #60	;Wait 
	lcall WaitSec 
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData	
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	mov a, #165
	lcall WriteData
	mov R2, #50	;Wait 
	lcall WaitSec 
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	mov a, #165
	lcall WriteData
	mov R2, #40	;Wait 
	lcall WaitSec
	mov a, #0x04
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	mov a, #0x06
	lcall WriteCommand
	mov a, #' '
	lcall WriteData
	
	;Broken wall
	mov a, #243
	lcall WriteData
	mov R2, #40	;Wait 
	lcall WaitSec
	mov a, #243
	lcall WriteData
	
	;Crunch!
	mov a, #0x84
	lcall WriteCommand
	mov a, #'C'
	lcall WriteData
	mov a, #'r'
	lcall WriteData
	mov a, #'u'
	lcall WriteData
	mov a, #'n'
	lcall WriteData
	mov a, #'c'
	lcall WriteData
	mov a, #'h'
	lcall WriteData
	mov a, #'!'
	lcall WriteData
	mov a, #'!'
	lcall WriteData
	
	mov R2, #200	;Wait 
	lcall WaitSec
	mov R2, #200	;Wait 
	lcall WaitSec
	mov a, #0x01
	lcall WriteCommand
	;---------------------------------------------------------------
	;Hacked Scroll
	;from middle
	mov a, #0x84
	lcall WriteCommand
	lcall scroll
	
	;from start
	mov a, #0x80
	lcall WriteCommand
	lcall dekcaH
	mov a, #0x80
	lcall WriteCommand
    
	scroll_from_start:
		lcall hacked_0
		lcall space
		
		lcall hacked_0
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space
		lcall space
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_5
		
		lcall hacked_0
		lcall space_5
		lcall space
		
		lcall hacked_0
		lcall space_5
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_5
		lcall space
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_5
		lcall space
		lcall space
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_10
		
		lcall hacked_0
		lcall space_10
		lcall space
		
		lcall hacked_0
		lcall space_10
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_10
		lcall space
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_10
		lcall space
		lcall space
		lcall space
		lcall space
		
		lcall hacked_0
		lcall space_10
		lcall space_5
		
		lcall hacked_0
		lcall space_10
		lcall space_5
		lcall space
		
		mov a, #0x80
		lcall WriteCommand
		lcall dekcaH
		mov a, #0x80
		lcall WriteCommand
	lcall scroll_from_start

forever:
    sjmp forever
END
