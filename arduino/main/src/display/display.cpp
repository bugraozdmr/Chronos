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

#define MAX_MENU_ITEMS 10
String menuItems[MAX_MENU_ITEMS];
int menuCount = 0;
int menuSelectedIndex = 0;
int menuScrollIndex = 0;
bool isMenuMode = false;
bool isSessionMode = false;
String currentSessionStatus = "IDLE";

// Quotes stored in Flash (PROGMEM) to save SRAM
const char quote_0[] PROGMEM = "Stay hungry,\nstay foolish.";
const char quote_1[] PROGMEM = "Knowledge is\npower.";
const char quote_2[] PROGMEM = "Never give up.";
const char quote_3[] PROGMEM = "I think,\ntherefore\nI am.";
const char quote_4[] PROGMEM = "Carpe diem.";
const char quote_5[] PROGMEM = "Veni, vidi,\nvici.";
const char quote_6[] PROGMEM = "Time is money.";
const char quote_7[] PROGMEM = "To be, or\nnot to be.";
const char quote_8[] PROGMEM = "Make it\nhappen.";

const char* const quotes[] PROGMEM = {
  quote_0, quote_1, quote_2, quote_3, quote_4,
  quote_5, quote_6, quote_7, quote_8
};

#include "display_image.h"

void displayInit() {
  lcd.begin();
  lcd.setContrast(LCD_CONTRAST);
  
  displayClear();

  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);

  // Random startup quote from PROGMEM
  randomSeed(analogRead(A0));
  
  int numQuotes = sizeof(quotes) / sizeof(quotes[0]);
  int randomIndex = random(0, numQuotes);

  char quoteBuf[32];
  strcpy_P(quoteBuf, (char*)pgm_read_word(&(quotes[randomIndex])));

  lcd.setCursor(0, 0);
  lcd.println(quoteBuf);

  lcd.display();
}

void displayClear() {
  isMenuMode = false;
  isSessionMode = false;
  lcd.clearDisplay();
  lcd.display();
}

void displayMessage(const char* message) {
  isMenuMode = false;
  isSessionMode = false;
  lcd.clearDisplay();
  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);
  lcd.setCursor(0, 0);
  lcd.println(message);
  lcd.display();
}

void displayMessage(const __FlashStringHelper* message) {
  isMenuMode = false;
  isSessionMode = false;
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

void displayDrawBitmapImage() {
  for (int y = 0; y < DISPLAY_IMAGE_HEIGHT; y++) {
    for (int x = 0; x < DISPLAY_IMAGE_WIDTH; x++) {
      uint8_t b = pgm_read_byte(&display_image[x + (y / 8) * DISPLAY_IMAGE_WIDTH]);
      if (b & (1 << (y % 8))) {
        lcd.drawPixel(x, y, BLACK);
      }
    }
  }
}

void displayWaitingBluetooth() {
  isMenuMode = false;
  isSessionMode = false;
  lcd.clearDisplay();
  
  // Draw user's bitmap from display_image.h
  displayDrawBitmapImage();
  
  lcd.display();
}

void displayData(char data) {
  isMenuMode = false;
  isSessionMode = false;
  lcd.clearDisplay();
  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);
  lcd.setCursor(0, 0);
  lcd.println("INCOMING:");
  lcd.setCursor(0, 15);
  lcd.println(data);
  lcd.display();
}

// ---------------- MENU SYSTEM ----------------
void displayMenuSetItems(String items[], int count) {
  menuCount = (count > MAX_MENU_ITEMS) ? MAX_MENU_ITEMS : count;
  for(int i = 0; i < menuCount; i++) {
    menuItems[i] = items[i];
  }
  menuSelectedIndex = 0;
  menuScrollIndex = 0;
  isMenuMode = true;
  isSessionMode = false;
  displayMenuShow();
}

void displayMenuShow() {
  if (!isMenuMode) return;
  
  lcd.clearDisplay();
  
  // Header
  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);
  lcd.setCursor(18, 0); // Center "JOBS" a bit (18 is approx center for 4 chars)
  lcd.println("- JOBS -");
  
  // Show up to 4 items (lines 1 to 4) on Nokia 5110
  int maxVisible = 4;
  for (int i = 0; i < maxVisible; i++) {
    int itemIndex = menuScrollIndex + i;
    if (itemIndex >= menuCount) break;
    
    lcd.setCursor(0, (i + 1) * 10); // 10 pixels spacing per line
    
    if (itemIndex == menuSelectedIndex) {
      // Invert colors for selected item
      lcd.setTextColor(WHITE, BLACK);
      lcd.print("> ");
      lcd.print(menuItems[itemIndex]);
      lcd.setTextColor(BLACK, WHITE); // Reset
    } else {
      lcd.setTextColor(BLACK, WHITE);
      lcd.print("  ");
      lcd.print(menuItems[itemIndex]);
    }
  }
  lcd.display();
}

void displayMenuScrollUp() {
  if (!isMenuMode || menuCount == 0) return;
  if (menuSelectedIndex > 0) {
    menuSelectedIndex--;
    if (menuSelectedIndex < menuScrollIndex) {
      menuScrollIndex = menuSelectedIndex;
    }
    displayMenuShow();
  }
}

void displayMenuScrollDown() {
  if (!isMenuMode || menuCount == 0) return;
  if (menuSelectedIndex < menuCount - 1) {
    menuSelectedIndex++;
    if (menuSelectedIndex >= menuScrollIndex + 4) { // maxVisible is 4
      menuScrollIndex++;
    }
    displayMenuShow();
  }
}

String displayMenuGetSelected() {
  if (!isMenuMode || menuCount == 0) return "";
  return menuItems[menuSelectedIndex];
}

// ---------------- SESSION VIEW ----------------
void displaySessionView(String jobName, int elapsedSeconds, String status) {
  isMenuMode = false;
  isSessionMode = true;
  currentSessionStatus = status;
  
  lcd.clearDisplay();
  
  // Top: Job Name (centered roughly)
  lcd.setTextSize(1);
  lcd.setTextColor(BLACK);
  // Center text (approx: 14 chars per line. Center = (84 - length*6) / 2)
  int startX = (84 - (jobName.length() * 6)) / 2;
  if (startX < 0) startX = 0;
  lcd.setCursor(startX, 0);
  lcd.println(jobName);
  
  // Middle: Time MM:SS
  int h = elapsedSeconds / 3600;
  int m = (elapsedSeconds % 3600) / 60;
  int s = elapsedSeconds % 60;
  
  char timeStr[10];
  if (h >= 10) {
    sprintf(timeStr, "%d:%02d", h, m); // e.g. "12:35" (5 chars)
  } else if (h > 0) {
    sprintf(timeStr, "%d:%02d:%02d", h, m, s); // e.g. "1:05:30" (7 chars = 84px, fits exactly)
  } else {
    sprintf(timeStr, "%02d:%02d", m, s); // e.g. "45:30" (5 chars)
  }
  
  // Center large text (approx: size 2 -> 12px width per char)
  int timeLen = strlen(timeStr);
  int timeX = (84 - (timeLen * 12)) / 2;
  if (timeX < 0) timeX = 0;
  
  lcd.setTextSize(2);
  lcd.setCursor(timeX, 14);
  lcd.print(timeStr);
  
  // Bottom: Buttons [PAUSE] [STOP]
  lcd.setTextSize(1);
  lcd.setCursor(0, 35);
  
  // Lcd is 84px wide. 14 chars max.
  // We want "[PAUS]" on left (0), "[STOP]" on right (approx x=48).
  if (status == "ACTIVE") {
    lcd.print("[PAUS]  [STOP]");
  } else if (status == "PAUSED") {
    lcd.print("[CONT]  [STOP]");
  }
  
  lcd.display();
}
