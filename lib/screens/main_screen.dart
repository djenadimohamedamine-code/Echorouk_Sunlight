import 'package:flutter/material.dart';
import '../services/sunlite_tcp_service.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  String sunliteIp = '192.168.1.7';
  late SunliteTcpService _sunliteService;
  bool _connected = false;
  String _statusText = 'Connexion...';

  List<SunliteSlider> _sliders = [];
  Map<int, double> _localValues = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sunliteService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quand on revient dans l'application, on force la reconnexion pour avoir les nouveaux UUIDs
      print("App resumed: reconnecting to get fresh UUIDs...");
      _reconnect();
    }
  }

  void _initService() {
    setState(() {
      _connected = false;
      _statusText = 'Connexion...';
    });

    _sunliteService = SunliteTcpService(
      ipAddress: sunliteIp,
      onConnected: () {
        if (mounted) {
          setState(() {
            _connected = true;
            _statusText = 'Connecté';
          });
        }
        print('Sunlite: connected via TCP 2431');
      },
      onError: (err) {
        print('Sunlite error: $err');
        if (mounted) {
          setState(() {
            _connected = false;
            _statusText = err;
          });
        }
      },
      onSlidersUpdated: (sliders) {
        if (mounted) {
          setState(() {
            _sliders = sliders;
            // Initialiser les valeurs locales avec les valeurs du serveur à la connexion
            for (var i = 0; i < sliders.length; i++) {
              _localValues[i] = sliders[i].value;
            }
          });
        }
      },
    );
    _sunliteService.connect();
  }

  void _changeIp() {
    final controller = TextEditingController(text: sunliteIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('IP du PC Sunlite', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Adresse IP',
            labelStyle: TextStyle(color: Colors.blueAccent),
            hintText: '192.168.1.7',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey)),
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
            child: Text('OK', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _reconnect() {
    _sunliteService.reconnect();
  }

  Widget _buildSliderItem(int index, SunliteSlider slider) {
    double val = _localValues[index] ?? slider.value;
    
    // Déterminer le nom du fader (Master pour le premier, Fader 2, Fader 3, etc. sinon)
    String label = slider.label.isNotEmpty ? slider.label : 'FADER ${index + 1}';
    if (index == 0 && slider.label.isEmpty) label = 'MASTER';

    bool isMaster = index == 0;
    Color accentColor = isMaster ? Colors.redAccent : Colors.blueAccent;

    return Container(
      width: 130,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _connected ? accentColor.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _connected ? accentColor.withOpacity(0.15) : Colors.transparent,
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        children: [
          SizedBox(height: 20),
          Text(
            label,
            style: TextStyle(
              color: _connected ? accentColor : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 16),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 24,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 20),
                  activeTrackColor: _connected ? accentColor : Colors.grey[600],
                  inactiveTrackColor: Colors.grey[900],
                  thumbColor: Colors.white,
                  overlayColor: accentColor.withOpacity(0.2),
                ),
                child: Slider(
                  value: val,
                  min: 0.0,
                  max: 1.0,
                  onChangeStart: (v) {
                    _sunliteService.pauseRefresh();
                  },
                  onChanged: (v) {
                    if (!_connected) return;
                    setState(() {
                      _localValues[index] = v;
                    });
                    _sunliteService.setSliderValue(index, v);
                  },
                  onChangeEnd: (v) {
                    if (!_connected) return;
                    _sunliteService.setSliderValue(index, v);
                    _sunliteService.resumeRefresh();
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Text(
              '${(val * 100).round()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text('Mimo Sunlight', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.black,
        elevation: 10,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _connected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _connected ? Colors.green : Colors.red)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _connected ? Icons.link : Icons.link_off,
                      color: _connected ? Colors.greenAccent : Colors.redAccent,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _connected ? 'CONNECTÉ' : 'DÉCONNECTÉ',
                      style: TextStyle(
                        color: _connected ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _reconnect,
            tooltip: 'Forcer la reconnexion',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            color: Colors.white,
            onPressed: _changeIp,
            tooltip: 'Changer l\'IP',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _sliders.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 24),
                  Text(
                    _statusText,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _sliders.length,
                itemBuilder: (context, index) {
                  return _buildSliderItem(index, _sliders[index]);
                },
              ),
            ),
    );
  }
}
