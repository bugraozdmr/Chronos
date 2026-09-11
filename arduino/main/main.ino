#include "src/bluetooth/bluetooth.h"
#include "src/buzzer/buzzer.h"
#include "src/commands/commands.h"
#include "src/config/config.h"
#include "src/display/display.h"
#include "src/led/led.h"
#include "src/sensor/sensor.h"
#include "src/utils/utils.h"

void setup() {
  displayInit();
  bluetoothInit();
  commandsInit();
  sensorInit();
  buzzerInit();
  ledInit();

  // Buttons (internal pull-up, pressed = LOW)
  pinMode(BTN1_PIN, INPUT_PULLUP);
  pinMode(BTN2_PIN, INPUT_PULLUP);
  pinMode(BTN3_PIN, INPUT_PULLUP);
}

bool lastBtState = false;
bool firstTime = true;
unsigned long lastJobRequestTime = 0;
const unsigned long JOB_REQUEST_INTERVAL = 60000; // 60 saniye (1 dakika)

void loop() {
  bluetoothUpdate();
  sensorUpdate();

  // Bluetooth state -> LED + LCD
  bool btState = isBluetoothConnected();
  ledSetConnectionState(btState);

  if (btState != lastBtState || firstTime) {
    if (btState) {
      displayMessage(F("System Ready"));
      // Bağlantı kurulduğunda hemen job listesini iste
      bluetoothSendMessage("GET_JOBS");
      lastJobRequestTime = millis();
    } else {
      displayWaitingBluetooth();
    }
    lastBtState = btState;
    firstTime = false;
  }

  // Bluetooth bağlı olduğu sürece dakikada bir job listesini güncelle (Sadece menüdeyken)
  if (btState && isMenuMode) {
    if (millis() - lastJobRequestTime >= JOB_REQUEST_INTERVAL) {
      lastJobRequestTime = millis();
      bluetoothSendMessage("GET_JOBS");
    }
  }

  // Button handling with simple debounce
  static unsigned long lastBtn1Time = 0;
  static unsigned long lastBtn2Time = 0;
  static unsigned long lastBtn3Time = 0;

  if (digitalRead(BTN1_PIN) == LOW && millis() - lastBtn1Time > 200) {
    if (isMenuMode) {
      displayMenuScrollUp();
    } else if (isSessionMode) {
      if (currentSessionStatus == "ACTIVE") {
        bluetoothSendMessage("PAUSE");
      } else if (currentSessionStatus == "PAUSED") {
        bluetoothSendMessage("RESUME");
      }
    }
    lastBtn1Time = millis();
  }
  if (digitalRead(BTN2_PIN) == LOW && millis() - lastBtn2Time > 200) {
    if (isMenuMode) {
      displayMenuScrollDown();
    } else if (isSessionMode) {
      bluetoothSendMessage("STOP");
    }
    lastBtn2Time = millis();
  }

  // BTN3 Long Press / Short Press / Double Click Logic
  static unsigned long btn3PressStart = 0;
  static unsigned long btn3LastReleaseTime = 0;
  static bool btn3Pressed = false;
  static bool btn3LongHandled = false;

  bool currentBtn3State = digitalRead(BTN3_PIN);
  if (currentBtn3State == LOW) { // Basılı tutuluyor
    if (!btn3Pressed) {
      btn3Pressed = true;
      btn3PressStart = millis();
      btn3LongHandled = false;
    } else {
      // Uzun basma kontrolü (Örn: 800ms)
      if (!btn3LongHandled && (millis() - btn3PressStart > 800)) {
        if (isMenuMode) {
          displayMessage(F("Refreshing..."));
          bluetoothSendMessage("GET_JOBS");
        }
        btn3LongHandled = true; // Sadece bir kere tetiklenmesi için
      }
    }
  } else { // Buton bırakıldı
    if (btn3Pressed) {
      // Kısa basma kontrolü (Debounce için en az 50ms basılmış olmalı)
      if (!btn3LongHandled && (millis() - btn3PressStart > 50)) {
        // Çift tıklama kontrolü (Örn: ard arda 400ms içinde iki kez basılırsa)
        if (millis() - btn3LastReleaseTime < 400) {
          // Easter Egg: Mipmap Göster! (displayWaitingBluetooth ekranı temizleyip resmi basıyor)
          displayWaitingBluetooth();
          delay(2000);
          btn3LastReleaseTime = 0; // Sıfırla
          
          // Ekrana geri dön
          if (btState) { // Menu için state
            isMenuMode = true; 
            displayMessage(F("Refreshing..."));
            bluetoothSendMessage("GET_JOBS");
          }
        } else {
          // İlk tıklama - işlevi yerine getir (Oturum başlat vb.)
          if (isMenuMode) {
            String selectedJob = displayMenuGetSelected();
            if (selectedJob != "") {
              displayMessage(F("Starting..."));
              bluetoothSendMessage("START|" + selectedJob);
            }
          }
          btn3LastReleaseTime = millis();
        }
      }
      btn3Pressed = false;
    }
  }
}