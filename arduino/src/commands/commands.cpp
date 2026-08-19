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
  else if (command == "GET_STATUS") {
    // Örnek bir status cevabı
    bluetoothSendMessage("STATUS:ACTIVE|120|Ders");
  }
}
