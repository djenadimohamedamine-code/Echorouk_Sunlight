import 'dart:io';
import 'dart:typed_data';

class OscService {
  final String ipAddress;
  final int port = 6454; // Art-Net UDP Port
  RawDatagramSocket? _socket;

  // Stocke les valeurs DMX (0-255) pour 512 canaux (0 = Ch 1)
  final List<int> _dmxData = List.filled(512, 0);

  OscService({required this.ipAddress});

  Future<void> connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      print('Art-Net Socket bound, sending to $ipAddress:$port');
    } catch (e) {
      print('Error binding socket: $e');
    }
  }

  /// address = fixtureId (1-512), value = 0.0 à 1.0 (float)
  void sendFixtureDimmer(int fixtureId, double value) {
    if (_socket == null) return;
    
    // Convert float to DMX 0-255
    int dmxValue = (value * 255).round().clamp(0, 255);
    
    if (fixtureId > 0 && fixtureId <= 512) {
      _dmxData[fixtureId - 1] = dmxValue;
    }
    
    _sendArtDmx();
  }

  void _sendArtDmx() {
    final bytes = BytesBuilder();
    
    // ID: "Art-Net" + Null byte
    bytes.add([0x41, 0x72, 0x74, 0x2d, 0x4e, 0x65, 0x74, 0x00]);
    
    // OpCode: OpDmx (0x5000 in little endian -> 0x00, 0x50)
    bytes.add([0x00, 0x50]);
    
    // Protocol Version: 14 (big endian -> 0x00, 0x0e)
    bytes.add([0x00, 0x0e]);
    
    // Sequence (0)
    bytes.add([0x00]);
    
    // Physical (0)
    bytes.add([0x00]);
    
    // Sub-Net / Universe (0x00, 0x00 = Universe 0)
    bytes.add([0x00, 0x00]);
    
    // Length: 512 (big endian -> 0x02, 0x00)
    bytes.add([0x02, 0x00]);
    
    // Data (512 channels)
    bytes.add(_dmxData);
    
    _socket?.send(bytes.toBytes(), InternetAddress(ipAddress), port);
  }

  void dispose() {
    _socket?.close();
  }
}
