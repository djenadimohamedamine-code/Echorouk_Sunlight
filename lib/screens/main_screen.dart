import 'package:flutter/material.dart';
import '../services/easy_remote_service.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // IP FIXE du PC Sunlite Suite 3
  final String sunliteIp = '192.168.1.6';
  late EasyRemoteService _easyRemote;
  bool _connected = false;
  int _elementCount = 0;

  // Valeurs des 8 sliders (0.0 à 100.0)
  List<double> values = List.filled(8, 0.0);

  // Configuration des 8 projecteurs avec leur ID EasyRemote (page 1).
  // D'après le layout reçu de Suite3, les boutons scène page 1 sont id=2..11.
  final List<Map<String, dynamic>> fixtures = [
    {'name': 'Projo 1', 'control_id': 2},
    {'name': 'Projo 2', 'control_id': 3},
    {'name': 'Projo 3', 'control_id': 4},
    {'name': 'Projo 4', 'control_id': 5},
    {'name': 'Gobo 1', 'control_id': 6},
    {'name': 'Gobo 2', 'control_id': 7},
    {'name': 'Gobo 3', 'control_id': 8},
    {'name': 'Gobo 4', 'control_id': 9},
  ];

  @override
  void initState() {
    super.initState();
    _easyRemote = EasyRemoteService(
      ipAddress: sunliteIp,
      onConnected: () {
        setState(() {
          _connected = true;
          _elementCount = _easyRemote.elements.length;
        });
        print('EasyRemote: console layout loaded ($_elementCount elements)');
      },
      onMessage: (msg) {
        // Optionnel: log des messages
      },
      onError: (err) {
        print('EasyRemote error: $err');
        setState(() => _connected = false);
      },
    );
    _easyRemote.connect();
  }

  @override
  void dispose() {
    _easyRemote.dispose();
    super.dispose();
  }

  void _onSliderChanged(int index, double value) {
    setState(() {
      values[index] = value;
    });
    // Convertir 0-100% en DMX 0-255
    int dmxValue = (value * 2.55).round().clamp(0, 255);
    int controlId = fixtures[index]['control_id'];
    // La console Echorouk utilise des sliders (type=sld) pour les projecteurs.
    _easyRemote.setSlider(1, controlId, dmxValue);
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
                '${_connected ? "●" : "○"} $sunliteIp',
                style: TextStyle(
                  color: _connected ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
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
