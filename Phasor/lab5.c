#define _SVID_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <at89lp51rd2.h>
#include "hardware.h"
#include "LCD.h"

#define CLK 22118400L
#define BAUD 115200L
#define ONE_USEC (CLK/1000000L) // Timer reload for one microsecond delay
#define BRG_VAL (0x100-(CLK/(16L*BAUD)))

#define ADC_CE  P2_0
#define BB_MOSI P2_1
#define BB_MISO P2_2
#define BB_SCLK P2_3
#define MAX 5
#define VREF 4.096

char mystr[CHARS_PER_LINE+1];


unsigned char SPIWrite(unsigned char out_byte)
{
	// In the 8051 architecture both ACC and B are bit addressable!
	ACC=out_byte;
	
	BB_MOSI=ACC_7; BB_SCLK=1; B_7=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_6; BB_SCLK=1; B_6=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_5; BB_SCLK=1; B_5=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_4; BB_SCLK=1; B_4=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_3; BB_SCLK=1; B_3=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_2; BB_SCLK=1; B_2=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_1; BB_SCLK=1; B_1=BB_MISO; BB_SCLK=0;
	BB_MOSI=ACC_0; BB_SCLK=1; B_0=BB_MISO; BB_SCLK=0;
	
	return B;
}

unsigned char _c51_external_startup(void)
{
	AUXR=0B_0001_0001; // 1152 bytes of internal XDATA, P4.4 is a general purpose I/O

	P0M0=0x00; P0M1=0x00;    
	P1M0=0x00; P1M1=0x00;    
	P2M0=0x00; P2M1=0x00;    
	P3M0=0x00; P3M1=0x00;    
    PCON|=0x80;
	SCON = 0x52;
    BDRCON=0;
    #if (CLK/(16L*BAUD))>0x100
    #error Can not set baudrate
    #endif
    BRL=BRG_VAL;
    BDRCON=BRR|TBCK|RBCK|SPD;
    
	CLKREG=0x00; // TPS=0000B

    return 0;
}

void wait_us (unsigned char x)
{
	unsigned int j;
	
	TR0=0; // Stop timer 0
	TMOD&=0xf0; // Clear the configuration bits for timer 0
	TMOD|=0x01; // Mode 1: 16-bit timer
	
	if(x>5) x-=5; // Subtract the overhead
	else x=1;
	
	j=-ONE_USEC*x;
	TF0=0;
	TH0=j/0x100;
	TL0=j%0x100;
	TR0=1; // Start timer 0
	while(TF0==0); //Wait for overflow
}

void waitms (unsigned int ms)
{
	unsigned int j;
	unsigned char k;
	for(j=0; j<ms; j++)
		for (k=0; k<4; k++) wait_us(250);
}

/*Read 10 bits from the MCP3008 ADC converter*/
unsigned int volatile GetADC(unsigned char channel)
{
	unsigned int adc;
	unsigned char spid;

	ADC_CE=0; //Activate the MCP3008 ADC.
	
	SPIWrite(0x01);//Send the start bit.
	spid=SPIWrite((channel*0x10)|0x80);	//Send single/diff* bit, D2, D1, and D0 bits.
	adc=((spid & 0x03)*0x100);//spid has the two most significant bits of the result.
	spid=SPIWrite(0x00);//It doesn't matter what we send now.
	adc+=spid;//spid contains the low part of the result. 
	
	ADC_CE=1; //Deactivate the MCP3008 ADC.
		
	return adc;
}

void LCDprint(char * string, unsigned char line, bit clear)
{
	int j;

	WriteCommand(line==2?0xc0:0x80);
	waitms(5);
	for(j=0; string[j]!=0; j++)	WriteData(string[j]);// Write the message
	if(clear) for(; j<CHARS_PER_LINE; j++) WriteData(' '); // Clear the rest of the line
}

void WriteData (unsigned char x)
{
	LCD_RS=1;
	LCD_byte(x);
	waitms(2);
}

void WriteCommand (unsigned char x)
{
	LCD_RS=0;
	LCD_byte(x);
	
}

void LCD_4BIT (void)
{
	LCD_E=0; // Resting state of LCD's enable is zero
	//LCD_RW=0; // We are only writing to the LCD in this program.  Connect pin to GND.
	waitms(20);
	// First make sure the LCD is in 8-bit mode and then change to 4-bit mode
	WriteCommand(0x33);
	WriteCommand(0x33);
	WriteCommand(0x32); // Change to 4-bit mode

	// Configure the LCD
	WriteCommand(0x28);
	WriteCommand(0x0c);
	WriteCommand(0x01); // Clear screen command (takes some time)
	waitms(20); // Wait for clear screen command to finsih.
}

void LCD_byte (unsigned char x)
{
	// The accumulator in the 8051 is bit addressable!
	ACC=x; //Send high nible
	LCD_D7=ACC_7;
	LCD_D6=ACC_6;
	LCD_D5=ACC_5;
	LCD_D4=ACC_4;
	LCD_pulse();
	wait_us(40);
	ACC=x; //Send low nible
	LCD_D7=ACC_3;
	LCD_D6=ACC_2;
	LCD_D5=ACC_1;
	LCD_D4=ACC_0;
	LCD_pulse();
}

void LCD_pulse (void)
{
	LCD_E=1;
	wait_us(40);
	LCD_E=0;
}

void voltage (void)
{
	#define VLED 2.03673 // Measured with multimeter
	float y, Vdd;
	unsigned char i;

	waitms(100);	
	printf("\n\nAT89LP51Rx2 SPI ADC test program.\n");
	Vdd=4.09622;
	
	while(1)
	{
		for(i=0; i<2; i++)
		{
			y=(GetADC(i)*Vdd)/1023.0; // Convert the 10-bit integer from the ADC to voltage
			printf("V%d=%5.3f ", i, y);
		}
		printf("\n"); // Carriage return only.
	}
}

float m_period(void){
	float myof, half_period, period;
	// Configure timer 0, leave time 1 alone!
	TMOD&=0B_1111_0000; // Set timer 0 as 16-bit timer (step 1)
	TMOD|=0B_0000_0001; // Set timer 0 as 16-bit timer (step 2)
	// Reset the timer and overflow counters
	TL0=0; TH0=0; myof=0;
	while (GetADC(0)!=0); // Wait for the signal to be zero
	while (GetADC(0)==0); // Wait for the sig. to be positive
	TF0=0; // Clear overflow flag
	TR0=1; // Start timer 0
	while (GetADC(0)!=0) // Wait for the sig. to be zero again
	{
	if (TF0) { TF0=0; myof++; }
	}
	TR0=0; // Stop timer 0. [myof-TH0-TL0] is the period in units of 1/CLK
	// half_period below is a float variable
	half_period=myof*65536.0+TH0*256.0+TL0; // The 24-bit number [myof-TH0-TL0]
	
	if (half_period > 50000){
		period = (half_period*2)/22118400;
		return period;
	}
	else {
		m_period();
	}
}

float m_peak_ref(void){
	float v0,Vdd,perd;
	Vdd=4.09622;
	perd = m_period();
	while(GetADC(0) != 0);
	while(GetADC(0) == 0);
	waitms(perd/4*1000);
	v0 = GetADC(0)*Vdd/1023.0;;
	return v0;
}

float m_peak_v(unsigned int i){
	float v,Vdd,perd;
	Vdd=4.09622;
	perd = m_period();
	while(GetADC(i) != 0);
	while(GetADC(i) == 0);
	waitms(perd/4*1000);
	v = GetADC(i)*Vdd/1023.0;;
	return v;

}

float m_phase(void){
	float myof, half_period, period;
		
	float myof2, half_period2, period2,time_diff;
	
	// Configure timer 0, leave time 1 alone!
	TMOD&=0B_1111_0000; // Set timer 0 as 16-bit timer (step 1)
	TMOD|=0B_0000_0001; // Set timer 0 as 16-bit timer (step 2)
	// Reset the timer and overflow counters
	TL0=0; TH0=0; myof=0;
	while (GetADC(0)!=0); // Wait for the signal to be zero
	while (GetADC(0)==0); // Wait for the sig. to be positive
	TF0=0; // Clear overflow flag
	TR0=1; // Start timer 0
	while (GetADC(1)!=0) // Wait for the sig. to be zero again
	{
	if (TF0) { TF0=0; myof++; }
	}
	TR0=0; 
	half_period=myof*65536.0+TH0*256.0+TL0; // The 24-bit number [myof-TH0-TL0]
	period = (half_period)/22118400;
	

	TMOD&=0B_1111_0000; 
	TMOD|=0B_0000_0001; 

	TL0=0; TH0=0; myof2=0;
	while (GetADC(1)!=0); 
	while (GetADC(1)==0); 
	TF0=0; 
	TR0=1; 
	while (GetADC(1)!=0) 
	{
	if (TF0) { TF0=0; myof2++; }
	}
	TR0=0; 
	half_period2=myof2*65536.0+TH0*256.0+TL0;
	period2 = (half_period2*2)/22118400;

	time_diff = 180 - (period*(360/period2));
	return time_diff;


}

void multi_temp(void) {
	float y;
	float y1;
	char str1[2];

	y = (GetADC(5)*VREF)/1023.0; // Convert the 10-bit integer from the ADC to voltage
	y1 = y*100 - 273;				// Covert to degree
	printf("%5.3f degrees celsius",y1);
	
	LCDprint("Temperature:", 1, 1);
	sprintf(str1, "%.2f Degree", y1);
	LCDprint(str1, 2, 1);
	
}

void multi_volt(void){
	float vref, v, vdiff;
	char str[2];
	vref = m_peak_ref();
	v = m_peak_v(1); 
	vdiff = vref - v;
	printf("Vref:%fV V:%fV Vdiff:%fV",vref,v,vdiff);
	sprintf(str, "V0:%.2f V:%.2f", vref, v);
	LCDprint(str, 1, 1);
	sprintf(str, "Vdiff:%.2f", vdiff);
	LCDprint(str, 2, 1);
}

void multi_freq(void){
	float freq, perd, count;
	char str2[1];
	perd = 0;
	freq = 0;
	count = 0;

	
	while(count < 20){
		perd = m_period();
		freq = 1.0/perd;
		count++;
	}
	
	freq = 1.0/perd;
	printf("Frequency:%fHz",freq);
	LCDprint("Frequency:", 1, 1);
	sprintf(str2, "%.2f Hz", freq);
	LCDprint(str2, 2, 1);
}

void multi_phas(void){
	float v0, v1, vref, v, perd, freq, phase, count;
	char str[15];
	LCD_4BIT();
	
	count = 0;
	perd = 0;
	phase = 0;
	freq = 0;


	while(count < 20){
		perd = m_period();
		freq = 1.0/perd;
		count++;
	}
	
	while(1){
		phase = m_phase();
		if (phase > 0.1){
			break;
		}
	}	
	
	v0 = m_peak_ref();
	v1 = m_peak_v(1);

		
	
	vref = v0*0.707107;
	v = v1*0.707107;


	printf("Vref(rms):%f V(rms):%f freq:%f phasor:%f",vref, v, freq, phase);
	
	sprintf(str, "V0:%.2f V:%.2f", vref, v);
	LCDprint(str, 1, 1);
	sprintf(str, "f:%.2f P:%.2f", freq, phase);
	LCDprint(str, 2, 1);
}



void main (void)
{	
	char user, user1;
	int  mode;
	

	printf("Welcome to the Lab 5 Interface!\n");
	printf("Please select from the functions below:\n\n");
	printf("1.Phasor Voltmeter   2.Regular Voltmeter\n");
	printf("3.Frequency Meter    4.Thermometer\n");
	
	mode = 0;
	user = getchar();
	
	while (1){
		while (mode == 0){
			if (user == '1'){
				mode = 1;
				printf("\n");
				waitms(500);
			}
			
			else if(user == '2'){
				mode = 2;
				printf("\n");
				waitms(500);
			}
			
			else if(user == '3'){
				mode = 3;
				printf("\n");
				waitms(500);
			}
			
			else if(user == '4'){
				mode = 4;
				printf("\n");
				waitms(500);
			}
			
			else {
				user = getchar();
			}
		}
		

		
		if (mode == 1){
			printf("Loading Phasor Voltmeter...\n");
			waitms(500);
			printf("Press ENTER to take the measurement     or     Press ESC to stop\n");
			user1 = getchar();
			
			while(user1 != 27){
				if (user1 == 13){ // detect ENTER
					multi_phas();
					user1 = getchar();	
				}
				
				else {
					printf("\nWrong input\n");
					user1 = getchar();
				}
			}
			printf("\nPProgram Stopped...\n"); //intentional two P's to compensate ESC character shift. 
			printf("Going back to the main menu\n");
			printf("-----------------------------------------------------\n");
			waitms(100);
			printf("Please select from the functions below:\n");
			printf("1.Phasor Voltmeter   2.Regular Voltmeter\n");
			printf("3.Frequency Meter    4.Thermometer\n");
			mode = 0;
			user = 0;
		}
		
		if (mode == 2){
			printf("Loading Regular Voltmeter...\n");
			waitms(500);
			printf("Press ENTER to take the measurement     or     Press ESC to stop\n");
			user1 = getchar();
			
			while(user1 != 27){
				if (user1 == 13){ // detect ENTER
					multi_volt();
					user1 = getchar();	
				}
				
				else {
					printf("\nWrong input\n");
					user1 = getchar();
				}
			}
			
			printf("\nPProgram Stopped...\n");
			printf("Going back to the main menu\n");
			printf("-----------------------------------------------------\n");
			waitms(100);
			printf("1.Phasor Voltmeter   2.Regular Voltmeter\n");
			printf("3.Frequency Meter    4.Thermometer\n");
			mode = 0;
			user = 0;
		}
		
		if (mode == 3){
			printf("Loading Frequency Meter...\n");
			waitms(500);
			printf("Press ENTER to take the measurement     or     Press ESC to stop\n");
			user1 = getchar();
			
			while(user1 != 27){
				if (user1 == 13){ // detect ENTER
					multi_freq();
					user1 = getchar();	
				}
				
				else {
					printf("\nWrong input\n");
					user1 = getchar();
				}
			}
			
			printf("\nPProgram Stopped...\n");
			printf("Going back to the main menu\n");
			printf("-----------------------------------------------------\n");
			waitms(100);
			printf("Please select from the functions below:\n");
			printf("1.Phasor Voltmeter   2.Regular Voltmeter\n");
			printf("3.Frequency Meter    4.Thermometer\n");
			mode = 0;
			user = 0;
		}

		
		if (mode == 4){
			printf("Loading Thermometer...\n");
			waitms(500);
			printf("Press ENTER to take the measurement     or     Press ESC to stop\n");
			user1 = getchar();
			
			while(user1 != 27){
				if (user1 == 13){ // detect ENTER
					multi_temp();
					user1 = getchar();	
				}
				
				else {
					printf("\nWrong input\n");
					user1 = getchar();
				}
			}
			
			printf("\nProgram Stopped...\n");
			printf("Going back to the main menu\n");
			printf("-----------------------------------------------------\n");
			printf("1.Phasor Voltmeter   2.Regular Voltmeter\n");
			printf("3.Frequency Meter    4.Thermometer\n");
			mode = 0;
			user = 0;
		}
	
	}

}