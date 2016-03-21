#include <EEPROM.h>
#include "EEPROMAnything.h"
#include <LiquidCrystal.h>
#include <stdio.h>

// This sketch initializes the EEPROM to zero zero zero...

/*
 This sketch shows two timers. One is user resettable and one is not. 
 The timers keep track of how long an analog input goes past a threshold.
 The smallest increment is one minute. If the threshold is exceeded for 
 any point in a minute (even less than a second) that minute is counted 
 towards the time.
 
  The circuit:
 * LCD RS pin to digital pin 12
 * LCD Enable pin to digital pin 11
 * LCD D4 pin to digital pin 5
 * LCD D5 pin to digital pin 4
 * LCD D6 pin to digital pin 3
 * LCD D7 pin to digital pin 2
 * LCD R/W pin to ground
 * 10K resistor:
 * ends to +5V and ground
 * wiper to LCD VO pin (pin 3)
 *
 * Analog input for thresholding analog in pin 0
 * button input for reset -> make on Nano D6, "pin 6"
 */

#define MAX_OUT_CHARS 16  //max nbr of characters to be sent on any one serial command

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

int userResetPin = 7;        // pin used for resetting user laser time  (Nano D7)

int RedPin = 6;				// pin for driving the Red backlight LED  (Nano D6)
int GreenPin = 9;			// pin for driving the Green backlight LED  (Nano D9)

struct config_t
{
    unsigned long seconds;
    unsigned long uSeconds;
	unsigned long EEPROMwriteCount;	// EEPROM write cycle count
									// Arduino EEPROM good for ~ 100,000 writes
									// only lasts ~ 1 year if write every 5 min, 24 x 7
									// and have ~ 12 people hitting reset every day
    unsigned int thisVersion;				// version number of this software
} laserTime;

void setup() {
	pinMode(userResetPin, INPUT);
	Serial.begin(9600);
  
	analogWrite(RedPin, 255);
	analogWrite(GreenPin, 125); 
	// initialize the LCD: 
	lcd.begin(16, 2);
	lcd.setCursor(0,0);
	lcd.println("open serial mon ");
	    //ie. open the Arduino Serial Monitor to observe more detailed output from the Nano
	lcd.setCursor(0,1);
	lcd.println("press clear btn ");
        //ie. press the Laser Cutter Timer Clear button to proceed with zeroing stored values


	Serial.println("Before Zeroing EEPROM");
	int addr = ROUND_ROBIN_EEPROM_read(laserTime);

    Serial.print("   Round Robin EEPROM address: ");
    Serial.println(addr);

	//EEPROM_readAnything(0, laserTime);
	ROUND_ROBIN_EEPROM_read(laserTime);
	ROUND_ROBIN_EEPROM_ZeroOutWindow();
  
	Serial.print("   laserTime.seconds ie tube: ");
	Serial.println(laserTime.seconds);
  
	Serial.print("   laserTime.uSeconds ie user: ");
	Serial.println(laserTime.uSeconds);
  
	Serial.print("   laserTime.EEPROMwriteCount: ");
	Serial.println(laserTime.EEPROMwriteCount);

	Serial.print("   laserTime.thisVersion: ");
	Serial.println(laserTime.thisVersion);
}

void loop() {
    int userReset = digitalRead(userResetPin);
    if (userReset == LOW) {

		Serial.println("Before Zeroing EEPROM");
		int addr = ROUND_ROBIN_EEPROM_read(laserTime);
  
        Serial.print("   Round Robin EEPROM address: ");
        Serial.println(addr);

		Serial.print("   laserTime.seconds ie tube: ");
		Serial.println(laserTime.seconds);
  
		Serial.print("   laserTime.uSeconds ie user: ");
		Serial.println(laserTime.uSeconds);
  
		Serial.print("   laserTime.EEPROMwriteCount: ");
		Serial.println(laserTime.EEPROMwriteCount);
  
		Serial.print("   laserTime.thisVersion: ");
		Serial.println(laserTime.thisVersion);


        // note: if you want to set the timers to some initial value, this is the place to do it...
        //       simply change the initial values from zero to something else, and proceed...

		// set the counter to zero, increment the write count
		laserTime.seconds = 0;
		laserTime.uSeconds = 0;
		laserTime.EEPROMwriteCount = laserTime.EEPROMwriteCount + 1;
		laserTime.thisVersion = 0;
		ROUND_ROBIN_EEPROM_write(laserTime);



		Serial.println("After Zeroing EEPROM");
		addr = ROUND_ROBIN_EEPROM_read(laserTime);

        Serial.print("   Round Robin EEPROM address: ");
		Serial.println(addr);

		ROUND_ROBIN_EEPROM_read(laserTime);
  
		Serial.print("   laserTime.seconds ie tube: ");
		Serial.println(laserTime.seconds);
  
		Serial.print("   laserTime.uSeconds ie user: ");
		Serial.println(laserTime.uSeconds);
  
		Serial.print("   laserTime.EEPROMwriteCount: ");
		Serial.println(laserTime.EEPROMwriteCount);
 
		Serial.print("   laserTime.thisVersion: ");
		Serial.println(laserTime.thisVersion);
 
		lcd.setCursor(0,0);
		lcd.println("EEPROM zeroed   ");
		lcd.setCursor(0,1);
		lcd.println("Reload firmware ");
		analogWrite(GreenPin, 255);
		analogWrite(RedPin, 0);

		delay(3000);	// cheap debouncing trick
	}
}

