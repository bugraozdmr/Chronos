#include <Arduino.h>
#include "buzzer.h"
#include "../config/config.h"

void buzzerInit() {
  pinMode(BUZZER_PIN, OUTPUT);
  // Startup beep
  buzzerBeep();
}

void buzzerBeep() {
  tone(BUZZER_PIN, 1000, 150);
  delay(200);
}
