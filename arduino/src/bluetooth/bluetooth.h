#ifndef BLUETOOTH_H
#define BLUETOOTH_H

#include <Arduino.h>

void bluetoothInit();
void bluetoothUpdate();
bool isBluetoothConnected();
void bluetoothSendMessage(String msg);

#endif
