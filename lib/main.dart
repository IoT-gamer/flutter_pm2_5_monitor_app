import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/pm_sensor_state.dart';
import 'app.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => PMSensorState(),
      child: const MyApp(),
    ),
  );
}
