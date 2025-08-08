import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

abstract class BtState {}

class BtInitial extends BtState {}

class BtOn extends BtState {
  final List<BluetoothDevice> paired;
  final List<BluetoothDevice> discovered;
  final BluetoothDevice? connected;

  BtOn({this.paired = const [], this.discovered = const [], this.connected});
}

class BtOff extends BtState {}

class BtLoading extends BtState {}

class BtFailure extends BtState {
  final String error;
  BtFailure(this.error);
}
