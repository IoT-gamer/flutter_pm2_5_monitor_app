import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/pm_sensor_state.dart';

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
                _buildChart(context, state),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Hourly PM2.5 Readings (µg/m³)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildReadingsList(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(BuildContext context, PMSensorState state) {
    return SizedBox(
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
                        value.toInt() < state.historicalData.length) {
                      final time =
                          state.historicalData[value.toInt()].timeOfDay;
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
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
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(value.toInt().toString()),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.shade300),
            ),
            minX: 0,
            maxX: (state.historicalData.length - 1).toDouble(),
            minY: 0,
            maxY: _calculateMaxY(state),
            lineBarsData: [
              _buildPM1LineData(state),
              _buildPM25LineData(state),
              _buildPM10LineData(state),
            ],
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildPM1LineData(PMSensorState state) {
    return LineChartBarData(
      spots: state.historicalData.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.pm1_0.toDouble());
      }).toList(),
      isCurved: true,
      color: Colors.blue,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _buildPM25LineData(PMSensorState state) {
    return LineChartBarData(
      spots: state.historicalData.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.pm2_5.toDouble());
      }).toList(),
      isCurved: true,
      color: Colors.green,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _buildPM10LineData(PMSensorState state) {
    return LineChartBarData(
      spots: state.historicalData.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.pm10.toDouble());
      }).toList(),
      isCurved: true,
      color: Colors.red,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _calculateMaxY(PMSensorState state) {
    double maxPM1 = 0;
    double maxPM25 = 0;
    double maxPM10 = 0;

    for (var reading in state.historicalData) {
      if (reading.pm1_0 > maxPM1) maxPM1 = reading.pm1_0.toDouble();
      if (reading.pm2_5 > maxPM25) maxPM25 = reading.pm2_5.toDouble();
      if (reading.pm10 > maxPM10) maxPM10 = reading.pm10.toDouble();
    }

    return [maxPM1, maxPM25, maxPM10]
            .reduce((max, value) => max > value ? max : value) *
        1.2;
  }

  Widget _buildReadingsList(BuildContext context, PMSensorState state) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.historicalData.length,
      itemBuilder: (context, index) {
        final reading = state.historicalData[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time: ${reading.timeOfDay.format(context)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReadingColumn('PM 1.0', reading.pm1_0),
                    _buildReadingColumn('PM 2.5', reading.pm2_5),
                    _buildReadingColumn('PM 10', reading.pm10),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingColumn(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value µg/m³',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
