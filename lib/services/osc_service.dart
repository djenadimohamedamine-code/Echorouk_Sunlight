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

  void sendDimmerValue(int dmxAddress, int value) {
    if (_socket == null) return;
    final message = _encodeOscMessage('/dmx/$dmxAddress', [value]);
    _socket?.send(message, InternetAddress(ipAddress), port);
  }

  void dispose() {
    _socket?.close();
  }

  Uint8List _encodeOscMessage(String address, List<int> arguments) {
    final bytes = BytesBuilder();

    void writeString(String s) {
      bytes.add(s.codeUnits);
      bytes.addByte(0);
      while (bytes.length % 4 != 0) {
        bytes.addByte(0);
      }
    }

    void writeInt(int value) {
      final b = Uint8List(4);
      b.buffer.asByteData().setInt32(0, value, Endian.big);
      bytes.add(b);
    }

    writeString(address);

    final typeTags = StringBuffer(',');
    for (var i = 0; i < arguments.length; i++) {
      typeTags.write('i');
    }
    writeString(typeTags.toString());

    for (final arg in arguments) {
      writeInt(arg);
    }

    return bytes.toBytes();
  }
}
