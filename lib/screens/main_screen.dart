import 'package:flutter/material.dart';
import '../services/osc_service.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // IP FIXE du PC Sunlite
  final String sunliteIp = '192.168.1.50';
  late OscService _oscService;

  // Valeurs des 8 sliders (0.0 à 100.0)
  List<double> values = List.filled(8, 0.0);

  // Configuration en dur des 8 projecteurs
  final List<Map<String, dynamic>> fixtures = [
    {'name': 'Projo 1', 'dmx': 1},
    {'name': 'Projo 2', 'dmx': 2},
    {'name': 'Projo 3', 'dmx': 3},
    {'name': 'Projo 4', 'dmx': 4},
    {'name': 'Gobo 1',  'dmx': 5},
    {'name': 'Gobo 2',  'dmx': 6},
    {'name': 'Gobo 3',  'dmx': 7},
    {'name': 'Gobo 4',  'dmx': 8},
  ];

  @override
  void initState() {
    super.initState();
    _oscService = OscService(ipAddress: sunliteIp);
    _oscService.connect();
  }

  @override
  void dispose() {
    _oscService.dispose();
    super.dispose();
  }

  void _onSliderChanged(int index, double value) {
    setState(() {
      values[index] = value;
    });
    // Convertir 0-100% en DMX 0-255
    int dmxValue = (value * 2.55).round();
    int dmxAddress = fixtures[index]['dmx'];
    _oscService.sendDimmerValue(dmxAddress, dmxValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Echorouk Sunlight — Console Lumière'),
        backgroundColor: Colors.black,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                '● $sunliteIp',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      backgroundColor: Colors.grey[900],
      body: GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 8 : 4,
          childAspectRatio: 0.35,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: fixtures.length,
        itemBuilder: (context, index) {
          return _buildFader(index, fixtures[index]['name']);
        },
      ),
    );
  }

  Widget _buildFader(int index, String name) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 20,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 16),
                ),
                child: Slider(
                  value: values[index],
                  min: 0,
                  max: 100,
                  activeColor: Colors.amber,
                  inactiveColor: Colors.grey[800],
                  onChanged: (val) => _onSliderChanged(index, val),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              '${values[index].round()}%',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
