import 'package:flutter/material.dart';

class HistoricalReading {
  final TimeOfDay timeOfDay;
  final int pm1_0;
  final int pm2_5;
  final int pm10;

  HistoricalReading({
    required this.timeOfDay,
    required this.pm1_0,
    required this.pm2_5,
    required this.pm10,
  });

  factory HistoricalReading.fromString(String data) {
    final parts = data.split(',');
    if (parts.length < 4) throw FormatException('Invalid data format');

    final timeParts = parts[0].split(':');
    final timeOfDay = TimeOfDay(
        hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));

    return HistoricalReading(
      timeOfDay: timeOfDay,
      pm1_0: int.parse(parts[1]),
      pm2_5: int.parse(parts[2]),
      pm10: int.parse(parts[3]),
    );
  }
}
