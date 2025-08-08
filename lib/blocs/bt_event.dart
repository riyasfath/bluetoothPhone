import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

abstract class BtEvent {}

class BtInit extends BtEvent {}

class BtStartDiscovery extends BtEvent {}

class BtDeviceTapped extends BtEvent {
  final BluetoothDevice device;
  BtDeviceTapped(this.device);
}

class BtDisconnect extends BtEvent {}
