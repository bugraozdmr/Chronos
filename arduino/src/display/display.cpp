#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_PCD8544.h>

#include "../config/config.h"
#include "display.h"

Adafruit_PCD8544 lcd(
  LCD_CLK,
  LCD_DIN,
  LCD_DC,
  LCD_CE,
  LCD_RST
);

void displayInit() {
  lcd.begin();
  lcd.setContrast(57);
  
  displayClear();

  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);

  // Random startup quote
  randomSeed(analogRead(A0));
  
  const char* quotes[] = {
    "Stay hungry,\nstay foolish.",
    "Knowledge is\npower.",
    "Never give up.",
    "I think,\ntherefore\nI am.",
    "Carpe diem.",
    "Veni, vidi,\nvici.",
    "Time is money.",
    "To be, or\nnot to be.",
    "Make it\nhappen."
  };
  
  int numQuotes = sizeof(quotes) / sizeof(quotes[0]);
  int randomIndex = random(0, numQuotes);

  lcd.setCursor(0, 0);
  lcd.println(quotes[randomIndex]);

  lcd.display();
}

void displayClear() {
  lcd.clearDisplay();
  lcd.display();
}

void displayMessage(const char* message) {
  lcd.clearDisplay();
  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);
  lcd.setCursor(0, 0);
  lcd.println(message);
  lcd.display();
}

void displayMessage(String message) {
  displayMessage(message.c_str());
}

void displayData(char data) {
  lcd.clearDisplay();
  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);
  lcd.setCursor(0, 0);
  lcd.println("INCOMING:");
  lcd.setCursor(0, 15);
  lcd.println(data);
  lcd.display();
}
