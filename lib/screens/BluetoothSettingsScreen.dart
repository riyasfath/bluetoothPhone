import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // Add this import
import 'package:blsample2/screens/LoginPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothPage extends StatefulWidget {
  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothState _btState = BluetoothState.UNKNOWN;
  List<BluetoothDevice> _discoveredDevices = [];
  List<BluetoothDevice> _pairedDevices = [];
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStream;
  BluetoothConnection? _connection;
  BluetoothDevice? _connectedDevice;
  bool _isDiscovering = false;
  bool _isToggleProcessing = false;
  Map<String, bool> _pairing = {};

  final Color pink = Color(0xFFFD3A73);

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  void _initBluetooth() async {
    // Request permissions first
    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      // Still try to continue, but user might face issues
      print('Some permissions were not granted');
    }

    // Get initial bluetooth state
    BluetoothState state = await FlutterBluetoothSerial.instance.state;
    setState(() => _btState = state);

    // Listen to state changes
    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      setState(() => _btState = state);
      if (state == BluetoothState.STATE_ON) {
        _getPairedDevices();
      }
    });

    // Get paired devices if bluetooth is on
    if (state == BluetoothState.STATE_ON) {
      _getPairedDevices();
    }
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        allGranted = false;
        print('Permission $permission: $status');
      }
    });

    if (!allGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some permissions were denied. Please enable them in settings.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }

    return allGranted;
  }

  void _getPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() => _pairedDevices = devices);
    } catch (e) {
      print('Error getting paired devices: $e');
    }
  }

  void _toggleBluetooth(bool value) async {
    setState(() => _isToggleProcessing = true);

    try {
      if (value) {
        await FlutterBluetoothSerial.instance.requestEnable();
      } else {
        await FlutterBluetoothSerial.instance.requestDisable();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle Bluetooth: $e')),
      );
    }

    setState(() => _isToggleProcessing = false);
  }

  void _startDiscovery() {
    if (_isDiscovering) return;

    setState(() {
      _discoveredDevices.clear();
      _isDiscovering = true;
    });

    _discoveryStream = FlutterBluetoothSerial.instance.startDiscovery().listen((BluetoothDiscoveryResult result) {
      setState(() {
        // Add device only if not already in the list
        final existingIndex = _discoveredDevices.indexWhere((device) => device.address == result.device.address);
        if (existingIndex == -1) {
          _discoveredDevices.add(result.device);
        }
      });
    });

    _discoveryStream!.onDone(() {
      setState(() => _isDiscovering = false);
    });

    _discoveryStream!.onError((error) {
      setState(() => _isDiscovering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery error: $error')),
      );
    });
  }

  void _stopDiscovery() {
    _discoveryStream?.cancel();
    FlutterBluetoothSerial.instance.cancelDiscovery();
    setState(() => _isDiscovering = false);
  }

  Future<void> _pairDevice(BluetoothDevice device) async {
    setState(() => _pairing[device.address] = true);

    try {
      bool? bonded = await FlutterBluetoothSerial.instance.bondDeviceAtAddress(device.address);

      if (bonded == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully paired with ${device.name ?? device.address}'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh paired devices list
        _getPairedDevices();
        // Remove from discovered devices as it's now paired
        setState(() {
          _discoveredDevices.removeWhere((d) => d.address == device.address);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pair with ${device.name ?? device.address}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pairing error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _pairing[device.address] = false);
  }

  Future<void> _unpairDevice(BluetoothDevice device) async {
    setState(() => _pairing[device.address] = true);

    try {
      bool? unbonded = await FlutterBluetoothSerial.instance.removeDeviceBondWithAddress(device.address);

      if (unbonded == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully unpaired ${device.name ?? device.address}'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh paired devices list
        _getPairedDevices();
        // Disconnect if currently connected
        if (_connectedDevice?.address == device.address) {
          _disconnect();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unpair ${device.name ?? device.address}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unpairing error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _pairing[device.address] = false);
  }

  void _connect(BluetoothDevice device) async {
    // Show loading state
    setState(() => _pairing[device.address] = true);

    // Disconnect from current device if any
    if (_connection != null) {
      _disconnect();
    }

    // Add delay to ensure pairing is complete
    await Future.delayed(Duration(milliseconds: 500));

    try {
      print('Attempting to connect to ${device.name} (${device.address})');

      // Try multiple connection attempts with different approaches
      BluetoothConnection? connection;

      // Method 1: Direct connection
      try {
        connection = await BluetoothConnection.toAddress(device.address).timeout(
          Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Connection timeout'),
        );
        print('Connected using direct method');
      } catch (e) {
        print('Direct connection failed: $e');

        // Method 2: Try with different socket type
        try {
          await Future.delayed(Duration(milliseconds: 1000));
          connection = await BluetoothConnection.toAddress(device.address).timeout(
            Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Connection timeout'),
          );
          print('Connected using retry method');
        } catch (e2) {
          print('Retry connection also failed: $e2');
          throw e2;
        }
      }

      if (connection != null && connection.isConnected) {
        setState(() {
          _connection = connection;
          _connectedDevice = device;
          _pairing[device.address] = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Connected to ${device.name ?? device.address}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Listen for disconnection and data
        connection.input!.listen(
              (data) {
            // Handle incoming data here if needed
            print('Received data: ${String.fromCharCodes(data)}');
            // You can add data handling logic here
          },
          onDone: () {
            print('Connection closed by remote device');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device disconnected'),
                  backgroundColor: Colors.orange,
                ),
              );
              _disconnect();
            }
          },
          onError: (error) {
            print('Connection stream error: $error');
            if (mounted) {
              _disconnect();
            }
          },
        );

        // Test connection by sending a simple message
        try {
          // Fix: Convert List<int> to Uint8List
          Uint8List helloMessage = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello" in ASCII
          connection.output.add(helloMessage);
          await connection.output.allSent;
          print('Test message sent successfully');
        } catch (e) {
          print('Failed to send test message: $e');
          // Connection might still work for receiving data
        }

      } else {
        throw Exception('Connection established but not active');
      }

    } on TimeoutException catch (e) {
      setState(() => _pairing[device.address] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection timeout. Make sure device is nearby and not connected to another device.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      print('Connection timeout: $e');
    } catch (e) {
      setState(() => _pairing[device.address] = false);

      String errorMessage = 'Connection failed';

      // Provide specific error messages
      if (e.toString().contains('socket might closed')) {
        errorMessage = 'Device rejected connection. Try unpairing and pairing again.';
      } else if (e.toString().contains('Service discovery failed')) {
        errorMessage = 'Service discovery failed. Device might not be compatible.';
      } else if (e.toString().contains('read failed')) {
        errorMessage = 'Connection lost. Device might be out of range.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Connection refused. Device might be busy or incompatible.';
      } else if (e.toString().contains('Host is down')) {
        errorMessage = 'Device is not responding. Make sure it\'s turned on and nearby.';
      } else if (e.toString().contains('Permission denied')) {
        errorMessage = 'Permission denied. Check app permissions.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _connect(device),
          ),
        ),
      );
      print('Connection error: $e');
    }
  }

  void _disconnect() {
    _connection?.close();
    setState(() {
      _connection = null;
      _connectedDevice = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Disconnected'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _logout() {
    _stopDiscovery();
    _disconnect();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
          (route) => false,
    );
  }

  Widget _buildDeviceListTile(BluetoothDevice device, {required bool isPaired}) {
    final name = (device.name?.isNotEmpty == true) ? device.name! : 'Unknown Device';
    final address = device.address;
    final isConnected = _connectedDevice?.address == device.address;
    final isConnecting = _pairing[device.address] == true;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.bluetooth_connected :
          isPaired ? Icons.bluetooth : Icons.bluetooth_searching,
          color: isConnected ? Colors.green : (isPaired ? pink : Colors.grey),
          size: 30,
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address, style: TextStyle(fontSize: 12)),
            Row(
              children: [
                if (isPaired)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Paired', style: TextStyle(color: Colors.green, fontSize: 10)),
                  ),
                if (isConnected) ...[
                  SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Connected', style: TextStyle(color: pink, fontSize: 10)),
                  ),
                ],
                if (isConnecting) ...[
                  SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Connecting...', style: TextStyle(color: Colors.orange, fontSize: 10)),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: isConnecting
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPaired && !isConnected)
              ElevatedButton(
                onPressed: () => _connect(device),
                child: Text('Connect', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pink,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size(70, 30),
                ),
              ),
            if (isConnected)
              ElevatedButton(
                onPressed: _disconnect,
                child: Text('Disconnect', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size(80, 30),
                ),
              ),
            if (!isPaired)
              ElevatedButton(
                onPressed: () => _pairDevice(device),
                child: Text('Pair', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size(60, 30),
                ),
              ),
            if (isPaired && !isConnected) ...[
              SizedBox(width: 8),
              IconButton(
                onPressed: () => _unpairDevice(device),
                icon: Icon(Icons.delete, color: Colors.red),
                iconSize: 20,
                constraints: BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopDiscovery();
    _connection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOn = _btState == BluetoothState.STATE_ON;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Bluetooth Settings'),
          backgroundColor: pink,
          actions: [
            if (isOn)
              IconButton(
                icon: _isDiscovering
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(Icons.refresh),
                onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
              ),
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: isOn
              ? TabBar(
            tabs: [
              Tab(text: 'Paired Devices'),
              Tab(text: 'Available Devices'),
            ],
            indicatorColor: Colors.white,
          )
              : null,
        ),
        body: Column(
          children: [
            // Bluetooth Toggle
            Container(
              color: Colors.grey[100],
              child: SwitchListTile(
                title: Text(
                  'Bluetooth',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isOn ? 'Enabled' : 'Disabled',
                  style: TextStyle(color: isOn ? Colors.green : Colors.red),
                ),
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
                  color: isOn ? pink : Colors.grey,
                  size: 32,
                ),
              ),
            ),

            // Device Lists
            if (isOn)
              Expanded(
                child: TabBarView(
                  children: [
                    // Paired Devices Tab
                    _pairedDevices.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No paired devices'),
                          SizedBox(height: 8),
                          Text('Go to Available Devices to pair new devices'),
                        ],
                      ),
                    )
                        : ListView.builder(
                      itemCount: _pairedDevices.length,
                      itemBuilder: (context, index) {
                        return _buildDeviceListTile(
                          _pairedDevices[index],
                          isPaired: true,
                        );
                      },
                    ),

                    // Available Devices Tab
                    Column(
                      children: [
                        if (!_isDiscovering && _discoveredDevices.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Tap refresh to discover devices',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        if (_isDiscovering)
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(width: 16),
                                Text('Discovering devices...'),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _discoveredDevices.length,
                            itemBuilder: (context, index) {
                              return _buildDeviceListTile(
                                _discoveredDevices[index],
                                isPaired: false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Bluetooth is disabled'),
                      SizedBox(height: 8),
                      Text('Enable Bluetooth to discover and connect to devices'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}