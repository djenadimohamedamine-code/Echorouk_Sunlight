import 'package:flutter/material.dart';
import '../services/easy_remote_service.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // IP du PC Sunlite Suite 3 (validée par capture réseau : 169.254.83.107)
  final String sunliteIp = '169.254.83.107';
  late EasyRemoteService _easyRemote;
  bool _connected = false;

  // Valeurs des 5 sliders (0.0 à 255.0)
  List<double> values = List.filled(5, 0.0);

  // Mapping validé par capture : id=0 = Master, id=1..4 = projecteurs (page 0)
  final List<Map<String, dynamic>> fixtures = [
    {'name': 'Master', 'type': 'master', 'elementId': 0, 'color': Colors.blueAccent},
    {'name': 'Projo 1', 'type': 'projector', 'elementId': 1, 'color': Colors.amber},
    {'name': 'Projo 2', 'type': 'projector', 'elementId': 2, 'color': Colors.amber},
    {'name': 'Projo 3', 'type': 'projector', 'elementId': 3, 'color': Colors.amber},
    {'name': 'Projo 4', 'type': 'projector', 'elementId': 4, 'color': Colors.amber},
  ];

  @override
  void initState() {
    super.initState();
    _easyRemote = EasyRemoteService(
      ipAddress: sunliteIp,
      onConnected: () {
        setState(() => _connected = true);
        print('EasyRemote: connected to Suite3');
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
    int elementId = fixtures[index]['elementId'];
    _easyRemote.setSlider(elementId, value / 255.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mimo Sunlight — Console Lumière'),
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
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
          childAspectRatio: 0.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: fixtures.length,
        itemBuilder: (context, index) {
          return _buildFader(index, fixtures[index]);
        },
      ),
    );
  }

  Widget _buildFader(int index, Map<String, dynamic> fixture) {
    final String name = fixture['name'];
    final Color color = fixture['color'];
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
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
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
                  max: 255,
                  activeColor: color,
                  inactiveColor: Colors.grey[800],
                  onChanged: (val) => _onSliderChanged(index, val),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              '${(values[index] / 255.0 * 100).round()}%',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
