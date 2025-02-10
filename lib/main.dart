import 'package:fl_chart/fl_chart.dart';
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
const String historyCharUUID = "91bad496-b950-4226-aa2b-4ede9fa42f59";

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
  List<HistoricalReading> historicalData = [];
  bool isLoadingHistory = false;

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

  void updateHistoricalData(List<HistoricalReading> data) {
    historicalData = data;
    notifyListeners();
  }
}

// Historical reading model
class HistoricalReading {
  final DateTime timestamp;
  final int pm1_0;
  final int pm2_5;
  final int pm10;

  HistoricalReading({
    required this.timestamp,
    required this.pm1_0,
    required this.pm2_5,
    required this.pm10,
  });

  factory HistoricalReading.fromString(String data) {
    final parts = data.split(',');
    return HistoricalReading(
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0]) * 1000),
      pm1_0: int.parse(parts[1]),
      pm2_5: int.parse(parts[2]),
      pm10: int.parse(parts[3]),
    );
  }
}

// Historical Data Screen
class HistoricalDataScreen extends StatelessWidget {
  const HistoricalDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical Data'),
      ),
      body: Consumer<PMSensorState>(
        builder: (context, state, child) {
          if (state.isLoadingHistory) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.historicalData.isEmpty) {
            return const Center(child: Text('No historical data available'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 300,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() <
                                        state.historicalData.length) {
                                  return Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      '${state.historicalData[value.toInt()].timestamp.hour}:00',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots:
                                state.historicalData.asMap().entries.map((e) {
                              return FlSpot(
                                  e.key.toDouble(), e.value.pm2_5.toDouble());
                            }).toList(),
                            isCurved: true,
                            color: Colors.blue,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Hourly PM2.5 Readings (µg/m³)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.historicalData.length,
                  itemBuilder: (context, index) {
                    final reading = state.historicalData[index];
                    return ListTile(
                      title: Text(
                        'Time: ${reading.timestamp.hour}:00',
                      ),
                      subtitle: Text(
                        'PM1.0: ${reading.pm1_0} µg/m³\n'
                        'PM2.5: ${reading.pm2_5} µg/m³\n'
                        'PM10: ${reading.pm10} µg/m³',
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
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

  Future<void> _fetchHistoricalData(BluetoothService service) async {
    final state = Provider.of<PMSensorState>(context, listen: false);
    state.isLoadingHistory = true;

    try {
      final characteristic = service.characteristics
          .firstWhere((c) => c.uuid.toString() == historyCharUUID);

      final value = await characteristic.read();
      final String historyStr = String.fromCharCodes(value);

      final readings = historyStr
          .split('\n')
          .where((line) => line.isNotEmpty)
          .map((line) => HistoricalReading.fromString(line))
          .toList();

      state.updateHistoricalData(readings);
    } catch (e) {
      if (mounted) {
        _showError('Failed to fetch historical data: ${e.toString()}');
      }
    } finally {
      state.isLoadingHistory = false;
    }
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
          // Fetch historical data
          await _fetchHistoricalData(service);
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoricalDataScreen(),
                      ),
                    );
                  },
                  child: const Text('View Historical Data'),
                ),
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
