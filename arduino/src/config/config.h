#ifndef CONFIG_H
#define CONFIG_H

// Nokia 5110 LCD Pins
#define LCD_CLK 3
#define LCD_DIN 4
#define LCD_DC  5
#define LCD_RST 6
#define LCD_CE  7

// LED Pins
#define LED_RED 9
#define LED_GREEN 10

// Button Pins
#define BTN1_PIN A1
#define BTN2_PIN A2
#define BTN3_PIN A3

// Buzzer
#define BUZZER_PIN 2

// Bluetooth (HC-05)
#define BT_BAUD_RATE 9600
#define BT_RX_PIN 12    // Arduino RX <- HC05 TX
#define BT_TX_PIN 11    // Arduino TX -> HC05 RX
#define BT_STATE_PIN 13 // HC05 STATE pin

#endif
