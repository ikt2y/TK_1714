/*
 * uart1.c
 *
 * Created: 2016/09/09 19:44:14
 * Author : kazuya
 */ 
#define F_CPU 1000000UL
#define READ_MAX 60
#define CHECK_LEN 11
#define CONECT_LEN 6

#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

void initPORT(void);
void initUART(void);
int isHex(char);
int hex2dec(char);

int isHex(char c) {
	if(((c>='0') && (c<='9')) || ((c>='A') && (c<='F'))) return 1;
	else return 0;
}

int hex2dec(char c) {
	if((c>='0') && (c<='9')) c -= '0';
	if((c>='A') && (c<='F')) c = 10 + c -'A';
	return c;
}

void initUART(void) { //UART設定

	UBRR0 = 25; //ボーレート2400
	UCSR0A = 0b00000000;
	UCSR0B = 0b00011000;
	UCSR0C = 0b00000110;
}

void initPORT(void) { //ポート設定

	DDRD  = 0xFC;
	PORTD = 0x00;
	DDRC  = 0xFF;
	PORTC = 0x00;
	DDRB  = 0xFF;
	PORTB = 0x00;
}

int main(void) {
	char leng = 0;
	int i;
	int flag = 0;
	char input[READ_MAX] = {};
	const char checker[CHECK_LEN] = "00,0000,00:";
	const char conect[CONECT_LEN] = "CONECT";

	initPORT();
	initUART();
	//initTMR0();

    while (1) {
		
		for(i=0; i<READ_MAX; i++) {
			while(1) { //if read value is not ASCII code, throw away it
				while(!(UCSR0A & 0x80)); //受信可能状態を待つ
				input[i] = UDR0; //受信
				if((input[i]>0) && (input[i]<=128)) break;
			}
			if(input[i]=='\n') {
				leng = i; //reserve the length of the sentence
				//Serial.println(leng);
				break;
			}
		}
		/*
		for(i=0; i<=leng; i++) {
			PORTD = 0x80;
			_delay_ms(500);
			PORTD = 0x00;
			_delay_ms(500);
		}
		*/
		if(leng >= CONECT_LEN) {
			for(i=0; i<CONECT_LEN; i++) {
				if(conect[i] != input[i]) break;
			}
			
			if(i == CONECT_LEN) {
				PORTD = 0x84;
				_delay_ms(125);
				PORTD = 0x00;
				_delay_ms(75);
				PORTD = 0x84;
				_delay_ms(125);
				PORTD = 0x00;
				continue;
			}
		}
		
		if(leng >= CHECK_LEN) {
			for(i=0; i<CHECK_LEN; i++) {
				if(checker[i] != input[i]) break;
				//check the initial input
			}

			if(i == CHECK_LEN) {
				for(i=CHECK_LEN; i<=leng; i+=3) {
					switch(hex2dec(input[i])*16+hex2dec(input[i+1])) {
						case 's': //start
							PORTD = 0x84;
							_delay_ms(200);
							PORTD = 0x00;
							_delay_ms(100);
							PORTD = 0x84;
							_delay_ms(200);
							PORTD = 0x00;
							_delay_ms(200);
							PORTD = 0x84;
							_delay_ms(200);
							PORTD = 0x00;
							_delay_ms(100);
							PORTD = 0x84;
							_delay_ms(200);
							PORTD = 0x00;
							break;
						case 'g': //goal
							PORTD = 0x84;
							_delay_ms(5000);
							PORTD = 0x00;
							_delay_ms(100);
							break;
						case 'r': //turn right
							PORTD = 0x80;
							_delay_ms(450);
							PORTD = 0x00;
							_delay_ms(100);
							PORTD = 0x80;
							_delay_ms(450);
							PORTD = 0x00;
							break;
						case 'l': //turn left
							PORTD = 0x04;
							_delay_ms(450);
							PORTD = 0x00;
							_delay_ms(100);
							PORTD = 0x04;
							_delay_ms(450);
							PORTD = 0x00;
							break;
						case 'R':
							PORTD = 0x80;
							_delay_ms(1500);
							PORTD = 0x00;
							_delay_ms(100);
							break;
						case 'L':
							PORTD = 0x04;
							_delay_ms(1500);
							PORTD = 0x00;
							_delay_ms(100);
							break;
						default:
							flag = 1;
							break;
					}
					
					if(flag == 0) {
						break;
					} else{
						flag = 0;
					}
				}
			}
		}
    }
}

