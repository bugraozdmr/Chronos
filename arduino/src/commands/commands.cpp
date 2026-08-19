#include <Arduino.h>
#include "commands.h"
#include "../display/display.h"
#include "../bluetooth/bluetooth.h"

void commandsInit() {
  // Komut modülü başlatma işlemleri
}

void processCommand(String command) {
  // Gelen komutu işle
  if (command == "TEST") {
    displayMessage("TEST BASARILI");
    bluetoothSendMessage("ACK:TEST_OK");
  } 
  else if (command.startsWith("START|")) {
    displayMessage("SURE BASLADI");
    bluetoothSendMessage("ACK:START_OK");
  }
  else if (command == "STOP") {
    displayMessage("SURE DURDU");
    bluetoothSendMessage("ACK:STOP_OK");
  }
  else if (command == "PAUSE") {
    displayMessage("DURAKLATILDI");
    bluetoothSendMessage("ACK:PAUSE_OK");
  }
  else if (command == "RESUME") {
    displayMessage("DEVAM EDIYOR");
    bluetoothSendMessage("ACK:RESUME_OK");
  }
  else if (command.startsWith("STATUS:")) {
    String payload = command.substring(7);
    if (payload == "IDLE" || payload == "NONE") {
      if (isSessionMode) {
        // Oturum bitti, menüye geri dönmek için jobları iste
        bluetoothSendMessage("GET_JOBS"); 
      }
    } else {
      // Örn: ACTIVE|120|Gaming
      int firstPipe = payload.indexOf('|');
      int secondPipe = payload.indexOf('|', firstPipe + 1);
      
      if (firstPipe != -1 && secondPipe != -1) {
        String statusStr = payload.substring(0, firstPipe);
        int timeSecs = payload.substring(firstPipe + 1, secondPipe).toInt();
        String jobNameStr = payload.substring(secondPipe + 1);
        
        displaySessionView(jobNameStr, timeSecs, statusStr);
      }
    }
  }
  else if (command.startsWith("JOBS:")) {
    // Örn: JOBS:Coding,Gaming,Reading
    String payload = command.substring(5);
    String parsedJobs[10];
    int jobCount = 0;
    
    int startIndex = 0;
    int commaIndex = payload.indexOf(',');
    
    while (commaIndex != -1 && jobCount < 10) {
      parsedJobs[jobCount++] = payload.substring(startIndex, commaIndex);
      startIndex = commaIndex + 1;
      commaIndex = payload.indexOf(',', startIndex);
    }
    
    // Son öğeyi veya tek öğeyi ekle
    if (startIndex < payload.length() && jobCount < 10) {
      parsedJobs[jobCount++] = payload.substring(startIndex);
    }
    
    if (jobCount > 0) {
      displayMenuSetItems(parsedJobs, jobCount);
    } else {
      displayMessage("No Jobs");
    }
  }
}
