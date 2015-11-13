#include <EEPROM.h>
#include "EEPROMAnything.h"
#include <LiquidCrystal.h>
#include <stdio.h>

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

 // Kent - altered eeprom read and write calls to extend eeprom life

#define MAX_OUT_CHARS 16  //max nbr of characters to be sent on any one serial command

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);

const unsigned long second = 1000;
const unsigned long minute = 60000;    // number of millis in a minute
const unsigned long hour = 3600000;    // number of millis in an hour

int userResetPin = 7;        // pin used for resetting user laser time  (Nano D7)

boolean TestOutToggle = true;
int TestOutPin = 13;		// pin for toggling once per every inner loop operation, just to keep tabs on software (Nano D13)

boolean TestOutToggle2 = true;
int TestOutPin2 = 8;		// pin for toggling once per every outer loop operation, just to keep tabs on software (Nano D8)

int RedPin = 6;				// pin for driving the Red backlight LED  (Nano D6)
int GreenPin = 9;			// pin for driving the Green backlight LED  (Nano D9)
int BluePin = 10;			// pin for driving the Blue backlight LED  (Nano D10)


int analogPin = 0;           // light sensor input (or voltsge) connected to analog pin 0
int analogVal = 0;           // variable to store the value read
int anaLowThreshold = 500;   // if analog value rises above this value its considered ON
int anaHighThreshold = 524;  // if analog value falls below this value its considered OFF
int cursorPos = 0;
unsigned long millisOnLast = 0;
unsigned long millisOffLast = 0;
unsigned long millisTemp = 0;
unsigned long millisDiff = 0;
boolean lastLaserOn = false;
unsigned long userMillis = 0;
int userHours = 0;
int userMinutes = 0;        // number of minutes user has used the laser (resettable when button pressed)
int userSeconds = 0;
int tubeHours = 0;
int tubeMinutes = 0;        // number of minutes tube has been used (not resettable)
int tubeSeconds = 0;
unsigned long tubeMillis = 0;        
unsigned long lastWriteToEEPROMMillis = 0;   // number of millis that the EEPROM was laser written to

char   buffer[MAX_OUT_CHARS];  //buffer used to format a line (+1 is for trailing 0)
char   buffer2[MAX_OUT_CHARS];  //buffer used to format a line (+1 is for trailing 0)

const unsigned int ThisCurrentVersion = 1;	// version number for this program.  simply counting releases

struct config_t
{
	unsigned long seconds;			// tube seconds
    unsigned long uSeconds;			// user seconds
	unsigned long EEPROMwriteCount;	// EEPROM write cycle count
									// Arduino EEPROM good for ~ 100,000 writes
									// only lasts ~ 1 year if write every 5 min, 24 x 7
									// and have ~ 12 people hitting reset every day
    unsigned int thisVersion;		// version number of this software
} laserTime;

void setup() {
  pinMode(userResetPin, INPUT);
  pinMode(TestOutPin, OUTPUT);
  pinMode(TestOutPin2, OUTPUT);
  
  Serial.begin(9600);
  //EEPROM_readAnything(0, laserTime);
  //ROUND_ROBIN_EEPROM_ZeroOutWindow();  //use this if you need to clean all the eeprom possitions withing the window defined in the header
  int addr = ROUND_ROBIN_EEPROM_read(laserTime);
  tubeMillis = laserTime.seconds*1000;
  userMillis = laserTime.uSeconds*1000;
  
  // Initialize the version number in EEPROM if this is the first load after a reflash
  if ( laserTime.thisVersion == 0 ) {
	laserTime.thisVersion = ThisCurrentVersion;
	laserTime.EEPROMwriteCount = laserTime.EEPROMwriteCount + 1;
	//EEPROM_writeAnything(0, laserTime);
	addr = ROUND_ROBIN_EEPROM_write(laserTime);
  }
  
  
  // Briefly show Arduino status
  sprintf(buffer, "Version: %02d", laserTime.thisVersion);
  sprintf(buffer2, "Writes: %06d", laserTime.EEPROMwriteCount);
  
  lcd.begin(16, 2);
  lcd.setCursor(0,0);
  lcd.print (buffer);
  lcd.setCursor(0,1);
  lcd.print (buffer2);
  
  // set display backlight to Purple
  BacklightColor ( 255, 0, 255);

  delay(5000);	// cheap debouncing trick  

  
  // Initialize the LCD 
//  lcd.begin(16, 2);
//  lcd.setCursor(0,0);
//  lcd.println("User    00:00:00");
//  lcd.setCursor(0,1);
//  lcd.print  ("Tube 00000:00:00");
  
  // start with the display backlight as Blue
//  BacklightColor ( 0, 0, 255);

  
  Serial.print("Values stored in EEPROM address ");
  Serial.println(addr);


  Serial.print("  laserTime.seconds ie tube: ");
  Serial.println(laserTime.seconds);
  
  Serial.print("  laserTime.uSeconds ie user: ");
  Serial.println(laserTime.uSeconds);
  
  Serial.print("  laserTime.EEPROMwriteCount: ");
  Serial.println(laserTime.EEPROMwriteCount);

  Serial.print("  laserTime.thisVersion: ");
  Serial.println(laserTime.thisVersion);
	
  Serial.println("setup Complete");
  Serial.println("");
}

void BacklightColor ( int R, int G, int B) {
// accept standard RGB color specs, with values from 0..255
// for a nice RGB value selection chart, see this source
//  http://blogs.msdn.com/blogfiles/davidlean/WindowsLiveWriter/SQLReportingHowtoConditionalColor24Funct_B98C/image_8.png
//  http://blogs.msdn.com/b/davidlean/archive/2009/02/17/sql-reporting-how-to-conditional-color-2-4-functions-for-tables-charts.aspx
// render that color by writing appropriate values to PWM based pins
  
  int Gadj = G / 2; //approximation to account for observation that G is twice as bright as other colors
					//   for the specific RGB display used in the Dallas Makerspace project
					//this adjustment empirically tends to give approximately a yellow, when 255 R and 127 G are mixed)
  analogWrite(RedPin, R);
  analogWrite(GreenPin, Gadj);
  analogWrite(BluePin, B);
}

void loop() {

  //  toggle a pin during every outer loop execution - just watch on a 'scope for a sense of timing
  //  baseline shows that this loop takes about 37 ms to execute
	if ( TestOutToggle2 ) {
  // nominally keep disabled, since Nano D13 annoyingly toggles an LED
//		digitalWrite(TestOutPin2, HIGH);
	}
	else {
		digitalWrite(TestOutPin2, LOW);
	}
	TestOutToggle2 = !TestOutToggle2;

// debug EEPROM protection timing	
//	Serial.print  ("lastWriteToEEPROMMillis: ");
//	Serial.println(lastWriteToEEPROMMillis);

	
  // do a tight loop on checking the laser and keeping track of on/off times  
  for (int i=0; i <= 100; i++) {
	
  //  toggle a pin during every inner loop execution - just watch on a 'scope for a sense of timing
  //  baseline shows that this loop takes about 178 us to execute
	if ( TestOutToggle ) {
  // nominally keep disabled, since Nano D13 annoyingly toggles an LED
//		digitalWrite(TestOutPin, HIGH);
	}
	else {
		digitalWrite(TestOutPin, LOW);
	}
	TestOutToggle = !TestOutToggle;
	
  
    analogVal = analogRead(analogPin);    // read the input pin
//    Serial.print("anaVal:");
//    Serial.println(analogVal);

  // set backlight to Red while laser is firing
  // set backlight to Yellow while laser NOT firing and user time is accumulated
  // set backlight back to Blue when laser not firing and no time accumulated
	if (analogVal <  anaLowThreshold) {		// go red
		BacklightColor ( 255, 0, 0);
	} else if (userMillis > 0) {    		// go yellowish
		BacklightColor ( 255, 245, 0);
	} else {   								// go Blue
		BacklightColor ( 0, 0, 255);
	}
 
	// consider checking hysteresis logic - it appears that anaLowThreshold alone determines laser on/off state
    if ((analogVal <  anaLowThreshold) && !lastLaserOn) {     // laser has been off, laser turning on here
      lastLaserOn = true;
      millisOnLast = (unsigned long) millis();
      millisDiff = millisOnLast - millisOffLast;
    } else if ((analogVal <  anaLowThreshold) && lastLaserOn) {   // laser has been on here, continuing on
      lastLaserOn = true;

      millisTemp = (unsigned long) millis();
      millisDiff = millisTemp-millisOnLast;
      millisOnLast = millisTemp;      
    } else if ((analogVal > anaHighThreshold) && lastLaserOn) {  // laser has been on, turning off
      lastLaserOn = false;
      millisOffLast = (unsigned long) millis();
    } else {             // laser has been off, staying off
      lastLaserOn = false;
      millisOffLast = (unsigned long) millis();
    }
    int userReset = digitalRead(userResetPin);
    if (userReset == LOW) {
	  
  //    allow reset and writing once every 10 seconds, but no faster
  //    write values to EPROM every time user hits reset
      if (millis() > (lastWriteToEEPROMMillis+10000)) {
        userMillis = 0;
		laserTime.seconds = tubeMillis/1000;
        laserTime.uSeconds = userMillis/1000;
		laserTime.EEPROMwriteCount = laserTime.EEPROMwriteCount + 1;
		laserTime.thisVersion = ThisCurrentVersion;
        //EEPROM_writeAnything(0, laserTime);
		int addr = ROUND_ROBIN_EEPROM_write(laserTime);

		lastWriteToEEPROMMillis = millis();
        
        Serial.println("User hit reset & Wrote to EEPROM");

		Serial.print("  EEPROM address: ");
		Serial.println(addr);

		Serial.print("  laserTime.seconds ie tube: ");
		Serial.println(laserTime.seconds);
  
		Serial.print("  laserTime.uSeconds ie user: ");
		Serial.println(laserTime.uSeconds);
  
		Serial.print("  laserTime.EEPROMwriteCount: ");
		Serial.println(laserTime.EEPROMwriteCount);
		
		Serial.print("  laserTime.thisVersion: ");
		Serial.println(laserTime.thisVersion);
      }
	  
    }
      userMillis = userMillis + millisDiff;
      tubeMillis = tubeMillis + millisDiff;
      millisDiff = 0;
  }

  // set the cursor to column 12, line 1    (is this really working this way? or does it rewrite the entire display?)
  // (note: line 1 is the second row, since counting begins with 0):
  tubeHours = tubeMillis/hour;
  tubeMinutes = (tubeMillis-tubeHours*hour)/minute;
  tubeSeconds = (tubeMillis-tubeHours*hour-tubeMinutes*minute)/second;
  userHours = userMillis/hour;
  userMinutes = (userMillis-userHours*hour)/minute;
  userSeconds = (userMillis-userHours*hour-userMinutes*minute)/second;
 
  sprintf(buffer, "User    %02d:%02d:%02d", userHours,  userMinutes, userSeconds);
  sprintf(buffer2,"Tube %05d:%02d:%02d", tubeHours,  tubeMinutes, tubeSeconds);

  // Only write to EEPROM if the current value is more than 5 minutes from the previous EEPROM value
  // to reduce the number of writes to EEPROM, since it is only good for ~ 100,000 writes
  //EEPROM_readAnything(0, laserTime);
  int addr = ROUND_ROBIN_EEPROM_read(laserTime);
  unsigned long laserSeconds = laserTime.seconds;
  
  // note - it appears that only one of the following If statements is required  
  if ((laserSeconds+300) < (tubeMillis/1000)) {    
    Serial.print("LaserSeconds:");
    Serial.print(laserSeconds);
    Serial.print("adjTubeSecs:");
    Serial.println(((tubeMillis/1000)+300));
    laserTime.seconds = tubeMillis/1000;
    laserTime.uSeconds = userMillis/1000;
	laserTime.EEPROMwriteCount = laserTime.EEPROMwriteCount + 1;
	laserTime.thisVersion = ThisCurrentVersion;
    //EEPROM_writeAnything(0, laserTime);
	addr = ROUND_ROBIN_EEPROM_write(laserTime);
    lastWriteToEEPROMMillis = millis();
    Serial.println("Wrote to EEPROM - tube has another 5 minutes of use");
	
	Serial.print("  EEPROM address: ");
	Serial.println(addr);

	Serial.print("  laserTime.seconds ie tube: ");
	Serial.println(laserTime.seconds);
	
	Serial.print("  laserTime.uSeconds ie user: ");
	Serial.println(laserTime.uSeconds);
  
	Serial.print("  laserTime.EEPROMwriteCount: ");
	Serial.println(laserTime.EEPROMwriteCount);
	 
	Serial.print("  laserTime.thisVersion: ");
	Serial.println(laserTime.thisVersion);
   }  
  if ((millis() > (lastWriteToEEPROMMillis+300000)) && ((laserSeconds+1)*1000 < tubeMillis)) { 
  // ie. if it has been 5 mins since last write and the value has changed, write now
    laserTime.seconds = tubeMillis/1000;
    laserTime.uSeconds = userMillis/1000;
	laserTime.EEPROMwriteCount = laserTime.EEPROMwriteCount + 1;
	laserTime.thisVersion = ThisCurrentVersion;
	//this method has been replaced to distribute the eeprom writing accross a wider address space
	//EEPROM_writeAnything(0, laserTime);
	addr = ROUND_ROBIN_EEPROM_write(laserTime);
    lastWriteToEEPROMMillis = millis();
    Serial.println("Wrote to EEPROM - value has changed in last 5 minutes");
	
	Serial.print("  EEPROM address: ");
	Serial.println(addr);

	Serial.print("  laserTime.seconds ie tube: ");
	Serial.println(laserTime.seconds);
	
	Serial.print("  laserTime.uSeconds ie user: ");
	Serial.println(laserTime.uSeconds);
  
	Serial.print("  laserTime.EEPROMwriteCount: ");
	Serial.println(laserTime.EEPROMwriteCount);
	 
	Serial.print("  laserTime.thisVersion: ");
	Serial.println(laserTime.thisVersion);
 	}
  lcd.setCursor(0,0);
  lcd.print(buffer);
//  Serial.println(buffer);
  lcd.setCursor(0,1);
  lcd.print(buffer2);
//  Serial.println(buffer2);

}

