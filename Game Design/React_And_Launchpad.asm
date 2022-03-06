$NOLIST
$MODLP51
$LIST

CLK             equ 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE0  EQU ((2048*2)+100)
TIMER0_RATE1  EQU ((2048*2)-300)
TIMER0_RELOAD0 EQU ((65536-(CLK/TIMER0_RATE0)))
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1)))

TIMER0_TUNE1 EQU ((2048*2)-500)
TIMER0_piano1 EQU ((65536-(CLK/TIMER0_TUNE1)))
TIMER0_TUNE2 EQU ((2048*2)+300)
TIMER0_piano2 EQU ((65536-(CLK/TIMER0_TUNE2)))
TIMER0_TUNE3 EQU ((2048*2)-500)
TIMER0_piano3 EQU ((65536-(CLK/TIMER0_TUNE3)))
DEBOUNCE_DELAY	equ	50


C__1 EQU	((65536-(CLK/523)))
D__1 EQU	((65536-(CLK/587)))
E__1 EQU	((65536-(CLK/659)))
F__1 EQU	((65536-(CLK/698)))
G__1 EQU	((65536-(CLK/784)))
A__1 EQU	((65536-(CLK/880)))
B__1 EQU	((65536-(CLK/987)))

C__2 EQU	((65536-(CLK/1046)))
D__2 EQU	((65536-(CLK/1174)))
E__2 EQU	((65536-(CLK/1318)))
F__2 EQU	((65536-(CLK/1396)))
G__2 EQU	((65536-(CLK/1568)))
A__2 EQU	((65536-(CLK/1760)))
B__2 EQU	((65536-(CLK/1975)))

;pin
BUTTON_BOOT   equ P4.5
SOUND_OUT     equ P1.1
SOUND_OUT2	  equ p2.2
BUTTON_1      equ p0.0
BUTTON_2      equ p0.3

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
	
; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:    	 ds 2 ; Used to determine when half second has passed
mode:		 	 ds 1 ; modes
Seed: 			 ds 1
x:   			 ds 4
y:   			 ds 4
bcd: 			 ds 5
Timer2_overflow: ds 1
period1:  		 ds 2
period2:  		 ds 2
p1_ctr:			 ds 1 ; Player 1 points counter
p2_ctr:			 ds 1 ; Player 2 points counter
dec_ctr:		 ds 2 ; Loop counter for incorrect tone 

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
tick_flag: 	        dbit 1 ; Set to one in the ISR every time 500 ms had passed
mf: 				dbit 1 

$NOLIST
$include(math32.inc)
$LIST

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

Wait_Seconds mac
	push AR2
	mov R2, %0
	lcall ?Wait_Seconds
	pop AR2
endmac

?Wait_Seconds:
	push AR0
	push AR1
L12: mov R1, #190
L11: mov R0, #200
L10: djnz R0, L10 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L11 ; 22.51519us*45=1.013ms
    djnz R2, L12 ; number of millisecons to wait passed in R2
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


WaitSec_1:
    push AR0
    push AR1
L16: mov R1, #30
L15: mov R0, #30
L14: djnz R0, L14 
    djnz R1, L15
    djnz R2, L16 ; number passed in R2
    pop AR1
    pop AR0
    ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
    ret
 
InitTimer0:
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD1)
	mov TL0, #low(TIMER0_RELOAD1)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret    
Timer0_ISR:
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti
	
Random:
	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(214013)
	lcall mul32
	Load_y(2531011)
	lcall add32
	mov Seed+0, x+0
	mov Seed+1, x+1
	mov Seed+2, x+2
	mov Seed+3, x+3
	ret
	
wait_random:
	Wait_Seconds(Seed+0)
	Wait_Seconds(Seed+1)
	Wait_Seconds(Seed+2)
	Wait_Seconds(Seed+3)
	ret

wait_milli_random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret
       
intro:
	Set_Cursor(1, 1)
	Send_Constant_String(#intro0)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro1)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro2)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro3)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro4)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro5)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro6)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro7)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro8)
	mov R2, #30	;Wait 
	lcall WaitSec
	
	Set_Cursor(2, 1) 
	
	Send_Constant_String(#intro9)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro10)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro11)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro12)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro13)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro14)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro15)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro16)
	mov R2, #30	;Wait 
	lcall WaitSec
	Send_Constant_String(#intro17)
	mov R2, #30	;Wait 
	lcall WaitSec
	ret
blanks:
	Set_Cursor(1, 1)
	Send_Constant_String(#blank)
	Set_Cursor(2, 1)
	Send_Constant_String(#blank)	
	
Intro0:  db 'W', 0
Intro1:  db 'E', 0
Intro2:  db 'L', 0
Intro3:  db 'C', 0
Intro4:  db 'O', 0
Intro5:  db 'M', 0
Intro6:  db 'E ', 0
Intro7:  db 'T', 0
Intro8:  db 'O', 0
Intro9:  db '2', 0
Intro10:  db '9', 0
Intro11:  db '1', 0
Intro12:  db ' ', 0
Intro13:  db 'G', 0
Intro14:  db 'A', 0
Intro15:  db 'M', 0
Intro16:  db 'E', 0
Intro17:  db 'S !', 0

menu0:   db '  Choose Your   ', 0
menu1:   db '     Game...    ', 0

game0:   db '1. React!       ', 0
game1:   db '2. Launch Pad   ', 0

cursor0: db '1. React!   <-  ', 0
cursor1: db '2. piano    <-  ', 0
loading: db '   Loading...   ', 0

react:   db '    [React!]    ', 0
piano:   db '  [Launch Pad]   ', 0
blank:   db '                ', 0

start:	 db 'Press 1 to start', 0
player1: db 'Player 1:       ', 0
player2: db 'Player 2:       ', 0
notr:    db 'Not ready yet   ', 0

score1:  db '            0   ', 0
score2:  db '            0   ', 0

p1_wins: db 'Player 1 wins   ', 0
p2_wins: db 'Player 2 wins   ', 0
hooray:  db 'Player 2 sucks! ', 0
hooray2:  db 'Player 1 sucks! ', 0
wait: 	 db 'wait', 0

Key1:   db '     Key 1       ', 0
Key2:   db '     Key 2      ', 0
changekey: db '   Change Key   ', 0 

wait_for_P0_0:
	jb p0.0, $ ; loop while the button is not pressed
	Wait_Milli_Seconds(#50) ; debounce time
	jb p0.0, wait_for_P0_0 ; it was a bounce, try again
	jnb p0.0, $ ; loop while the button is pressed
	ret
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb    EA              ; Enable Global interrupts
    lcall LCD_4BIT
    lcall InitTimer0
    clr     TR0
    setb P2.0
    setb P2.1
   ;------------------------------------------------------Opening
   
	lcall intro
    
    mov R2, #50	;Wait 
	lcall WaitSec
	
	lcall blanks
	
	mov R2, #50	;Wait 
	lcall WaitSec
	
	Set_Cursor(1, 1)
    Send_Constant_String(#menu0)
	Set_Cursor(2, 1)
	Send_Constant_String(#menu1)
	
	mov R2, #250	;Wait 
	lcall WaitSec

    ;------------------------------------------------------Game Menu
    Set_Cursor(1, 1)
    Send_Constant_String(#game0)
    Set_Cursor(2, 1)
    Send_Constant_String(#game1)

    ; something important
    setb    tick_flag
    ; set mode
    mov		mode,			#0x00
    ; initialize time
    mov     a,  #0x00

;------------------------------------------------------------Which mode?
loop:
    clr		c
    mov 	a,  mode
    jz		mode0			; if mode == 0
    subb	a, 	#0x01
    jnz		loop_notMode1	; if mode == 1
    ljmp	mode1
loop_notMode1:
    clr     c
    mov 	a,  mode
    subb	a, 	#0x02
    jnz		loop_notMode2   ; if mode == 2
    ljmp    mode2

loop_notMode2:
	; reset mode back to 0
	mov		a, 		#0x00
	mov		mode, 	a
    ljmp    mode0_d
  
;------------------------------------------------------------Mode transition
mode0:
    jb      BUTTON_1, mode0_a  		      
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)	      
    jb     	BUTTON_1, mode0_a               
    jnb    	BUTTON_1, $		              
                                              
    ; button 1 is pressed here (goto mode 1)
    ; setup screen
    Set_Cursor(1, 1)
    Send_Constant_String(#game0)
    Set_Cursor(2, 1)
    Send_Constant_String(#game1)
    
    ; change mode
    mov     a,      #0x01
    mov     mode,   a
    ljmp   	mode0_d
    
    
mode0_a:
    jb      BUTTON_2, mode0_d 		      
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)	       
    jb     	BUTTON_2, mode0_d              
    jnb    	BUTTON_2, $		               
                                              
    ; button 2 is pressed here (goto mode 2)
    ; setup screen
    Set_Cursor(1, 1)
    Send_Constant_String(#game0)
    Set_Cursor(2, 1)
    Send_Constant_String(#game1)
    ; change mode
    mov     a,      #0x02
    mov     mode,   a
    ljmp   	mode0_d
    
mode0_d:
    clr    	tick_flag ; We clear this flag in the main ; display every second
    ljmp    loop

;Converts the hex number in TH2-TL2 to BCD in R2-R1-R0 DELETE
hex2bcd_loop:
    mov a, TL2 ;Shift TH0-TL0 left through carry
    rlc a
    mov TL2, a
    
    mov a, TH2
    rlc a
    mov TH2, a
      
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	djnz R3, hex2bcd_loop
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret
;------------------------------------------------------------Mode 1 -> React!
Display_formatted_BCD:
	Set_Cursor(2,1)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret
measure_cap:
    ; Measure the period applied to pin P2.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(250)
    lcall x_gt_y
    jb mf, check_pt1
    
   ; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov period2+0, TL2
    mov period2+1, TH2
	; Convert the result to BCD and display on LCD
    Set_Cursor(2,1)
    lcall hex2bcd2
	;lcall Display_formatted_BCD
    mov x+0, period2+0
    mov x+1, period2+1
    mov x+2, #0
    mov x+3, #0
    load_y(250)
    lcall x_gt_y
    jb mf, check_pt22
    ljmp measure_cap
	ret
check_pt22:
	ljmp check_pt2
addpt11:
	ljmp addpt1
check_pt1:
	clr mf
	mov a, p1_ctr
	cjne a, #0x04, addpt11
	mov R2, #100
	inc p1_ctr 
	Set_Cursor(1,11)
    Display_BCD(p1_ctr)
    lcall waitsec
    mov R2, #255
	Set_Cursor(1,1)
	Send_Constant_String(#p1_wins)
	Set_Cursor(2,1)
	Send_Constant_String(#hooray)
	lcall waitsec
	lcall waitsec
	ljmp main
check_pt2:
	clr mf
	mov a, p2_ctr
	cjne a, #0x04, addpt2
	mov R2, #100
	inc p2_ctr 
	Set_Cursor(2,11)
    Display_BCD(p2_ctr)
    lcall waitsec
    mov R2, #255
	Set_Cursor(2,1)
	Send_Constant_String(#p2_wins)
	Set_Cursor(1,1)
	Send_Constant_String(#hooray2)
	lcall waitsec
	lcall waitsec
	ljmp main
addpt1:
	inc p1_ctr 
	Set_Cursor(1,11)
    Display_BCD(p1_ctr)
	mov R2, #100
	lcall waitsec
	lcall wait_Random
	ljmp react1
addpt2:
	inc p2_ctr 
	Set_Cursor(2,11)
    Display_BCD(p2_ctr)
	mov R2, #100
	lcall waitsec
	lcall wait_Random
	ljmp react1
negcheck_pt11:
	ljmp negcheck_pt1
measure_cap2:
	clr mf
    ; Measure the period applied to pin P2.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(2,1)
    lcall hex2bcd

    mov x+0, TL2
    mov x+1, TH2
    mov x+2, #0
    mov x+3, #0
    load_y(250)
    lcall x_gt_y
    jb mf, negcheck_pt11
	; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov period2+0, TL2
    mov period2+1, TH2
	; Convert the result to BCD and display on LCD
    Set_Cursor(2,1)
    lcall hex2bcd2
    mov x+0, period2+0
    mov x+1, period2+1
    mov x+2, #0
    mov x+3, #0
    load_y(250)
    lcall x_gt_y
    jb mf, negcheck_pt22

	inc dec_ctr ; dec_ctr = 0
    mov a, dec_ctr
	da a
    cjne a, #99, next0
	cjne a, #99, next1
	cjne a, #99, next2
	cjne a, #99, next3
	cjne a, #99, next4
	cjne a, #99, next5
	cjne a, #99, next6
	cjne a, #99, next7
	cjne a, #99, next8
	cjne a, #99, next9
	cjne a, #99, next10
	cjne a, #99, next11
	cjne a, #99, next12
	cjne a, #99, next13
	cjne a, #99, next14
	cjne a, #99, next15
	cjne a, #99, next16
	lcall wait_Random
	ljmp react1
next0:
	ljmp measure_cap2
negcheck_pt22:
	ljmp negcheck_pt2
next1: 
    ljmp measure_cap2
next2: 
    ljmp measure_cap2
next3: 
    ljmp measure_cap2
next4: 
    ljmp measure_cap2
next5: 
    ljmp measure_cap2
next6: 
    ljmp measure_cap2
next7: 
    ljmp measure_cap2
next8: 
    ljmp measure_cap2
next9: 
    ljmp measure_cap2
next10: 
    ljmp measure_cap2
next11: 
    ljmp measure_cap2
next12: 
    ljmp measure_cap2
next13: 
    ljmp measure_cap2
next14: 
    ljmp measure_cap2
next15: 
    ljmp measure_cap2
next16: 
    ljmp measure_cap2
	
negcheck_pt1:
	clr mf
	mov a, p1_ctr
	cjne a, #0x00, subpt1
	mov R2, #100
	lcall waitsec
	lcall wait_Random
	ljmp react1
negcheck_pt2:
	clr mf
	mov a, p2_ctr
	cjne a, #0x00, subpt2
	mov R2, #100
	lcall waitsec
	lcall wait_Random
	ljmp react1
subpt1:
	dec p1_ctr
	Set_Cursor(1,11)
    Display_BCD(p1_ctr)
	mov R2, #100
	lcall waitsec
	lcall wait_Random
	ljmp react1
subpt2:
	dec p2_ctr
	Set_Cursor(2,11)
    Display_BCD(p2_ctr)
	mov R2, #100
	lcall waitsec
	lcall wait_Random
	ljmp react1
mode1:
	jb      BUTTON_BOOT,    mode1_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_BOOT,    mode1_a
    jnb     BUTTON_BOOT,    $
    
    Set_Cursor(1, 1)
    Send_Constant_String(#game0)
    Set_Cursor(2, 1)
    Send_Constant_String(#game1)
    
    mov     a,      #0x00
    mov     mode,   a 
    ljmp    mode1_d
    

mode1_a:
	jb      BUTTON_1,    mode1_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,    mode1_b
    jnb     BUTTON_1,    $

 	ljmp mode1_d
 	
loop_1:
	ljmp loop
	
mode1_b:
	Set_Cursor(1,1)
    Send_Constant_String(#react)
	Set_Cursor(2,1)
    Send_Constant_String(#start)
    
mode1_d:
	jb P0.0, loop_1
	
	;---------As button 1 is pushed, it runs the code below
	WriteCommand(#0x01)
	
    mov R2, #50	;Wait 
	lcall WaitSec
	
	mov p1_ctr, #0x00
	mov p2_ctr, #0x00
	Set_Cursor(1,1)
    Send_Constant_String(#player1)
	Set_Cursor(2,1)
    Send_Constant_String(#player2)
	Set_Cursor(1,11)
    Display_BCD(p1_ctr)
    Set_Cursor(2,11)
    Display_BCD(p2_ctr)
    lcall InitTimer2
    
    mov R2, #180	;Wait 
	lcall WaitSec
	
	clr TR0
	mov Seed+0, TH0
	mov Seed+1, #0x01
	mov Seed+2, #0x87
	mov Seed+3, TL0
	sjmp react1

tone22:
	ljmp tone2
	
react1:
	lcall Random
	mov a, Seed+1 
	mov c, acc.3
    jc tone22 ; jump to tone2 if c = acc.3 is 1, else run the code below. Thus making 2 different sounds. 
 
    clr TR0
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	setb TR0
    lcall wait_milli_random
    clr TR0


    ;--------------------------detect and increment/decrement here
	mov dec_ctr, #0
	;lcall hex2bcd2
    lcall measure_cap2
	ljmp react1

tone2:
	lcall Random
	mov a, Seed+2

  	clr TR0
	mov RH0, #high(TIMER0_RELOAD0)
	mov RL0, #low(TIMER0_RELOAD0)
	setb TR0
    lcall wait_milli_random
    clr TR0


	;-------------------------detect and increment/decrement here
	lcall measure_cap
    ;ljmp react1 ; Repeat! 

;------------------------------------------------------------Mode 2 -> piano
mode2:
	jb      BUTTON_BOOT,    mode2_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_BOOT,    mode2_a
    jnb     BUTTON_BOOT,    $
    
    Set_Cursor(1, 1)
    Send_Constant_String(#game0)
    Set_Cursor(2, 1)
    Send_Constant_String(#game1)
    
    mov     a,      #0x00
    mov     mode,   a
    ljmp    mode1_d
    
 
mode2_a:
	jb      BUTTON_1,    mode2_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,    mode2_b
    jnb     BUTTON_1,    $
    
 	ljmp mode2_d
 
mode2_b:
	Set_Cursor(1,1)
    Send_Constant_String(#piano)
	Set_Cursor(2,1)
    Send_Constant_String(#start)

mode2_d:
	jb P0.0, loop_2
	
	;---------As button 1 is pushed, it runs the code below
	WriteCommand(#0x01)
    
    mov R2, #50	;Wait 
	lcall WaitSec
	
	Set_Cursor(1,1)
    Send_Constant_String(#changekey)

    
    mov R2, #180	;Wait 
	lcall WaitSec
	ljmp piano1
	
loop_2:
	ljmp loop
	
piano1:
	Set_Cursor(2,1)
    Send_Constant_String(#Key1)
    ;--------------------------Capacitor sound here
	lcall measure_key 

piano2:
	Set_Cursor(2,1)
    Send_Constant_String(#Key2)
    
	lcall measure_key_2

measure_key_2:
    jnb P0.6, piano1
	; Measure the period applied to pin P2.0
	clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, C2_11
	sjmp D2_11
C2_11:
	ljmp C_2
	;Detect Key2
D2_11:
	clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
    jb mf, D_2111
	sjmp E_211
D_2111:
	ljmp D_2
E_211:
	clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.2, $
    jnb P2.2, $
    setb TR2 ; Start counter 0
    jb P2.2, $
    jnb P2.2, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, E_2111
	sjmp F_211
E_2111:
	ljmp E_2
F_211:
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.3, $
    jnb P2.3, $
    setb TR2 ; Start counter 0
    jb P2.3, $
    jnb P2.3, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, F_2111
	sjmp G_211
F_2111:
	ljmp F_2
G_211:
	clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.4, $
    jnb P2.4, $
    setb TR2 ; Start counter 0
    jb P2.4, $
    jnb P2.4, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
    jb mf, G_2111
	sjmp C_31
G_2111:
	ljmp G_2
C_31:
	ljmp measure_key_2
    

	
piano22:
	ljmp piano2
measure_key:
    jnb P0.3, piano22
	; Measure the period applied to pin P2.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, C_11
	sjmp D_11
C_11:
	ljmp C_1
	;Detect Key2
D_11:
	clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
    jb mf, D_111
	sjmp E_11
D_111:
	ljmp D_1
E_11:
	clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.2, $
    jnb P2.2, $
    setb TR2 ; Start counter 0
    jb P2.2, $
    jnb P2.2, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, E_111
	sjmp F_11
E_111:
	ljmp E_1
F_11:
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.3, $
    jnb P2.3, $
    setb TR2 ; Start counter 0
    jb P2.3, $
    jnb P2.3, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, F_111
	sjmp G_11
F_111:
	ljmp F_1
G_11:
clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.4, $
    jnb P2.4, $
    setb TR2 ; Start counter 0
    jb P2.4, $
    jnb P2.4, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, G_111
	sjmp C_21
G_111:
	ljmp G_1
C_21:
	ljmp measure_key
;----------------------	
C_1:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(C__1)
	mov RL0, #low(C__1)
	setb TR0

    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, C_1
	clr TR0
	
	ljmp piano1
	
D_1:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(D__1)
	mov RL0, #low(D__1)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, D_1
	clr TR0
	
	ljmp piano1

E_1:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(E__1)
	mov RL0, #low(E__1)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.2, $
    jnb P2.2, $
    setb TR2 ; Start counter 0
    jb P2.2, $
    jnb P2.2, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, E_1
	clr TR0
	
	ljmp piano1

F_1:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(F__1)
	mov RL0, #low(F__1)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.3, $
    jnb P2.3, $
    setb TR2 ; Start counter 0
    jb P2.3, $
    jnb P2.3, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, F_1
	clr TR0
	
	ljmp piano1

G_1:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(G__1)
	mov RL0, #low(G__1)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.4, $
    jnb P2.4, $
    setb TR2 ; Start counter 0
    jb P2.4, $
    jnb P2.4, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, G_1
	clr TR0
	
	ljmp piano1

C_2:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(C__2)
	mov RL0, #low(C__2)
	setb TR0

    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, C_2
	clr TR0
	
	ljmp piano2
	
D_2:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(D__2)
	mov RL0, #low(D__2)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
    jb mf, D_2
	clr TR0
	
	ljmp piano2

E_2:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(E__2)
	mov RL0, #low(E__2)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.2, $
    jnb P2.2, $
    setb TR2 ; Start counter 0
    jb P2.2, $
    jnb P2.2, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, E_2
	clr TR0
	
	ljmp piano2

F_2:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(F__2)
	mov RL0, #low(F__2)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.3, $
    jnb P2.3, $
    setb TR2 ; Start counter 0
    jb P2.3, $
    jnb P2.3, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, F_2
	clr TR0
	
	ljmp piano2

G_2:
	lcall WaitSec_1
	clr TR0
	mov RH0, #high(G__2)
	mov RL0, #low(G__2)
	setb TR0
	
    mov TL2, #0
    mov TH2, #0
    jb P2.4, $
    jnb P2.4, $
    setb TR2 ; Start counter 0
    jb P2.4, $
    jnb P2.4, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov period1+0, TL2
    mov period1+1, TH2
    Set_Cursor(1,1)
    lcall hex2bcd2
    mov x+0, period1+0
    mov x+1, period1+1
    mov x+2, #0
    mov x+3, #0
    load_y(175)
    lcall x_gt_y
	lcall hex2bcd2
	Set_Cursor(1,13)
    jb mf, G_2
	clr TR0
	
	ljmp piano2
END
