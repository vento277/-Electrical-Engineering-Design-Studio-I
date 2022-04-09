// Coin Pick up Robot
// Basic: Pick up 20 coins, 4 of each type
// Extra:
//		LED displaying the number of coins it picked up.
//		Draw a heart shape using the coins that it picked up.

#include "samd20.h"
#include "nvm_data.h"
#include <stdio.h>

#define PE 4  // Prescaler as configured in REC_TC3_CTRLA
#define RATE 100000 // in Hz.  We want to interrupt every 10us
#define TC3_RELOAD (((F_CPU/PE)/RATE)-1)
#define WHITE PORT_PA19
#define RED PORT_PA24
#define YELLOW PORT_PA25
#define GREEN PORT_PA27
#define BLUE PORT_PA28

#if (TC3_RELOAD > 255)
#error TC3_RELOAD is greater than 255
#endif

volatile int ISR_pwm1=150, ISR_pwm2=150, ISR_cnt=0;

unsigned char* ARRAY_PORT_PINCFG0 = (unsigned char*)&REG_PORT_PINCFG0;
unsigned char* ARRAY_PORT_PMUX0 = (unsigned char*)&REG_PORT_PMUX0;

int detect_coin(int ctr_period);
int get_perimeter_reading();
void init_Clock48();
void UART3_init(uint32_t baud);
void printString (char * s);
void printNum(uint32_t v, int base, int digits);
void turn_around(int t);
void coin_pickup_reverse();
void coin_pickup();
void servo_arm(int n, int m);
void servo_leg(int g, int h);
void move_forward();
void move_backward();
void move_stop();
void coin_pickup_modified();
int initial_period(int n);
void coin_deposit(int coin);
void move_turn(int x);
void move_turn_2(int x);
void move_turn_left();
void heart();
void servo_arm_slow(int xinitial, int xfinal, int yinitial, int yfinal);

void Configure_TC2_servo ()
{
    REG_GCLK_CLKCTRL = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | GCLK_CLKCTRL_ID_TC2_TC3;
    REG_PM_APBCMASK |= PM_APBCMASK_TC2; // Enable TC2 bus clock
    
    REG_TC2_CTRLA = 1;              /* Software Reset */
    while (REG_TC2_CTRLA & 1) {}    /* Wait till out of reset */
    REG_TC2_CTRLA = 0x0560;         /* Prescaler: GCLK_TC/64, 16-bit mode, MPWM.  Check page 490*/
    REG_TC2_COUNT16_CC0 = (F_CPU/(64*50))-1; /* Match value 0 */
    REG_TC2_CTRLA |= 2;             /* Enable */

	REG_TC2_COUNT16_CC1 = (F_CPU/(64*50*20))-1;

    /* Enable & configure alternate function F for pin PA17 (pin 18) Page 22*/
    PORT->Group[0].PINCFG[17].bit.PMUXEN = 1;
    PORT->Group[0].PMUX[8].reg = 0x50;
}

void Configure_TC3_servo ()
{
    REG_GCLK_CLKCTRL = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | GCLK_CLKCTRL_ID_TC2_TC3;
    REG_PM_APBCMASK |= PM_APBCMASK_TC3; // Enable TC3 bus clock
    
    REG_TC3_CTRLA = 1;              /* Software Reset */
    while (REG_TC3_CTRLA & 1) {}    /* Wait till out of reset */
    REG_TC3_CTRLA = 0x0560;         /* Prescaler: GCLK_TC/64, 16-bit mode, MPWM.  Check page 490*/
    REG_TC3_COUNT16_CC0 = (F_CPU/(64*50))-1; /* Match value 0 */
    REG_TC3_CTRLA |= 2;             /* Enable */

	REG_TC3_COUNT16_CC1 = (F_CPU/(64*50*20))-1;

    /* Enable & configure alternate function E for pin PA15 (pin 16) Page 22*/
    PORT->Group[0].PINCFG[15].bit.PMUXEN = 1;
    PORT->Group[0].PMUX[7].reg = 0x40;
}

void Configure_TC3 (void)
{
    __disable_irq();
    // Configure Clocks
    REG_GCLK_CLKCTRL = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | GCLK_CLKCTRL_ID_TC2_TC3;
    REG_PM_APBCMASK |= PM_APBCMASK_TC3; // Enable TC3 bus clock
    REG_TC3_CTRLA = 1;              // reset TC3 before configuration
    while (REG_TC3_CTRLA & 1);      // wait till out of reset
    REG_TC3_CTRLA = 0x0204;         // prescaler /64, 8-bit mode, NFRQ. Check page 681 of datasheet
    REG_TC3_COUNT8_PER=TC3_RELOAD;  // TOP count value in 8-bit mode
    REG_TC3_CTRLA |= 2;             // enable TC3
    REG_TC3_INTENSET = 1;           // enable overflow interrupt
    NVIC_EnableIRQ(TC3_IRQn);       // enable TC3 interrupt in NVIC
    __enable_irq();                 // enable interrupt globally

}

void TC2_Handler(void)
{
    REG_TC2_INTFLAG = 1; // clear OVF flag
    
	ISR_cnt++;
	if(ISR_cnt==ISR_pwm1)
	{
		REG_PORT_OUTCLR0 = PORT_PA08;
	}
	if(ISR_cnt==ISR_pwm2)
	{
		REG_PORT_OUTCLR0 = PORT_PA09;
	}
	if(ISR_cnt>=2000)
	{
		ISR_cnt=0; // 2000 * 10us=20ms
		REG_PORT_OUTSET0 = PORT_PA08;
		REG_PORT_OUTSET0 = PORT_PA09;
	}	
}

void TC3_Handler(void)
{
    REG_TC3_INTFLAG = 1; // clear OVF flag
    
	ISR_cnt++;
	if(ISR_cnt==ISR_pwm1)
	{
		REG_PORT_OUTCLR0 = PORT_PA08;
	}
	if(ISR_cnt==ISR_pwm2)
	{
		REG_PORT_OUTCLR0 = PORT_PA09;
	}
	if(ISR_cnt>=2000)
	{
		ISR_cnt=0; // 2000 * 10us=20ms
		REG_PORT_OUTSET0 = PORT_PA08;
		REG_PORT_OUTSET0 = PORT_PA09;
	}	
}

uint32_t GetPeriod (void)
{
    int i;
    // Configure SysTick
    SysTick->LOAD = 0xffffff; // Reload with max number of clocks (SysTick is 24-bit)
    SysTick->VAL = 0;         // clear current value register
    SysTick->CTRL = 0x5;      // Enable the timer

    while ((REG_PORT_IN0 & PORT_PA14)!=0) // Wait for zero
    {
    	if (SysTick->CTRL & 0x10000) return 0xffffffffL;
    }
    while ((REG_PORT_IN0 & PORT_PA14)==0) // Wait for one
    {
    	if (SysTick->CTRL & 0x10000) return 0xffffffffL;
    }
    SysTick->CTRL = 0; // Stop the timer (Enable = 0)


    // Configure SysTick again
    SysTick->LOAD = 0xffffff;  // Reload with max number of clocks (SysTick is 24-bit)
    SysTick->VAL = 0;          // clear current value register
    SysTick->CTRL = 0x5;       // Enable the timer

    for(i = 0; i < 100; i++)
    {
	    while ((REG_PORT_IN0 & PORT_PA14)!=0)
	    {
	    	if (SysTick->CTRL & 0x10000) return 0xffffffffL;
	    }
	    while ((REG_PORT_IN0 & PORT_PA14)==0)
	    {
	    	if (SysTick->CTRL & 0x10000) return 0xffffffffL;
	    }
    }
    SysTick->CTRL = 0; // Stop the timer (Enable = 0)
    return (0xffffff-SysTick->VAL);
}

void delayMs(int n)
{
    int i;
    // Configure SysTick
    SysTick->LOAD = (F_CPU/1000L) - 1; // Reload with number of clocks per millisecond
    SysTick->VAL = 0;         // clear current value register
    SysTick->CTRL = 0x5;      // Enable the timer

    for(i = 0; i < n; i++)
    {
        while((SysTick->CTRL & 0x10000) == 0); // wait until the COUNTFLAG is set
    }
    SysTick->CTRL = 0; // Stop the timer (Enable = 0)
}

void ADC_init (void)
{
	PM->APBCMASK.reg |= PM_APBCMASK_ADC; // enable bus clock for ADC
	GCLK->CLKCTRL.reg = GCLK_CLKCTRL_ID(ADC_GCLK_ID) |	GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN(0); // GCLK0 to ADC
	
    REG_ADC_SAMPCTRL = 10;       // sampling time 10 clocks
      
    ARRAY_PORT_PINCFG0[3] |= 1; // Use PMUX for PA03
    ARRAY_PORT_PMUX0[1] = 0x10; // PA03 = VREFA
    REG_ADC_REFCTRL = 3;        // Use VREFA
    
    //REG_ADC_REFCTRL = 0x80 | 0x02; // Reference buffer offset compensation is enabled; Reference Selection=VDDANA/2
    REG_ADC_CTRLB |= 0x0700; // clock pre-scaler is: Peripheral clock divided by 512
    
    REG_ADC_INPUTCTRL = 0x1805; // V- = GND; V+ = AIN5
    ARRAY_PORT_PINCFG0[4] |= 1; // Use PMUX for PA04
    ARRAY_PORT_PINCFG0[5] |= 1; // Use PMUX for PA05
    ARRAY_PORT_PMUX0[2] = 0x11; // PA04 = AIN4, PA05 = AIN5 (low nibble is for AIN4, high nibble is for AIN5)
    
    REG_ADC_CALIB = ADC_CALIB_BIAS_CAL(NVM_READ_CAL(ADC_BIASCAL)) |
                    ADC_CALIB_LINEARITY_CAL(NVM_READ_CAL(ADC_LINEARITY));

    REG_ADC_CTRLA = 2;          // enable ADC
}

int ADC_read (unsigned int channel)
{
    int result;

    REG_ADC_INPUTCTRL = 0x1800 | channel; // V- = GND; V+ = channel (either 4 or 5 as configured above)
    
    REG_ADC_SWTRIG = 2;             // start a conversion
    while(!(REG_ADC_INTFLAG & 1));  // wait for conversion complete
    result = REG_ADC_RESULT;        // read conversion result
    
    return result;
}

void ConfigurePins (void)
{
	// Configure input pins
    REG_PORT_DIRCLR0 = PORT_PA14; // Period surbroutine input pin
    ARRAY_PORT_PINCFG0[14] |= 6;  // enable PA15 input buffer with pull
    REG_PORT_OUTSET0 = PORT_PA14; // PA15 pull-up
    
    //votlage input
    //REG_PORT_DIRCLR1 = PORT_PA13; // Voltage surbroutine input pin
    //ARRAY_PORT_PINCFG0[13] |= 6;  // enable PA15 input buffer with pull
    //REG_PORT_OUTSET1 = PORT_PA13; // PA15 pull-up
    
    // Configure output pins
    REG_PORT_DIRSET0 = PORT_PA00; // Configure PA00 as output.  This is pin 1 of the LQFP32 package.
    REG_PORT_DIRSET0 = PORT_PA01; // Configure PA01 as output.  This is pin 2 of the LQFP32 package.
    REG_PORT_DIRSET0 = PORT_PA02;
    REG_PORT_DIRSET0 = PORT_PA03;  // Configure PA02 as output.  This is pin 3 of the LQFP32 package.
    REG_PORT_DIRSET0 = PORT_PA06; // Configure PA06 as output.  This is pin 7 of the LQFP32 package.
    REG_PORT_DIRSET0 = PORT_PA07; // Configure PA07 as output.  This is pin 8 of the LQFP32 package.
    REG_PORT_DIRSET0 = PORT_PA08; // Configure PA08 as output.  This is pin 11 of the LQFP32 package.
    REG_PORT_DIRSET0 = PORT_PA09; // Configure PA09 as output.  This is pin 12 of the LQFP32 package.
}


/*-----------------------------------------------------------------
//converts decimal to binary
//input: decimal number
//output: binary number
-----------------------------------------------------------------*/
int DecimalToBinary(int decimalnum)
{
    int binarynum = 0;
    int remainder, temp = 1;

    while (decimalnum!=0)
    {
        remainder = decimalnum % 2;
        decimalnum = decimalnum / 2;
        binarynum = binarynum + remainder * temp;
        temp = temp * 10;
    }

    return binarynum;
}

/*-----------------------------------------------------------------
//converts integer number into array
//input: integer number
//output: integer array
-----------------------------------------------------------------*/
void int_to_arr(int number, int array[5]){

    for (int i = 0; i < 5; i++){
        array[i] = number % 10;
        number = number / 10;
    }

}

//BLOCK DIAGRAM: https://docs.google.com/drawings/d/1T3Urse6BNoc9c-jF8palLSMFl9NvYzkgg40_ldZfCOA/edit
int main(void)
{
    init_Clock48();
    UART3_init(115200);
    ADC_init();
    ConfigurePins();
	Configure_TC2_servo();
    Configure_TC3();
	Configure_TC3_servo();
	
	int ctr_period;
	int coin_bits[5];
	int binary_coin_count;
	
    int x, y, coins;
    x = 125; // 125 is middle for servo_arm
    y = 180; // 180 is middle for servo_arm
    coins = 0;
    
	//configure pin
	REG_PORT_DIRCLR0 = PORT_PA19;
	REG_PORT_DIRCLR0 = PORT_PA24;
	REG_PORT_DIRCLR0 = PORT_PA25;
	REG_PORT_DIRCLR0 = PORT_PA27;
	REG_PORT_DIRCLR0 = PORT_PA28;	
	
	//setting initial arm position 
	servo_arm(x-20,y);
	//setting initial control period
	ctr_period = initial_period(3000);


	//main loop while picking up coins	
	while (coins < 20){
	
		move_forward();
	
		if(get_perimeter_reading()){
			move_backward();
			delayMs(300);
			move_turn(820);
			//printf("Getting pri\n\r");
		}
		
		//wait and see method for detecting coin
		if(detect_coin(ctr_period)){
			delayMs(10);
			if(detect_coin(ctr_period)){
				delayMs(10);
				if(detect_coin(ctr_period)){

					//set LEDs to reflect new coin value
					coins++;
					binary_coin_count = DecimalToBinary(coins); //convert decimal to binary
					int_to_arr(binary_coin_count, coin_bits);
					if (coin_bits[0] == 1) {
						REG_PORT_DIRSET0 = WHITE;
					}
				
					else {
						REG_PORT_DIRCLR0 = WHITE;
					}
				
					if (coin_bits[1] == 1) {
						REG_PORT_DIRSET0 = RED;
					}
				
					else {
						REG_PORT_DIRCLR0 = RED;
					}
				
					if (coin_bits[2] == 1) {
						REG_PORT_DIRSET0 = YELLOW;
					}
				
					else {
						REG_PORT_DIRCLR0 = YELLOW;
					}
				
					if (coin_bits[3] == 1) {
						REG_PORT_DIRSET0 = GREEN;
					}
				
					else {
						REG_PORT_DIRCLR0 = GREEN;
					}
				
					if (coin_bits[4] == 1) {
						REG_PORT_DIRSET0 = BLUE;
					}
				
					else {
						REG_PORT_DIRCLR0 = BLUE;
					}

					move_stop();
					move_backward();
					delayMs(200);
					move_stop();
			
					coin_pickup();

					//after collecting coin return to initial position and set new ctrl period
					ctr_period = initial_period(2000);
		
				
					//checks how many coins in each box and decides where to put coin
				
					if(coins <= 8){
						coin_pickup();
						//printf("Doing coin pickup\n\r");
					}
				
					else{
						coin_pickup_modified();
						//printf("Doing coin pickup mod\n\r");
					}
				}
			}
		}	
	}
	
	delayMs(1000);

	//get away from the perimeter
	move_forward();
	delayMs(2000)l
	
	//draw a heart
	heart();
	
	// move the robot backwards so the heart is observable
	move_backward();
	delayMs(2000);  
	
	//when coins = 20, stop and enter infinite loop
	move_stop();
}

/*---------------------------------------------------------
//Deposits coins in a heart shape
//inputs: none
//outputs: none
---------------------------------------------------------*/
void heart(){
	int coins;
    coins = 0;
	
	coin_deposit(coins);
	coins++;
	move_forward();
	delayMs(500);
	move_stop();
	coin_deposit(coins);
	coins++;
	
	move_backward();
	delayMs(700);
	move_turn(670);
	move_forward();
	delayMs(400);
	move_turn_2(670);
	move_stop(); 
	
	
	coin_deposit(coins);
	coins++;
	move_forward();
	delayMs(1000);
	move_stop();
	coin_deposit(coins);
	coins++;
	
	
	move_backward();
	delayMs(1200);
	move_turn(670);
	move_forward();
	delayMs(440);
	move_turn_2(670);
	move_stop();
	
	
	coin_deposit(coins);
	coins++;
	move_forward();
	delayMs(900);
	move_stop();
	coin_deposit(coins);
	coins++;
	
	move_backward();
	delayMs(1000);
	move_turn(640);
	move_forward();
	delayMs(470);
	move_turn_2(640);
	move_forward();
	delayMs(370);
	move_stop();
	
	coin_deposit(coins);
	coins++;
	move_forward();
	delayMs(1000);
	move_stop();
	coin_deposit(coins);
	coins++;
	
	
	move_backward();
	delayMs(1000);
	move_turn(640);
	move_forward();
	delayMs(370);
	move_turn_2(620);
	move_forward();
	delayMs(500);
	move_stop();
	
	
	coin_deposit(coins);
	coins++;
	move_forward();
	delayMs(500);
	move_stop();
	coin_deposit(coins);
	coins++;

	
}

/*-----------------------------------------------------------------
//checks for perimeter wire, if detected, returns 1
//input: none
//output: 1 if wire detected, else 0
-----------------------------------------------------------------*/
int get_perimeter_reading(){
   
   int voltage_1; //control voltage (voltage reading when tank circuit is not close to perimeter wire)
   int voltage_2;
   voltage_1 = ADC_read(4);
   voltage_2 = ADC_read(5);
   delayMs(10);
   if(voltage_1 > 100 || voltage_2 > 100)
   {
   		
  	  	voltage_1 = ADC_read(4);
   		voltage_2 = ADC_read(5);

   		if(voltage_1 > 100 || voltage_2 > 100)
   		{		
		return 1;
   		}
   	}
   
   return 0;
	
}


/*-----------------------------------------------------------------
//checks for coin, if detected, returns 1
//input: none
//output: 1 if coin detected, else 0
-----------------------------------------------------------------*/
int detect_coin(int ctr_period){
 	int period;

   	period=GetPeriod();//(F_CPU*100.0); // We are measuring the time of 100 full periods

   	delayMs(10);
   	   	
   	if(period < ctr_period - 14)
   	{

   		return 1;
   	}
   	
   	return 0; 	
   	
 }
 
 int initial_period(int n){
 
 	delayMs(200);
 	int ctr_period = GetPeriod();
 	int ctr_period_low = ctr_period;
 	
 	for (int i = 0; i < n; i++)
 	{
 		ctr_period = GetPeriod();
 		//printNum(ctr_period_low,10,5);
 		//printf("\r\n");
 		if(ctr_period < ctr_period_low)
 		{
 			ctr_period_low = ctr_period;
 		}
 	}

 	return ctr_period_low;
 }


/*-----------------------------------------------------------------
//moves the robot
//input: none
//output: none
-----------------------------------------------------------------*/
void move_forward(){
	REG_PORT_OUTSET0 = PORT_PA00;
    REG_PORT_OUTCLR0 = PORT_PA01;
    REG_PORT_OUTSET0 = PORT_PA06;
    REG_PORT_OUTCLR0 = PORT_PA07; 
}

void move_backward(){
	REG_PORT_OUTCLR0 = PORT_PA00;
    REG_PORT_OUTSET0 = PORT_PA01;
    REG_PORT_OUTCLR0 = PORT_PA06;
    REG_PORT_OUTSET0 = PORT_PA07;
}
    
void move_stop(){
	REG_PORT_OUTCLR0 = PORT_PA00;
    REG_PORT_OUTCLR0 = PORT_PA01;
    REG_PORT_OUTCLR0 = PORT_PA06;
    REG_PORT_OUTCLR0 = PORT_PA07;
}
    
void move_turn_right(){
	move_stop();
    REG_PORT_OUTSET0 = PORT_PA01;
    REG_PORT_OUTSET0 = PORT_PA06;
    REG_PORT_OUTCLR0 = PORT_PA07;
    REG_PORT_OUTCLR0 = PORT_PA00;
    delayMs(775);
    move_stop();
}
    
void move_turn_left(){
	move_stop();
    REG_PORT_OUTCLR0 = PORT_PA01;
    REG_PORT_OUTCLR0 = PORT_PA06;
    REG_PORT_OUTSET0 = PORT_PA07;
    REG_PORT_OUTSET0 = PORT_PA00;
    delayMs(775);
    move_stop();	
}
    
void move_turn(int x){
	move_stop();
    REG_PORT_OUTSET0 = PORT_PA01;
    REG_PORT_OUTSET0 = PORT_PA06;
    REG_PORT_OUTCLR0 = PORT_PA07;
    REG_PORT_OUTCLR0 = PORT_PA00;
    delayMs(x);
    move_stop();
}

    
void move_turn_2(int x){
	move_stop();
    REG_PORT_OUTCLR0 = PORT_PA01;
    REG_PORT_OUTCLR0 = PORT_PA06;
    REG_PORT_OUTSET0 = PORT_PA07;
    REG_PORT_OUTSET0 = PORT_PA00;
    delayMs(x);
    move_stop();
}



/*---------------------------------------------------------------
Moves the servo arm from initial position to final position with delays
in betweeen to slow down motion
inputs: xinitial, xfinal, yinital, yfinal
outputs: none
---------------------------------------------------------------*/
void servo_arm_slow(int xinitial, int xfinal, int yinitial, int yfinal){	
	
	int x = 125; // 125 is middle for servo_arm
    int y = 180; // 180 is middle for servo_arm
	
	servo_arm(x+xinitial,y+yinitial);
	
	delayMs(80);
	
	//checks starting location and decides which direction to turn
	if(xinitial > xfinal){

		//moves position incrementally with delay in between each loop
		for(int i = xinitial; i != xfinal; i--){
			servo_arm(x+i,y + yinitial);
			delayMs(9);
	}
	
	}
	else{
		for(int i = xinitial; i != xfinal; i++){
			servo_arm(x+i,y + yinitial);
			delayMs(9);
		}
	}
	
	delayMs(80);
	
	//similar process for y motor, decides which position to turn and moves incrementally
	if(yinitial>yfinal){
		for(int i = yinitial; i != yfinal; i--){
			servo_arm(x+xfinal,y+i);
			delayMs(4);
		}
	}
	else{
		for(int i = yinitial; i != yfinal; i++){
			servo_arm(x+xfinal,y+i);
			delayMs(4);
		}
	}
	
	servo_arm(x+xfinal, y+yfinal);
}

/*-----------------------------------------------------------------
//operate the servos to pick up the coin and place in metal box (60[=0] ~ 240[=180])
//input: none
//output: none
-----------------------------------------------------------------*/
void coin_pickup() {
	int x = 125; // 125 is middle for servo_arm
    int y = 180; // 180 is middle for servo_arm
    
    servo_arm(x,y+50);
    delayMs(400);
    servo_arm_slow(93,93, 50, -25);
    delayMs(700);
    REG_PORT_OUTSET0 = PORT_PA02;
    delayMs(700);
    servo_arm_slow(93,93, -25, 55);
    delayMs(750);
    servo_arm_slow(93,-30, 55, 55);
    delayMs(750);
    servo_arm_slow(-30,-30, 55, -29);
    delayMs(1000);
    REG_PORT_OUTCLR0 = PORT_PA02;
    
    // return to oritinal position
 	delayMs(400);
 	servo_arm(x-20, y);
}

void coin_pickup_modified(){
	int x = 125; // 125 is middle for servo_arm
    int y = 180; // 180 is middle for servo_arm
    
	//swing motor down to start position
    servo_arm(x-10,y+50);
    delayMs(400);
    servo_arm(x+93, y+50);
    delayMs(700);

	//turn on magnet and sweep horizontally
    REG_PORT_OUTSET0 = PORT_PA02;
    delayMs(800);
    servo_arm_slow(93,93, 50, -25);
    delayMs(800);

	//move up into box and drop
    servo_arm_slow(93,93, -25, 55);
    delayMs(800);
    servo_arm_slow(93,-25, 55, 55);
    delayMs(800);
    servo_arm_slow(-25,-25, 55, 5);
    delayMs(800);
    REG_PORT_OUTCLR0 = PORT_PA02;
   
   	// return to original position
    delayMs(400);
    servo_arm(x-20,y);
}

/*-------------------------------------------------------
takes a coin from box and drops it at specified location
inputs: coins - keeps track of coin stack height to determine how deep in box to go
outputs: none
-------------------------------------------------------*/
void coin_deposit(int coin){

	int x = 125; // 125 is middle for servo_arm
    int y = 180; // 180 is middle for servo_arm
    int YPOS = y + 16 - 2*coin; //counter to keep track of how deep stack is and where to move motor
    
	//move into box to pickup coin
    servo_arm(x-20,y);
    delayMs(500);
    servo_arm(x-20, YPOS);
    delayMs(500);
    servo_arm(x+20, YPOS); 
    delayMs(500);
	//turn on magnet
    REG_PORT_OUTSET0 = PORT_PA02;

	//move out arm to position in front of robot
    delayMs(500);
    servo_arm(x-35, YPOS); 
    delayMs(500);
    servo_arm(x-35, y+45);
    delayMs(500);
    servo_arm(x+90, y+45);
    delayMs(500);
    servo_arm(x+90, y);
    delayMs(500);

	//turn off magnet to drop coin and return to start
    REG_PORT_OUTCLR0 = PORT_PA02;
    delayMs(500);
    servo_arm(x+90, y+45);
    delayMs(500);
    servo_arm(x-20, y+45);
    delayMs(500);
    servo_arm(x-20, y);	
}

/*-----------------------------------------------------------------
//moves servos to position specified by parameter n and m *pin 16 & pin 18
//input: 	n - TC2 Servo
			m - TC3 Servo
//output: none
-----------------------------------------------------------------*/
void servo_arm(int n, int m){
	REG_TC2_COUNT16_CC1 = (((F_CPU/(64*50))* n )/2000)-1;
	REG_TC3_COUNT16_CC1 = (((F_CPU/(64*50))* m )/2000)-1;
}

