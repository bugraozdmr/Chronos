#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>

void displayInit();
void displayClear();
void displayMessage(const char* message);
void displayMessage(String message);
void displayData(char data);

// Menu Functions
void displayMenuSetItems(String items[], int count);
void displayMenuShow();
void displayMenuScrollUp();
void displayMenuScrollDown();
String displayMenuGetSelected();

// Session Mode Functions & Variables
extern bool isMenuMode;
extern bool isSessionMode;
extern String currentSessionStatus;

void displaySessionView(String jobName, int elapsedSeconds, String status);

#endif
