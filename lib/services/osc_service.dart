import 'dart:io';
import 'dart:typed_data';

class OscService {
  final String ipAddress;
  final int port;
  RawDatagramSocket? _socket;

  OscService({required this.ipAddress, this.port = 7000});

  Future<void> connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      print('OSC Service ready to send to $ipAddress:$port');
    } catch (e) {
      print('Error binding socket: $e');
    }
  }

  /// Envoie la valeur d'un fixture à Sunlite Suite 3
  /// address = OSC path, value = 0.0 à 1.0 (float)
  void sendFixtureDimmer(int fixtureId, double value) {
    if (_socket == null) return;
    final message = _encodeOscMessageFloat('/fixture/$fixtureId/dimmer', value);
    _socket?.send(message, InternetAddress(ipAddress), port);
  }

  void dispose() {
    _socket?.close();
  }

  /// Encode OSC avec un argument float (format Sunlite Suite 3)
  Uint8List _encodeOscMessageFloat(String address, double value) {
    final bytes = BytesBuilder();

    void writeString(String s) {
      bytes.add(s.codeUnits);
      bytes.addByte(0);
      while (bytes.length % 4 != 0) bytes.addByte(0);
    }

    void writeFloat(double v) {
      final b = Uint8List(4);
      b.buffer.asByteData().setFloat32(0, v, Endian.big);
      bytes.add(b);
    }

    writeString(address);
    writeString(',f'); // 'f' = float32
    writeFloat(value);

    return bytes.toBytes();
  }
}
