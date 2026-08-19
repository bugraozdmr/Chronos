#include <Arduino.h>
#include "led.h"
#include "../config/config.h"

void ledInit() {
  pinMode(LED_RED, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  
  // Hardware test: RED 2s, then GREEN 2s
  digitalWrite(LED_RED, HIGH);
  digitalWrite(LED_GREEN, LOW);
  delay(2000);
  
  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, HIGH);
  delay(2000);
  
  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, LOW);
}

void ledSetConnectionState(bool isConnected) {
  if (isConnected) {
    digitalWrite(LED_GREEN, HIGH);
    digitalWrite(LED_RED, LOW);
  } else {
    digitalWrite(LED_GREEN, LOW);
    digitalWrite(LED_RED, HIGH);
  }
}
