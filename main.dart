import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(SoilTesterApp());
}

class SoilTesterApp extends StatefulWidget {
  @override
  _SoilTesterAppState createState() => _SoilTesterAppState();
}

class _SoilTesterAppState extends State<SoilTesterApp> {
  // Create a proper instance of MqttServerClient
  late MqttServerClient client;
  String soilStatus = "Unknown";
  String temperature = "--";
  String humidity = "--";
  String moisture = "--";
  bool irrigationOn = false;

  @override
  void initState() {
    super.initState();
    // Initialize client in initState
    client = MqttServerClient('broker.hivemq.com', 'flutter_client');
    _connectMQTT();
  }

  Future<void> _connectMQTT() async {
    client.port = 1883;
    client.keepAlivePeriod = 60;
    client.onConnected = () {
      // Use logger instead of print in production
      debugPrint('Connected to MQTT broker');
      client.subscribe('soil/data', MqttQos.atMostOnce);
    };

    // Set up proper message handler
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        final MqttPublishMessage publishMessage = message.payload as MqttPublishMessage;
        final String payload = MqttPublishPayload.bytesToStringAsString(
            publishMessage.payload.message);
        _processMQTTMessage(payload);
      }
    });

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Failed to connect: $e');
    }
  }

  void _processMQTTMessage(String message) {
    List<String> data = message.split(',');
    if (data.length == 3) {
      setState(() {
        temperature = data[0];
        humidity = data[1];
        moisture = data[2];
        soilStatus = _getSoilStatus(double.tryParse(moisture) ?? 0);
      });
    }
  }

  String _getSoilStatus(double moisture) {
    if (moisture < 30) return "Dry - Needs Irrigation";
    if (moisture < 60) return "Moderate - Okay";
    return "Wet - No Irrigation Needed";
  }

  void _toggleIrrigation() {
    setState(() {
      irrigationOn = !irrigationOn;
    });
    
    // Fix the payload builder
    final builder = MqttClientPayloadBuilder();
    builder.addString(irrigationOn ? "ON" : "OFF");
    
    client.publishMessage(
      'soil/irrigation',
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Soil Tester'),
          elevation: 4,
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildTile("Soil Status", soilStatus),
                    _buildTile("Temperature", "$temperature°C"),
                    _buildTile("Humidity", "$humidity%"),
                    _buildTile("Moisture", "$moisture%"),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _toggleIrrigation,
                icon: Icon(irrigationOn ? Icons.water_drop : Icons.water_drop_outlined),
                label: Text(irrigationOn ? "Stop Irrigation" : "Start Irrigation"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(String title, String value) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.black87
              )
            ),
            SizedBox(height: 10),
            Text(
              value, 
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: title == "Soil Status" 
                  ? _getSoilStatusColor(value)
                  : Colors.black
              )
            ),
          ],
        ),
      ),
    );
  }

  Color _getSoilStatusColor(String status) {
    if (status.contains("Dry")) return Colors.orange;
    if (status.contains("Moderate")) return Colors.blue;
    if (status.contains("Wet")) return Colors.green;
    return Colors.grey;
  }

  @override
  void dispose() {
    // Clean up MQTT connection when widget is disposed
    client.disconnect();
    super.dispose();
  }
}