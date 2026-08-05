import 'package:flutter/material.dart';
import '../services/sunlite_service.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String sunliteIp = '192.168.1.6';
  late SunliteService _sunliteService;
  bool _connected = false;

  double masterValue = 0.0; // 0.0 to 1.0

  @override
  void initState() {
    super.initState();
    _initService();
  }

  void _initService() {
    _sunliteService = SunliteService(
      ipAddress: sunliteIp,
      onConnected: () {
        setState(() => _connected = true);
        print('Sunlite: connected');
      },
      onError: (err) {
        print('Sunlite error: $err');
        setState(() => _connected = false);
      },
    );
    _sunliteService.connect();
  }

  void _changeIp() {
    final controller = TextEditingController(text: sunliteIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('IP du PC Sunlite'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Adresse IP', hintText: '192.168.1.6'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                setState(() => sunliteIp = ip);
                _sunliteService.dispose();
                _initService();
              }
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sunliteService.dispose();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    setState(() {
      masterValue = value;
    });
    _sunliteService.setMaster(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mimo Sunlight — Master'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            color: Colors.white70,
            onPressed: _changeIp,
          ),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: BoxConstraints(maxWidth: 200, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 5,
                )
              ]
            ),
            child: Column(
              children: [
                SizedBox(height: 24),
                Text(
                  'MASTER',
                  style: TextStyle(
                    color: Colors.blueAccent, 
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    letterSpacing: 2
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 30,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 24),
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.grey[800],
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: masterValue,
                        min: 0.0,
                        max: 1.0,
                        onChanged: _onSliderChanged,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    '${(masterValue * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 32, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
