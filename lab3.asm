$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram
   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
Timer2_overflow: ds 1
T2ov: ds 2 ; 16-bit timer 2 overflow (to measure the period of very slow signals)

BSEG
mf: dbit 1

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

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  	db 'Period (ns)    :', 0
No_Signal_Str:    	db 'No signal       ', 0
hello:				db 'Hello World !   ', 0
cap:				db 'Capacitance(uF):', 0
imp:				db 'Impedance      :', 0
res:				db 'Resistance     :', 0

; Sends 10-digit BCD number in bcd to the LCD
Display_10_digit_BCD:
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret
	
hex22bcd:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #0
    mov R4, #24 ;Loop counter.

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret

Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	push acc
	inc T2ov+0
	mov a, T2ov+0
	jnz Timer2_ISR_done
	inc T2ov+1
Timer2_ISR_done:
	pop acc
	reti
	
wait_for_P4_5:
	jb P4.5, $ ; loop while the button is not pressed
	Wait_Milli_Seconds(#50) ; debounce time
	jb P4.5, wait_for_P4_5 ; it was a bounce, try again
	jnb P4.5, $ ; loop while the button is pressed
	ret
	
wait_for_P2_6:
	jb P2.6, $ ; loop while the button is not pressed
	Wait_Milli_Seconds(#50) ; debounce time
	jb P2.6, wait_for_P2_6 ; it was a bounce, try again
	jnb P2.6, $ ; loop while the button is pressed
	ret	
	
wait_for_P0_0:
	jb P0.0, $ ; loop while the button is not pressed
	Wait_Milli_Seconds(#50) ; debounce time
	jb P0.0, wait_for_P0_0 ; it was a bounce, try again
	jnb P0.0, $ ; loop while the button is pressed
	ret

DisplayBCD_LCD:
	; 8th digit:
    mov a, R3
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 6th digit:
    mov a, R3
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 6th digit:
    mov a, R2
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
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
Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
    ret

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
    setb EA
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    setb P0.0 ; Pin is used as input
    
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    
forever:
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2
synch1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal ; If the count is larger than 0x01ffffffff*45ns=1.16s, we assume there is no signal
    jb P0.0, synch1
synch2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P0.0, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal 
    jb P0.0, measure1
measure2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P0.0, measure2
    clr TR2 ; Stop timer 2, [T2ov+1, T2ov+0, TH2, TL2] * 45.21123ns is the period

	sjmp skip_this
no_signal:	
	Set_Cursor(2, 1)
    Send_Constant_String(#No_Signal_Str)
    ljmp skip_this ; Repeat! 
    
skip_this:
    lcall wait_for_P4_5
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
	; Make sure [T2ov+1, T2ov+2, TH2, TL2]!=0
	mov a, TL2
	orl a, TH2
	orl a, T2ov+0
	orl a, T2ov+1
	jz no_signal
	; Using integer math, convert the period to frequency:
	mov x+0, TL2
	mov x+1, TH2
	mov x+2, T2ov+0
	mov x+3, T2ov+1
	Load_y(45) ; One clock pulse is 1/22.1184MHz=45.21123ns
	lcall mul32
	Set_Cursor(2, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD
	
	;--------------------------Capacitor
	lcall wait_for_P4_5; wait for the push button
	Set_Cursor(1, 1)
    Send_Constant_String(#cap)
    Load_y(300000000); Capacitance calculation
	lcall div32
	Load_y(144)
	lcall mul32

	Set_Cursor(2, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD ; x = 10

	
	;--------------------------Impedance
    lcall wait_for_P4_5; wait for the push button
    Set_Cursor(1, 1)
    Send_Constant_String(#imp)
    
    Load_y(300000000); reversing calculation
    lcall mul32
    Load_y(144)
    lcall div32 
	lcall copy_xy
	Load_x(1000000000); Convert from ns to Hz
	lcall div32	
	Load_y(71000); Impedance calculation
	lcall mul32
	Load_y(113)
	lcall div32
	Load_y(300)
	lcall div32
	
	Set_Cursor(2, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD

    ;-------------------------Resistance
	lcall wait_for_P4_5; wait for the push button
    Set_Cursor(1, 1)
	Send_Constant_String(#res)

	Load_y(300); reversing calculation
	lcall mul32
	Load_y(113)
	lcall mul32
	Load_y(71000)
	lcall div32
	lcall copy_xy
	Load_x(1000000000)
	lcall mul32
	Load_y(144)
	lcall mul32
	Load_y(300000000)
	lcall div32
	
	Load_y(1440000); Resistance calculation, noting that the displayed value is in ohms	
	lcall mul32
	Load_y(10000)	
	lcall div32
	Load_y(2000)
	lcall sub32

    Set_Cursor(2, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD
    ljmp forever ; Repeat!
end
