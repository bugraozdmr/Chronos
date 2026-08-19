#include <Arduino.h>
#include <SoftwareSerial.h>
#include "../config/config.h"
#include "bluetooth.h"
#include "../display/display.h"
#include "../commands/commands.h"

SoftwareSerial btSerial(BT_RX_PIN, BT_TX_PIN);

void bluetoothInit() {
  btSerial.begin(BT_BAUD_RATE);
  pinMode(BT_STATE_PIN, INPUT);
}

bool isBluetoothConnected() {
  // Debounce: read pin 10 times, require all HIGH
  int highCount = 0;
  for (int i = 0; i < 10; i++) {
    if (digitalRead(BT_STATE_PIN) == HIGH) {
      highCount++;
    }
    delay(5);
  }
  return (highCount >= 10);
}

void bluetoothUpdate() {
  if (btSerial.available()) {
    String incomingData = btSerial.readStringUntil('\n');
    incomingData.trim(); // \r ve gereksiz boşlukları temizle
    
    if (incomingData.length() > 0) {
      // Gelen veriyi doğrudan komut yönlendiriciye ilet.
      // Ekrana doğrudan raw veriyi basmak (displayMessage) SPI iletişiminden dolayı 
      // 50ms sürer ve SoftwareSerial buffer'ını taşırıp verileri bozabilir!
      processCommand(incomingData);
    }
  }
}

void bluetoothSendMessage(String msg) {
  // Mobil uygulamaya mesaj gönderirken sonuna \n (veya \r\n) eklemek çok önemli!
  btSerial.println(msg);
}
