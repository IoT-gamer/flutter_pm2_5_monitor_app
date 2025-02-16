import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/ble_constants.dart';
import '../models/historical_reading.dart';
import '../models/pm_sensor_state.dart';

class BLEService {
  final PMSensorState state;
  final Function(String) onError;
  final BuildContext context;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  BLEService({
    required this.state,
    required this.onError,
    required this.context,
  });

  Future<void> checkPermissions() async {
    final connectPermission = await Permission.bluetoothConnect.request();
    final scanPermission = await Permission.bluetoothScan.request();
    final locationPermission = await Permission.location.request();

    if (connectPermission.isDenied ||
        scanPermission.isDenied ||
        locationPermission.isDenied) {
      onError('Please grant permissions to use the app');
    }
  }

  Future<bool> checkBluetoothScanState() async {
    return await FlutterBluePlus.adapterState
        .firstWhere((element) =>
            element == BluetoothAdapterState.on ||
            element == BluetoothAdapterState.off ||
            element == BluetoothAdapterState.unknown)
        .then((s) {
      if (s == BluetoothAdapterState.off) {
        onError('Please enable Bluetooth to use the app');
        return false;
      }
      return true;
    });
  }

  Future<void> startScan(Function(bool) onScanningChanged) async {
    if (!await checkBluetoothScanState()) {
      return;
    }

    onScanningChanged(true);
    _scanSubscription?.cancel();

    // Start scanning
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.platformName == deviceName) {
          connect(result.device);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    // Stop scanning after timeout
    Future.delayed(const Duration(seconds: 10), () {
      onScanningChanged(false);
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect();
      if (!context.mounted) return;
      state.setDevice(device);

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      if (!context.mounted) return;

      // Find our service
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUUID) {
          // First sync the time
          await _syncTime(service);

          // Set up notifications for each characteristic
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if ([pm1_0CharUUID, pm2_5CharUUID, pm10CharUUID]
                .contains(characteristic.uuid.toString())) {
              await characteristic.setNotifyValue(true);
              if (!context.mounted) return;
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
          // Fetch historical data
          await fetchHistoricalData(service);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      onError('Failed to connect: ${e.toString()}');
      state.setDevice(null);
    }
  }

  Future<void> fetchHistoricalData(BluetoothService service) async {
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
      if (context.mounted) {
        onError('Failed to fetch historical data: ${e.toString()}');
      }
    } finally {
      state.isLoadingHistory = false;
    }
  }

  Future<void> _syncTime(BluetoothService service) async {
    try {
      final characteristic = service.characteristics
          .firstWhere((c) => c.uuid.toString() == timeSyncCharUUID);

      // Convert local time to Unix timestamp and add timezone offset
      final now = DateTime.now();
      final timestamp =
          (now.millisecondsSinceEpoch ~/ 1000) + now.timeZoneOffset.inSeconds;

      final bytes = Uint8List(8);
      final byteData = ByteData.view(bytes.buffer);
      byteData.setUint64(0, timestamp, Endian.little);

      await characteristic.write(bytes);
    } catch (e) {
      if (context.mounted) {
        onError('Failed to sync time: ${e.toString()}');
      }
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
  }
}
