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

bool isAsleep = false;
unsigned long lastActivityTime = 0;
const unsigned long SLEEP_TIMEOUT = 300000; // 5 mins

void wakeUp() {
  if (!isAsleep)
    return;
  isAsleep = false;
  lastActivityTime = millis();
  displayMessage(F("Waking up..."));
  if (isBluetoothConnected()) {
    bluetoothSendMessage("GET_JOBS");
  }
}

void goToSleep() {
  if (isAsleep)
    return;
  isAsleep = true;
  displayClear(); // lcd is private to display.cpp, so we use displayClear()
  digitalWrite(LED_RED, LOW);
  digitalWrite(LED_GREEN, LOW);
}

void loop() {
  bluetoothUpdate();

  if (isAsleep) {
    if (digitalRead(BTN1_PIN) == LOW || digitalRead(BTN2_PIN) == LOW ||
        digitalRead(BTN3_PIN) == LOW) {
      wakeUp();
      delay(300); // Debounce for wake up
    }
    return; // Uyku modundayken loop'un geri kalanını çalıştırma
  }

  // Herhangi bir butona basıldığında aktivite süresini güncelle
  if (digitalRead(BTN1_PIN) == LOW || digitalRead(BTN2_PIN) == LOW ||
      digitalRead(BTN3_PIN) == LOW) {
    lastActivityTime = millis();
  }

  // Uyku moduna geçiş kontrolü
  if (millis() - lastActivityTime > SLEEP_TIMEOUT && !isSessionMode) {
    goToSleep();
    return;
  }

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

  // Bluetooth bağlı olduğu sürece dakikada bir job listesini güncelle (Sadece
  // menüdeyken)
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
  static bool btn3WaitingForDouble = false;

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
        if (btn3WaitingForDouble) {
          // Çift tıklama başarılı!
          btn3WaitingForDouble = false;
          displayWaitingBluetooth(); // Mipmap göster
          delay(2000);

          if (isBluetoothConnected()) {
            isMenuMode = true;
            displayMessage(F("Refreshing..."));
            bluetoothSendMessage("GET_JOBS");
          }
        } else {
          // İlk tıklama kaydedildi, ikinciyi bekle
          btn3WaitingForDouble = true;
          btn3LastReleaseTime = millis();
        }
      }
      btn3Pressed = false;
    }
  }

  // Çift tıklama süresi dolduysa ve ikinci tıklama gelmediyse tek tıklama
  // işlemini yap
  if (btn3WaitingForDouble && (millis() - btn3LastReleaseTime > 300)) {
    btn3WaitingForDouble = false;
    if (isMenuMode) {
      String selectedJob = displayMenuGetSelected();
      if (selectedJob != "") {
        displayMessage(F("Starting..."));
        bluetoothSendMessage("START|" + selectedJob);
      }
    }
  }
}