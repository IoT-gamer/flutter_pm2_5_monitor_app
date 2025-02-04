import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// BLE device name matching the microcontroller
const String deviceName = "PM2.5 Sensor";

// BLE UUIDs matching the microcontroller
const String serviceUUID = "91bad492-b950-4226-aa2b-4ede9fa42f59";
const String pm1_0CharUUID = "91bad493-b950-4226-aa2b-4ede9fa42f59";
const String pm2_5CharUUID = "91bad494-b950-4226-aa2b-4ede9fa42f59";
const String pm10CharUUID = "91bad495-b950-4226-aa2b-4ede9fa42f59";

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PMSensorState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PM Sensor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class PMSensorState extends ChangeNotifier {
  BluetoothDevice? device;
  bool isConnected = false;
  int pm1_0 = 0;
  int pm2_5 = 0;
  int pm10 = 0;

  void updateReadings({int? pm1_0, int? pm2_5, int? pm10}) {
    if (pm1_0 != null) this.pm1_0 = pm1_0;
    if (pm2_5 != null) this.pm2_5 = pm2_5;
    if (pm10 != null) this.pm10 = pm10;
    notifyListeners();
  }

  void setDevice(BluetoothDevice? device) {
    this.device = device;
    isConnected = device != null;
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _checkPermissions() async {
    // Request necessary permissions for BLE
    final connectPermission = await Permission.bluetoothConnect.request();
    final scanPermission = await Permission.bluetoothScan.request();
    final locationPermission = await Permission.location.request();
    if (connectPermission.isDenied ||
        scanPermission.isDenied ||
        locationPermission.isDenied) {
      _showError('Please grant permissions to use the app');
      // print('locationPermissions: $locationPermission');
      // print('connectPermission: $connectPermission');
      // print('scanPermission: $scanPermission');
    }
  }

  Future<bool> _checkBluetoothScanState() async {
    return await FlutterBluePlus.adapterState
        .firstWhere((element) =>
            element == BluetoothAdapterState.on ||
            element == BluetoothAdapterState.off ||
            element == BluetoothAdapterState.unknown)
        .then((s) {
      if (s == BluetoothAdapterState.off) {
        _showError('Please enable Bluetooth to use the app');
        return false;
      }
      return true;
    });
  }

  void _startScan() async {
    if (!await _checkBluetoothScanState()) {
      return;
    }
    setState(() => _isScanning = true);
    _scanSubscription?.cancel();

    // Start scanning
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // print('Found device: ${result.device.platformName}');
        if (result.device.platformName == deviceName) {
          _connect(result.device);
          // print('Found PM sensor');
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    // Stop scanning after timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    final state = Provider.of<PMSensorState>(context, listen: false);

    try {
      await device.connect();
      if (!mounted) return;
      state.setDevice(device);

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      if (!mounted) return;

      // Find our service
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUUID) {
          // Set up notifications for each characteristic
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            await characteristic.setNotifyValue(true);
            if (!mounted) return;
            characteristic.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                int reading = value[0];

                switch (characteristic.uuid.toString()) {
                  case pm1_0CharUUID:
                    state.updateReadings(pm1_0: reading);
                    break;
                  case pm2_5CharUUID:
                    state.updateReadings(pm2_5: reading);
                    break;
                  case pm10CharUUID:
                    state.updateReadings(pm10: reading);
                    break;
                }
              }
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to connect: ${e.toString()}');
      state.setDevice(null);
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PM Sensor Monitor'),
      ),
      body: Consumer<PMSensorState>(
        builder: (context, state, child) {
          if (!state.isConnected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isScanning)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _startScan,
                      child: const Text('Scan for Sensor'),
                    ),
                  const SizedBox(height: 16),
                  Text(_isScanning
                      ? 'Scanning...'
                      : 'Press to scan for PM sensor'),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Readings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildReadingCard('PM 1.0', state.pm1_0),
                const SizedBox(height: 16),
                _buildReadingCard('PM 2.5', state.pm2_5),
                const SizedBox(height: 16),
                _buildReadingCard('PM 10', state.pm10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadingCard(String label, int value) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$value µg/m³',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
