import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pm_sensor_state.dart';
import '../services/ble_service.dart';
import '../widgets/reading_card.dart';
import 'historical_data_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late BLEService _bleService;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _bleService = BLEService(
      state: Provider.of<PMSensorState>(context, listen: false),
      onError: _showError,
      context: context,
    );
    _bleService.checkPermissions();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startScan() async {
    await _bleService.startScan((isScanning) {
      if (mounted) {
        setState(() => _isScanning = isScanning);
      }
    });
  }

  @override
  void dispose() {
    _bleService.dispose();
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
                ReadingCard(label: 'PM 1.0', value: state.pm1_0),
                const SizedBox(height: 16),
                ReadingCard(label: 'PM 2.5', value: state.pm2_5),
                const SizedBox(height: 16),
                ReadingCard(label: 'PM 10', value: state.pm10),
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
}
