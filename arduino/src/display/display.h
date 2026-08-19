#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>

void displayInit();
void displayClear();
void displayMessage(const char* message);
void displayMessage(String message);
void displayData(char data);

#endif
