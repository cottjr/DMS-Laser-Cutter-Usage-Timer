#include <EEPROM.h>

// Carl - updated per this thread - http://forum.arduino.cc/index.php?topic=114164.0
//#include <WProgram.h>  // for type definitions
#include <Arduino.h>  // for type definitions

// Kent - added round robin methods and configuration items to help minimize eeprom wear

//this is already configured to the size of the 'config_t' struct
#define ROUND_ROBIN_DATA_TYPE_BYTES 4+4+4+2

//this is configured to ignore address 0 which has already seen a lot of action
#define ROUND_ROBIN_MIN_EEPROM_ADDR 1 * ROUND_ROBIN_DATA_TYPE_BYTES

//define the number of slots we will distribute the eeprom IO out accross
//this setting will still comfortably not exceed the atmega168 512 byte limitations (you can expand this if your chip allows 1K)
#define ROUND_ROBIN_MAX_EEPROM_ADDR 30 * ROUND_ROBIN_DATA_TYPE_BYTES

template <class T> int EEPROM_writeAnything(int ee, const T& value)
{
    const byte* p = (const byte*)(const void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
        EEPROM.write(ee++, *p++);
    return i;
}

template <class T> int EEPROM_readAnything(int ee, T& value)
{
    byte* p = (byte*)(void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
        *p++ = EEPROM.read(ee++);
    return i;
}

//zero out the entire round robin window
void ROUND_ROBIN_EEPROM_ZeroOutWindow()
{
    byte eeData[ROUND_ROBIN_DATA_TYPE_BYTES];

    for (int addr = ROUND_ROBIN_MIN_EEPROM_ADDR; addr <= ROUND_ROBIN_MAX_EEPROM_ADDR; addr += ROUND_ROBIN_DATA_TYPE_BYTES)
    {
        EEPROM_readAnything(addr, eeData);
        byte testByte = 0x00;
        for (int b = 0; b < ROUND_ROBIN_DATA_TYPE_BYTES; b++)
        {
            //if we find a byte address with data in it, set it to 0x00
            if (eeData[b] != 0x00)
                EEPROM.write(addr + b, 0x00);
        }

    }

}

//returns the address that is currently being used in the round robin window
int ROUND_ROBIN_EEPROM_GetAddressOfData()
{
    byte eeData[ROUND_ROBIN_DATA_TYPE_BYTES];

    for (int addr = ROUND_ROBIN_MIN_EEPROM_ADDR; addr <= ROUND_ROBIN_MAX_EEPROM_ADDR; addr += ROUND_ROBIN_DATA_TYPE_BYTES)
    {
        EEPROM_readAnything(addr, eeData);
        for (int b = 0; b < ROUND_ROBIN_DATA_TYPE_BYTES; b++)
        {
            //if we find the address with data in it, return that address and break out of the loop
            if (eeData[b] != 0x00)
                return addr;
        }

    }
    //if we get to this line we failed to find data in our round robin window (or the data was actually 0L)
    //in this case we start at the beginning of the window again
    return ROUND_ROBIN_MIN_EEPROM_ADDR;
}

//find the value stored in the round robin window and assign it to 'value'
template <class T> int ROUND_ROBIN_EEPROM_read(T& value)
{
    int ee = ROUND_ROBIN_EEPROM_GetAddressOfData();
    int newAddress = ee;
    byte* p = (byte*)(void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
        *p++ = EEPROM.read(ee++);
    return newAddress;
}

//write the 'value' to the round robin window and manage clean up from the previous write
template <class T> int ROUND_ROBIN_EEPROM_write(T& value)
{
    //this will be the eeprom address of the last round robin value recorded
    int eeLastAddress = ROUND_ROBIN_EEPROM_GetAddressOfData();

    //to spread things out the next block in our round robin window will be used next
    //if we are at the end of the defined window, start again at the first byte of our window
    int ee = (eeLastAddress == ROUND_ROBIN_MAX_EEPROM_ADDR) ? ROUND_ROBIN_MIN_EEPROM_ADDR : eeLastAddress + sizeof(value);
    int newAddress = ee;
    const byte* p = (const byte*)(const void*)&value;
    int i;
    for (i = 0; i < sizeof(value); i++)
        EEPROM.write(ee++, *p++);

    //now clean up the data in the previously used slot so it won't be confused with live data on the next read request
    for (int l = 0; l < sizeof(value); l++)
        EEPROM.write(eeLastAddress++, 0x00);
    return newAddress;
}



