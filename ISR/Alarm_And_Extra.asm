; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.1 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P4.5 is pressed.
$NOLIST
$MODLP51
$LIST

; There is a couple of typos in MODLP51 in the definition of the timer 0/1 reload
; special function registers (SFRs), so:

CLK             equ 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE     equ 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
;TIMER0_RELOAD   equ ((65536-(CLK/4096)))
TIMER0_RELOAD   equ 61342
TIMER0_RELOAD1  equ 61093
TIMER0_RELOAD2  equ 61342
TIMER0_RELOAD3  equ 61093
TIMER0_RELOAD4  equ 61342
TIMER0_RELOAD5  equ 59938
TIMER0_RELOAD6  equ 60829
TIMER0_RELOAD7  equ 60252
TIMER0_RELOAD8  equ 59252
TIMER0_RELOAD9  equ 59252
TIMER0_RELOAD10 equ 59252

TIMER1_RATE		equ 1000
TIMER1_RELOAD   equ ((65536-(CLK/TIMER1_RATE)))
TIMER2_RATE     equ 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD   equ ((65536-(CLK/TIMER2_RATE)))
TIME_RATE       equ 250
DEBOUNCE_DELAY	equ	50

;pin
BUTTON_BOOT   equ P4.5
UPDOWN        equ P0.0
SOUND_OUT     equ P1.1
SOUND_OUT2	  equ p2.2
BUTTON_1      equ p0.3
BUTTON_2      equ p0.6
BUTTON_3      equ p2.4
BUTTON_4	  equ p2.2
BUTTON_5	  equ p2.0


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
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:    ds 2 ; Used to determine when half second has passed
BCD_date:	 ds 1
BCD_months:  ds 1
BCD_hour:	 ds 1
BCD_minute:	 ds 1
BCD_second:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
mode:		 ds 1 ; modes
cursor_pos:  ds 1 ; curosr position for setting time
alarm_hour:  ds 1
alarm_min:   ds 1
sound_pos:   ds 1
timer:       ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
tick_flag: 	        dbit 1 ; Set to one in the ISR every time 500 ms had passed
am_pm_flag:         dbit 1
alarm_ampm_flag:    dbit 1
sound_flag:         dbit 1
alarm_toggle_flag:	dbit 1
timer1_flag:        dbit 1

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
Initial_Message:  	db 	'--:--:-- -M     ',  	0
string_date:		db 	'2022/--/--      ', 	0
string_mode3_date:	db 	'Date    ^^      ', 	0
string_mode3_month:	db 	'Mth  ^^         ', 	0
string_mode0:		db	'--:--:-- -M SET ',		0
string_mode1_hour:	db 	'^^          TIME',		0
string_mode1_min:	db	'   ^^       TIME',		0
string_mode1_sec:	db	'      ^^    TIME',		0
string_alarm:       db  '--:-- -M    SET ',  	0
string_alarm_hour:  db  '^^         ALARM',  	0
string_alarm_min:   db  '   ^^      ALARM',  	0
string_alarm_ampm:  db  '      ^^   ALARM',  	0
timer_init:		  	db 	'    --:--:--    ',  	0
timer4:				db  'Lap   :  :      ',     0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)

	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
  	setb    TR0  ; Start timer 0
    ;setb    ET1
    ;setb    TR1
    mov     sound_pos,  #0x00
    ret

	
;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;
Timer0_ISR:
    ;clr TF0  ; According to the data sheet this is done for us already.
    ; In mode 1 we need to reload the timer.
    push	acc
    clr     TR0
    mov 	a,	sound_pos

    cjne    a,  #0x0A,  Timer0_ISR_not10
    mov     TH0, #high(TIMER0_RELOAD10)
    mov     TL0, #low(TIMER0_RELOAD10)
    sjmp    Timer0_ISR_done
	reti
Timer0_ISR_not10:
    cjne    a,  #0x09,  Timer0_ISR_not9
    mov     TH0, #high(TIMER0_RELOAD9)
    mov     TL0, #low(TIMER0_RELOAD9)
    sjmp    Timer0_ISR_done
Timer0_ISR_not9:
    cjne    a,  #0x08,  Timer0_ISR_not8
    mov     TH0, #high(TIMER0_RELOAD8)
    mov     TL0, #low(TIMER0_RELOAD8)
    sjmp    Timer0_ISR_done
Timer0_ISR_not8:
    cjne    a,  #0x07,  Timer0_ISR_not7
    mov     TH0, #high(TIMER0_RELOAD7)
    mov     TL0, #low(TIMER0_RELOAD7)
    sjmp    Timer0_ISR_done
Timer0_ISR_not7:
    cjne    a,  #0x06,  Timer0_ISR_not6
    mov     TH0, #high(TIMER0_RELOAD6)
    mov     TL0, #low(TIMER0_RELOAD6)
    sjmp    Timer0_ISR_done
Timer0_ISR_not6:
    cjne    a,  #0x05,  Timer0_ISR_not5
    mov     TH0, #high(TIMER0_RELOAD5)
    mov     TL0, #low(TIMER0_RELOAD5)
    sjmp    Timer0_ISR_done
Timer0_ISR_not5:
    cjne    a,  #0x04,  Timer0_ISR_not4
    mov     TH0, #high(TIMER0_RELOAD4)
    mov     TL0, #low(TIMER0_RELOAD4)
    sjmp    Timer0_ISR_done
Timer0_ISR_not4:
    cjne    a,  #0x03,  Timer0_ISR_not3
    mov     TH0, #high(TIMER0_RELOAD3)
    mov     TL0, #low(TIMER0_RELOAD3)
    sjmp    Timer0_ISR_done
Timer0_ISR_not3:
    cjne    a,  #0x02,  Timer0_ISR_not2
    mov     TH0, #high(TIMER0_RELOAD2)
    mov     TL0, #low(TIMER0_RELOAD2)
    sjmp    Timer0_ISR_done
Timer0_ISR_not2:
    cjne    a,  #0x01,  Timer0_ISR_not1
    mov     TH0, #high(TIMER0_RELOAD1)
    mov     TL0, #low(TIMER0_RELOAD1)
    sjmp    Timer0_ISR_done
Timer0_ISR_not1:
    mov     TH0, #high(TIMER0_RELOAD)
    mov     TL0, #low(TIMER0_RELOAD)
Timer0_ISR_done:
    setb    TR0
    cpl     SOUND_OUT ; Connect speaker to P3.7!
    pop		acc
    reti


;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)

	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	cpl P1.0 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Timer2_ISR_incDone
	inc Count1ms+1

Timer2_ISR_incDone:
    ; Check if [] second has passed
    mov     a,  Count1ms+0
    cjne    a,  #low(TIME_RATE),    Timer2_ISR_done ; Warning: this instruction changes the carry flag!
    mov     a,  Count1ms+1
    cjne    a,  #high(TIME_RATE),   Timer2_ISR_done

    ; toggle sound
    ; CHANGED
   	mov 	a,	sound_pos
    cjne    a,  #0x0A,  Timer2_ISR_inDone_incSound
    mov     sound_pos,  #0x00
    sjmp    Timer2_ISR_inDone_incSound_done
Timer2_ISR_inDone_incSound:
    inc     sound_pos
Timer2_ISR_inDone_incSound_done:
    ; END OF CHANGED

    ;jnb     timer1_flag,    Timer2_ISR_noTimer1
    ;cpl     TR1
;Timer2_ISR_noTimer1:
    ; 500 milliseconds have passed.  Set a flag so the main program knows
    setb    tick_flag ; Let the main program know [] second had passed
    ; Reset to zero the milli-seconds counter, it is a 16-bit variable
    clr     a
    mov     Count1ms+0, a
    mov     Count1ms+1, a

    ; set second
    mov 	a, 	BCD_second
    cjne 	a, 	#0x59,     Timer2_ISR_incSecond
    mov 	a,	#0         ; reset second, increment minute
    da 		a
    mov 	BCD_second,    a

    ; check if alarm is up
    jnb     alarm_toggle_flag,  Timer2_ISR_skipAlarm
    lcall   Timer2_checkAlarm

Timer2_ISR_skipAlarm:
    ; set minute
    mov		a,	BCD_minute
    cjne	a,	#0x59,     Timer2_ISR_incMinute
    mov 	a,  #0         ; reset minute, increment hour
    da		a
    mov 	BCD_minute,    a
    mov 	a,  BCD_hour   ; reset hour, toggle am/pm
    jb 		am_pm_flag,	   Timer2_ISR_PM
    cjne 	a, 	#0x11, Timer2_ISR_incHour
    cjne 	a, 	#0x12, Timer2_ISR_AM11
Timer2_ISR_AM11:
    cpl		am_pm_flag
    sjmp 	Timer2_ISR_incHour
Timer2_ISR_PM:
    cjne	a, 	#0x12, Timer2_ISR_PM12
    mov		a, 	#1
    da		a
    mov		BCD_hour, 	a
    sjmp	Timer2_ISR_done
Timer2_ISR_PM12:
    cjne 	a, 	#0x11, Timer2_ISR_incHour
    cpl		am_pm_flag
    mov 	a,	#0
    da		a
    mov 	BCD_hour,	a
    sjmp    Timer2_ISR_done
Timer2_ISR_incSecond:
    add 	a, 	#0x01
    da 		a
    mov 	BCD_second, a
    sjmp	Timer2_ISR_done
Timer2_ISR_incMinute:
    add		a, 	#0x01
    da		a
    mov		BCD_minute, a
    sjmp	Timer2_ISR_done
Timer2_ISR_incHour:
    add		a, 	#0x01
    da		a
    mov 	BCD_hour,	a
    sjmp	Timer2_ISR_done
Timer2_ISR_done:
    pop psw
    pop acc
    reti

Timer2_checkAlarm:
    ; now would be a good time to check if alarm time == current time
    mov     a,  BCD_hour
    cjne    a,  alarm_hour, Timer2_checkAlarm_done
    mov     a,  BCD_minute
    inc 	a
    da		a
    cjne    a,  alarm_min,  Timer2_checkAlarm_done
    jb      am_pm_flag,	Timer2_checkAlarm_pm
    jb      alarm_ampm_flag,    Timer2_checkAlarm_done
    setb    TR0
    mov     sound_pos,  #0x00
    setb    timer1_flag
    sjmp    Timer2_checkAlarm_done
Timer2_checkAlarm_pm:
    jnb     alarm_ampm_flag,    Timer2_checkAlarm_done
    setb    TR0
    mov     sound_pos,  #0x00
    setb    timer1_flag
    sjmp    Timer2_checkAlarm_done
Timer2_checkAlarm_done:
    ret

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer2_Init
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb    EA              ; Enable Global interrupts
    lcall LCD_4BIT
     ; stop alarm sound
    clr     TR0
    ;clr     TR1
    clr     sound_flag
    ;clr     timer1_flag

    ; set initial message
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)

    ; something important
    setb    tick_flag

    ; alarm is off by default
    clr     alarm_toggle_flag

    ; set mode
    mov		mode,			#0x00

    ; initialize time
    mov     a,  #0x00
    da      a
    mov     BCD_second,     a
    mov     BCD_minute,     a
    mov     BCD_hour,       a
    clr     am_pm_flag
    mov     alarm_hour,     a
    mov     a,  #0x01
    da      a
    mov     alarm_min,      a
    clr     alarm_ampm_flag
    mov 	BCD_date, a
    mov 	BCD_months, a

; After initialization the program stays in this 'forever' loop
loop:
    ; find which mode we are running
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
    clr     c
    mov 	a,  mode
    subb	a, 	#0x03
    jnz		loop_notMode3   ; if mode == 3
    ljmp    mode3
loop_notMode3:
    clr     c
    mov 	a,  mode
    subb	a, 	#0x04
    jnz		loop_notMode4	; if mode == 4
    ljmp    mode4
loop_notMode4:
	; reset mode back to 0
	mov		a, 		#0x00
	mov		mode, 	a
    ljmp    mode0_d
  

mode0:
    jb      BUTTON_BOOT, mode0_a  		       ; if the 'BOOT' button is not pressed skip
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)	       ; Debounce delay.  This macro is also in 'LCD_4bit.inc'
    jb     	BUTTON_BOOT, mode0_a               ; if the 'BOOT' button is not pressed skip
    jnb    	BUTTON_BOOT, $		               ; Wait for button release.  The '$' means: jump to same instruction.
                                               ; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
   	                                           ; But first stop timer 2 and reset the milli-seconds counter, to resync everything.

    ; boot button is pressed here (goto mode 1)
    ; set position variable
    clr    	a
    mov     cursor_pos,  a
    ; setup screen
    Set_Cursor(1, 1)
    Send_Constant_String(#string_mode0)
    ; change mode
    mov     a,      #0x01
    mov     mode,   a
    ljmp   	mode0_d
    
mode0_a:
    jb 		BUTTON_1,	mode0_b_0
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,   mode0_b_0
    jnb     BUTTON_1,   $
    ; button 1 pressed (set alarm) (goto mode 2)
    ; set curosr variable
    jnb     TR0,        mode0_a_setAlarm
    ; when alarm is off, this is the snooze button
    clr     TR0
    ;clr     timer1_flag
    ;clr     TR1
    mov     a,  BCD_minute
    add     a,  #0x01
    da      a
    mov     alarm_min,  a
    ljmp    mode0_d
    
mode0_a_setAlarm:
    clr    	a
    mov     cursor_pos,  a
    ; setup screen
    Set_Cursor(1, 1)
    Send_Constant_String(#string_alarm)
    Set_Cursor(2, 1)
    Send_Constant_String(#string_alarm_hour)
    ; change mode
    mov     a,      #0x02
    mov     mode,   a
    ljmp    loop
    
mode0_b_0:
    jb 		BUTTON_3,	mode0_b_1
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_3,   mode0_b_1
    jnb     BUTTON_3,   $
    ; button 3 pressed (set date) (goto mode 3)
    ; set curosr variable
    jnb     TR0,        mode0_b_0_setDate
    ljmp    mode0_d
mode0_b_0_setDate:
    clr    	a
    mov     cursor_pos,  a
    ; setup screen
    Set_Cursor(1, 1)
    Send_Constant_String(#string_date)
    Set_Cursor(2, 1)
    Send_Constant_String(#string_mode3_date)
    ; change mode
    mov     a,      #0x03
    mov     mode,   a
    ljmp    loop 

mode0_b_1:
    jb 		BUTTON_4,	mode0_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_4,   mode0_b
    jnb     BUTTON_4,   $
    ; button 1 pressed (set alarm) (goto mode 2)
    ; set curosr variable
    jnb     TR0,        mode0_b_1_timer
    ; when alarm is off, this is the snooze button
    ljmp    mode0_d
    
mode0_b_1_timer:
    clr    	a
    mov     cursor_pos,  a
    ; setup screen
    Set_Cursor(1, 1)
    Send_Constant_String(#timer_init)
    Set_Cursor(2, 1)
    Send_Constant_String(#timer4)
    ; change mode
    mov     a,      #0x04
    mov     mode,   a
    ljmp    loop  
     
mode0_b:
    jb      BUTTON_2,   mode0_c
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,   mode0_c
    jb      BUTTON_2,   mode0_b
    jnb     BUTTON_2,   $
    ; button 2 pressed (turn off alarm (when on), toggle when off)
    jnb     TR0,        mode0_b_toggleAlarm
    ; do the following when alarm is on
    clr     TR0
    clr     timer1_flag
    clr     TR1
    sjmp    mode0_d
mode0_b_toggleAlarm:
    cpl     alarm_toggle_flag
    sjmp    mode0_d
    
mode0_c:
    jb		tick_flag,	mode0_d
    ljmp	loop

mode0_d:
    clr    	tick_flag ; We clear this flag in the main ; display every second
    Set_Cursor(2, 1)
  	Send_Constant_String(#string_date)
    Set_Cursor(2, 6)
    Display_BCD(BCD_months)
    Set_Cursor(2, 9)
    Display_BCD(BCD_date)
    Set_Cursor(1, 1)
    Display_BCD(BCD_hour)
    Set_Cursor(1, 4)
    Display_BCD(BCD_minute)
    Set_Cursor(1, 7)
    Display_BCD(BCD_second)
    Set_Cursor(1, 10)
    jb 		am_pm_flag, mode0_setpm
    Display_char(#'A')
    sjmp	mode0_setAlarm
mode0_setpm:
    Display_char(#'P')
    sjmp    mode0_setAlarm
mode0_setAlarm:
    Set_Cursor(1, 16)
    jb      alarm_toggle_flag,  mode0_setAlarmOn
    Display_char(#' ')
    ljmp    loop
mode0_setAlarmOn:
    Display_char(#'!')
    ljmp    loop

;===[MODE 1]===
mode1:
    ; Clock time set mode
    jb      BUTTON_BOOT,    mode1_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_BOOT,    mode1_a
    jnb     BUTTON_BOOT,    $
    ; valid boot button register (save and go back to mode 0)
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    mov     a,      #0x00
    mov     mode,   a
    ljmp    mode1_d
mode1_a:
    jb      BUTTON_1,       mode1_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,       mode1_b
    jnb     BUTTON_1,       $
    ; valid button 1: change position
    mov     a,  cursor_pos
    cjne    a,  #0x02,  mode1_a_inc
    mov     cursor_pos,  #0x00
    ljmp    mode1_d
mode1_a_inc:
    inc     cursor_pos
    ljmp    mode1_d
mode1_b:
    jb      BUTTON_2,       mode1_c
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode1_c
    jnb     BUTTON_2,       $
    ; valid button 2: increment current position value
    clr     c
    mov     a,  cursor_pos
    jz      mode1_b_setHours
    subb    a,  #0x01
    jz      mode1_b_setMinutes
    ; set seconds, also resync timer
    clr     TR2
    clr     a
    mov     Count1ms+0, a
    mov     Count1ms+1, a
    mov     BCD_second, #0x00
    setb    TR2
    sjmp    mode1_d
mode1_b_setHours:
    ; increment hours
    mov 	a,  BCD_hour   ; reset hour, toggle am/pm
    jb 		am_pm_flag,	   mode1_b_setHours_PM
    cjne 	a, 	#0x11,     mode1_b_setHours_incHour
    cjne 	a, 	#0x12,     mode1_b_setHours_AM11
mode1_b_setHours_AM11:
    cpl		am_pm_flag
    sjmp 	mode1_b_setHours_incHour
mode1_b_setHours_PM:
    cjne	a, 	#0x12, mode1_b_setHours_PM12
    mov		a, 	#1
    da		a
    mov		BCD_hour, 	a
    sjmp	mode1_d
mode1_b_setHours_PM12:
    cjne 	a, 	#0x11, mode1_b_setHours_incHour
    cpl		am_pm_flag
    mov 	a,	#0
    da		a
    mov 	BCD_hour,	a
    sjmp    mode1_d
mode1_b_setHours_incHour:
    add		a, 	#0x01
    da		a
    mov 	BCD_hour,	a
    sjmp    mode1_d
mode1_b_setMinutes:
    ; increment minutes
    mov     a,  BCD_minute
    cjne    a,  #0x59,  mode1_b_setMinutes_inc
    mov     BCD_minute, #0x00
    sjmp    mode1_d
mode1_b_setMinutes_inc:
    add     a, 	#0x01
    da		a
    mov		BCD_minute,	a
    sjmp    mode1_d
mode1_c:
    jb		tick_flag,	mode1_d
    ljmp	loop
mode1_d:
    clr    	tick_flag
    ; display cursor
    Set_Cursor(2, 1)
    clr     c
    mov     a,  cursor_pos
    jz      mode1_d_setHours
    subb    a,  #0x01
    jz      mode1_d_setMinutes
    Send_Constant_String(#string_mode1_sec)
    sjmp    mode1_d_display
mode1_d_setHours:
    Send_Constant_String(#string_mode1_hour)
    sjmp    mode1_d_display
mode1_d_setMinutes:
    Send_Constant_String(#string_mode1_min)
    sjmp	mode1_d_display
mode1_d_display:
    ; display rest
    Set_Cursor(1, 1)
    Display_BCD(BCD_hour)
    Set_Cursor(1, 4)
    Display_BCD(BCD_minute)
    Set_Cursor(1, 7)
    Display_BCD(BCD_second)
    Set_Cursor(1, 10)
    jb 		am_pm_flag, mode1_setpm
    Display_char(#'A')
    ljmp	loop
mode1_setpm:
    Display_char(#'P')
    ljmp    loop

;===[MODE 2]===
mode2:
    jb      BUTTON_BOOT,    mode2_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_BOOT,    mode2_a
    jnb     BUTTON_BOOT,    $
    ; boot button functions (save alarm)
    ; set screen
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    ; change mode back to 0
    mov     a,      #0x00
    mov     mode,   a
    ljmp    loop
mode2_a:
    jb      BUTTON_1,       mode2_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,       mode2_b
    jnb     BUTTON_1,       $
    ; button 1 function (next pos)
    mov     a,  cursor_pos
    cjne    a,  #0x02,  mode2_a_inc
    mov     cursor_pos, #0x00
    sjmp    mode2_d
mode2_a_inc:
    inc     cursor_pos
    ljmp    mode2_d
mode2_b:
    jb      BUTTON_2,       mode2_c
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode2_c
    jnb     BUTTON_2,       $
    ; button 2 function (increment)
    clr     c
    mov     a,  cursor_pos
    jz      mode2_b_setHours
    subb    a,  #0x01
    jz      mode2_b_setMinutes
    ; set am pm
    cpl     alarm_ampm_flag
    mov 	R0,	alarm_hour
    cjne    R0, #0x12,  mode2_b_hourNot12
    jb      alarm_ampm_flag,	mode2_d
    ; if 12 and am, change to 00
    mov     a,  #0x00
    da      a
    mov     alarm_hour, a
    sjmp    mode2_d
mode2_b_hourNot12:
    cjne    R0, #0x00,  mode2_d
    jnb      alarm_ampm_flag,   mode2_d
    ; if 0 and pm, change to 12
    mov     a,  #0x12
    da      a
    mov     alarm_hour, a
    sjmp    mode2_d
mode2_b_setHours:
    mov     a,  alarm_hour
    cjne    a,  #0x12, mode2_b_setHours_inc
    mov     a,  #0x01
    da      a
    mov     alarm_hour, a
    sjmp    mode2_d
mode2_b_setHours_inc:
    add     a,  #0x01
    da      a
    mov     alarm_hour, a
    sjmp    mode2_d
mode2_b_setMinutes:
    mov     a,  alarm_min
    cjne    a,  #0x59,  mode2_b_setMinutes_inc
    mov     a,  #0x00
    da      a
    mov     alarm_min,  a
    sjmp    mode2_d
mode2_b_setMinutes_inc:
    add     a,  #0x01
    da      a
    mov     alarm_min, a
    sjmp    mode2_d
mode2_c:
    jb		tick_flag,	mode2_d
	ljmp	loop
mode2_d:
    clr    	tick_flag
    ; display cursor
    Set_Cursor(2, 1)
    clr     c
    mov     a,  cursor_pos
    jz      mode2_d_setHours
    subb    a,  #0x01
    jz      mode2_d_setMinutes
    Send_Constant_String(#string_alarm_ampm)
    sjmp    mode2_d_display
mode2_d_setHours:
    Send_Constant_String(#string_alarm_hour)
    sjmp    mode2_d_display
mode2_d_setMinutes:
    Send_Constant_String(#string_alarm_min)
    sjmp	mode2_d_display
mode2_d_display:
    Set_Cursor(1, 1)
    Display_BCD(alarm_hour)
    Set_Cursor(1, 4)
    Display_BCD(alarm_min)
    Set_Cursor(1, 7)
    jb 		alarm_ampm_flag, mode2_setpm
    Display_char(#'A')
    ljmp	loop
mode2_setpm:
    Display_char(#'P')
    ljmp    loop

;----------------------
mode3:
    jb      BUTTON_BOOT,    mode3_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_BOOT,    mode3_a
    jnb     BUTTON_BOOT,    $
    ; boot button functions (save alarm)
    ; set screen
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    ; change mode back to 0
    mov     a,      #0x00
    mov     mode,   a
    ljmp    loop
mode3_a:
; button 1 function (next pos)
    jb      BUTTON_1,       mode3_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_1,       mode3_b
    jnb     BUTTON_1,       $
    
    mov     a,  cursor_pos
    cjne    a,  #0x02,  mode3_a_inc
    mov     cursor_pos, #0x00
    sjmp    mode3_d
mode3_a_inc:
    inc     cursor_pos
    ljmp    mode3_d
mode3_b:
 ; button 2 function (increment)
    jb      BUTTON_2,       mode3_c
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_2,       mode3_c
    jnb     BUTTON_2,       $
    clr     c
    mov     a,  cursor_pos
    jz      mode3_b_setDate
    subb    a,  #0x01
    jz      mode3_b_setMonths
mode3_b_setDate:
    mov     a,  BCD_date
    cjne    a,  #0x31, mode3_b_setDate_inc
    mov     a,  #0x01
    da      a
    mov     BCD_date, a
    sjmp    mode3_d
mode3_b_setDate_inc:
    add     a,  #0x01
    da      a
    mov     BCD_date, a
    sjmp    mode3_d
mode3_b_setMonths:
    mov     a,  BCD_months
    cjne    a,  #0x12,  mode3_b_setMonths_inc
    mov     a,  #0x00
    da      a
    mov     BCD_months,  a
    sjmp    mode3_d
mode3_b_setMonths_inc:
    add     a,  #0x01
    da      a
    mov     BCD_months, a
    sjmp    mode3_d
mode3_c:
    jb		tick_flag, mode3_d
	ljmp	loop
mode3_d:
    clr    	tick_flag
    ; display cursor
    Set_Cursor(2, 1)
    clr     c
    mov     a,  cursor_pos
    jz      mode3_d_setDates
    subb    a,  #0x01
    jz      mode3_d_setMonths
    sjmp    mode3_d_display
mode3_d_setDates:
    Send_Constant_String(#string_mode3_date)
    sjmp    mode3_d_display
mode3_d_setMonths:
    Send_Constant_String(#string_mode3_month)
    sjmp	mode3_d_display
mode3_d_display:
    Set_Cursor(1, 9)
    Display_BCD(BCD_date)
    Set_Cursor(1, 6)
    Display_BCD(BCD_months)
    ljmp	loop

;---------------------
mode4:
    jb      BUTTON_BOOT,    mode4_a
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_BOOT,    mode4_a
    jnb     BUTTON_BOOT,    $
    ; boot button functions (save alarm)
    ; set screen
    Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    ; change mode back to 0
    mov     a,      #0x00
    mov     mode,   a
    ljmp    loop
mode4_a:
    jb      BUTTON_5,    mode4_b
    Wait_Milli_Seconds(#DEBOUNCE_DELAY)
    jb      BUTTON_5,    mode4_b
    jnb     BUTTON_5,    $
    
	Set_Cursor(2, 5)
    Display_BCD(BCD_hour)
    Set_Cursor(2, 8)
    Display_BCD(BCD_minute)
    Set_Cursor(2, 11)
    Display_BCD(BCD_second)
    ljmp    loop
mode4_b:

	Set_Cursor(1, 5)
    Display_BCD(BCD_hour)
    Set_Cursor(1, 8)
    Display_BCD(BCD_minute)
    Set_Cursor(1, 11)
    Display_BCD(BCD_second)
    
    ljmp    loop

END
