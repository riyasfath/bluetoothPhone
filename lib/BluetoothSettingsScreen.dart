import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt;
import 'main.dart';

class BluetoothPage extends StatefulWidget {
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  bool _isDiscovering = false;
  List<BluetoothDevice> _devicesList = [];
  List<BluetoothDevice> _discoveredDevices = [];
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;

  BluetoothDevice? _connectedDevice;
  BluetoothConnection? _connection;
  bool get isConnected => _connection?.isConnected ?? false;

  final greenColor = Color(0xFF1DB954);

  @override
  void initState() {
    super.initState();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
      if (state == BluetoothState.STATE_ON) {
        _getPairedDevices();
      }
    });

    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (state == BluetoothState.STATE_ON) {
          _getPairedDevices();
        } else {
          _discoveredDevices.clear();
          _devicesList.clear();
          _cancelDiscovery();
        }
      });
    });
  }

  Future<void> _getPairedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devicesList = devices;
      });
    } catch (e) {
      print("Error getting paired devices: $e");
    }
  }

  void _startDiscovery() {
    setState(() {
      _discoveredDevices.clear();
      _isDiscovering = true;
    });

    _discoveryStreamSubscription = FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      setState(() {
        final existingIndex = _discoveredDevices.indexWhere((d) => d.address == result.device.address);
        if (existingIndex >= 0) {
          _discoveredDevices[existingIndex] = result.device;
        } else {
          _discoveredDevices.add(result.device);
        }
      });
    });

    _discoveryStreamSubscription!.onDone(() {
      setState(() => _isDiscovering = false);
    });
  }

  void _cancelDiscovery() {
    _discoveryStreamSubscription?.cancel();
    setState(() => _isDiscovering = false);
  }

  Future<void> _connect(BluetoothDevice device) async {
    if (isConnected) {
      await _disconnect();
    }

    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connectedDevice = device;
        _connection = connection;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${device.name}')));
      connection.input!.listen(null).onDone(() {
        setState(() {
          _connectedDevice = null;
          _connection = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disconnected from device')));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
    }
  }

  Future<void> _disconnect() async {
    await _connection?.close();
    setState(() {
      _connectedDevice = null;
      _connection = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disconnected')));
  }

  void _toggleBluetooth(bool value) {
    if (value) {
      FlutterBluetoothSerial.instance.requestEnable();
    } else {
      FlutterBluetoothSerial.instance.requestDisable();
    }
  }

  void _logout() async {
    if (isConnected) {
      await _disconnect();
    }
    _cancelDiscovery();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
    );
  }

  Widget _buildDeviceTile(
      BluetoothDevice device, bool connected, VoidCallback onConnect, VoidCallback onDisconnect) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shadowColor: Colors.black.withOpacity(0.15),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(Icons.bluetooth, color: connected ? greenColor : Colors.grey[600], size: 32),
        title: Text(
          device.name ?? "Unknown Device",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: connected ? greenColor : Colors.black87,
          ),
        ),
        subtitle: Text(
          device.address,
          style: TextStyle(color: Colors.grey[700]),
        ),
        trailing: connected
            ? ElevatedButton(
          onPressed: onDisconnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text("Disconnect"),
        )
            : ElevatedButton(
          onPressed: onConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: greenColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text("Connect"),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelDiscovery();
    _connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOn = _bluetoothState == BluetoothState.STATE_ON;

    return Scaffold(
      appBar: AppBar(
        title: Text("Bluetooth Settings"),
        actions: [
          IconButton(
            tooltip: "Refresh Paired Devices",
            icon: Icon(Icons.refresh),
            onPressed: isOn ? _getPairedDevices : null,
          ),
          IconButton(
            tooltip: "Logout",
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(
                "Bluetooth",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOn ? greenColor : Colors.grey,
                  fontSize: 18,
                ),
              ),
              value: isOn,
              onChanged: _toggleBluetooth,
              activeColor: greenColor,
              inactiveThumbColor: Colors.grey,
            ),
            if (isOn) ...[
              Text("Paired Devices", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: _devicesList.isEmpty
                    ? Center(child: Text("No paired devices found"))
                    : ListView.builder(
                  itemCount: _devicesList.length,
                  itemBuilder: (_, index) {
                    final device = _devicesList[index];
                    final connected = _connectedDevice?.address == device.address;
                    return _buildDeviceTile(
                      device,
                      connected,
                          () => _connect(device),
                      _disconnect,
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              Divider(),
              ListTile(
                title: Text(
                  "Discover Devices",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                trailing: _isDiscovering
                    ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
                    : ElevatedButton(
                  onPressed: _startDiscovery,
                  style: ElevatedButton.styleFrom(backgroundColor: greenColor),
                  child: Text("Scan"),
                ),
              ),
              Expanded(
                flex: 1,
                child: _discoveredDevices.isEmpty
                    ? Center(child: Text(_isDiscovering ? "Scanning..." : "No devices found"))
                    : ListView.builder(
                  itemCount: _discoveredDevices.length,
                  itemBuilder: (_, index) {
                    final device = _discoveredDevices[index];
                    final connected = _connectedDevice?.address == device.address;
                    return _buildDeviceTile(
                      device,
                      connected,
                          () => _connect(device),
                      _disconnect,
                    );
                  },
                ),
              )
            ] else ...[
              Expanded(
                child: Center(child: Text("Bluetooth is OFF")),
              )
            ]
          ],
        ),
      ),
    );
  }
}
