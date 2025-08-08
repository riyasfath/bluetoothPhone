import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'bt_event.dart';
import 'bt_state.dart';

class BtBloc extends Bloc<BtEvent, BtState> {
  BtBloc() : super(BtInitial()) {
    on<BtInit>(_onInit);
    on<BtStartDiscovery>(_onDiscover);
    on<BtDeviceTapped>(_onConnect);
    on<BtDisconnect>(_onDisconnect);
  }

  Future<void> _onInit(BtInit e, Emitter<BtState> emit) async {
    final btState = await FlutterBluetoothSerial.instance.state;
    if (btState == BluetoothState.STATE_ON) {
      final paired = await FlutterBluetoothSerial.instance.getBondedDevices();
      emit(BtOn(paired: paired));
    } else {
      emit(BtOff());
    }

    FlutterBluetoothSerial.instance.onStateChanged().listen((_) {
      add(BtInit());
    });
  }

  Future<void> _onDiscover(BtStartDiscovery e, Emitter<BtState> emit) async {
    emit(BtLoading());
    List<BluetoothDevice> discovered = [];

    await for (var result in FlutterBluetoothSerial.instance.startDiscovery()) {
      discovered.add(result.device);
    }

    final current = state;
    if (current is BtOn) {
      emit(BtOn(
        paired: current.paired,
        discovered: discovered,
        connected: current.connected,
      ));
    }
  }

  Future<void> _onConnect(BtDeviceTapped e, Emitter<BtState> emit) async {
    try {
      await BluetoothConnection.toAddress(e.device.address);
      final current = state;
      if (current is BtOn) {
        emit(BtOn(
          paired: current.paired,
          discovered: current.discovered,
          connected: e.device,
        ));
      }
    } catch (e) {
      emit(BtFailure(e.toString()));
    }
  }

  void _onDisconnect(BtDisconnect e, Emitter<BtState> emit) {
    final current = state;
    if (current is BtOn) {
      emit(BtOn(paired: current.paired, discovered: current.discovered));
    }
  }
}
