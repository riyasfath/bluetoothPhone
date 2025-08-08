import 'package:blsample2/screens/LoginPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';

class BluetoothPage extends StatefulWidget {
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothState _btState = BluetoothState.UNKNOWN;
  bool _isToggleProcessing = false;
  bool _isDiscovering = false;
  List<BluetoothDevice> _devices = [];
  BluetoothConnection? _connection;
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStream;

  @override
  void initState() {
    super.initState();
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() => _btState = state);
    });
    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      setState(() => _btState = state);
    });
  }

  Future<void> _toggleBluetooth(bool value) async {
    setState(() => _isToggleProcessing = true);
    if (value) {
      await FlutterBluetoothSerial.instance.requestEnable();
    } else {
      await FlutterBluetoothSerial.instance.requestDisable();
    }
    setState(() => _isToggleProcessing = false);
  }

  void _startDiscovery() {
    setState(() {
      _isDiscovering = true;
      _devices.clear();
    });

    _discoveryStream = FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      final d = r.device;
      setState(() {
        if (!_devices.any((e) => e.address == d.address)) {
          _devices.add(d);
        }
      });
    });

    _discoveryStream!.onDone(() {
      setState(() => _isDiscovering = false);
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      final conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connection = conn;
        _connectedDevice = device;
      });
      conn.input?.listen(null).onDone(() {
        setState(() {
          _connectedDevice = null;
          _connection = null;
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  Future<void> _disconnect() async {
    await _connection?.close();
    setState(() {
      _connection = null;
      _connectedDevice = null;
    });
  }

  Future<void> _logout() async {
    await _disconnect();
    _discoveryStream?.cancel();
    FlutterBluetoothSerial.instance.cancelDiscovery();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    _disconnect();
    _discoveryStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOn = _btState == BluetoothState.STATE_ON;

    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Settings'),
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: Text('Bluetooth'),
              value: isOn,
              onChanged: _isToggleProcessing ? null : _toggleBluetooth,
              secondary: _isToggleProcessing
                  ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(
                Icons.bluetooth,
                color: isOn ? Theme.of(context).primaryColor : Colors.grey,
              ),
            ),
            if (isOn) ...[
              ElevatedButton.icon(
                onPressed: _isDiscovering ? null : _startDiscovery,
                icon: _isDiscovering
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Icon(Icons.search),
                label: Text('Scan'),
              ),
              SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final connected = _connectedDevice?.address == device.address;
                    return ListTile(
                      title: Text(device.name ?? 'Unknown'),
                      subtitle: Text(device.address),
                      trailing: connected
                          ? ElevatedButton(
                        onPressed: _disconnect,
                        child: Text('Disconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                      )
                          : ElevatedButton(
                        onPressed: () => _connect(device),
                        child: Text('Connect'),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(child: Text('Bluetooth is OFF')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
