#include "src/config/config.h"
#include "src/display/display.h"
#include "src/bluetooth/bluetooth.h"
#include "src/commands/commands.h"
#include "src/sensor/sensor.h"
#include "src/buzzer/buzzer.h"
#include "src/led/led.h"
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
      displayMessage("System Ready");
      // Bağlantı kurulduğunda hemen job listesini iste
      bluetoothSendMessage("GET_JOBS");
      lastJobRequestTime = millis();
    } else {
      displayMessage("Waiting BT");
    }
    lastBtState = btState;
    firstTime = false;
  }

  // Bluetooth bağlı olduğu sürece dakikada bir job listesini güncelle
  if (btState) {
    if (millis() - lastJobRequestTime >= JOB_REQUEST_INTERVAL) {
      lastJobRequestTime = millis();
      bluetoothSendMessage("GET_JOBS");
    }
  }

  // Button test
  if (digitalRead(BTN1_PIN) == LOW) {
    displayMessage("BTN1 Pressed");
    delay(300);
  }
  if (digitalRead(BTN2_PIN) == LOW) {
    displayMessage("BTN2 Pressed");
    delay(300);
  }
}