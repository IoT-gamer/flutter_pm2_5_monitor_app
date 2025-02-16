import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'historical_reading.dart';

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
