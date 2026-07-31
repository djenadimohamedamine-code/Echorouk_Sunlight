import 'dart:io';
import 'package:osc/osc.dart';

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
    final message = OSCMessage(
      '/dmx/$dmxAddress',
      arguments: [value],
    );
    final bytes = message.toBytes();
    _socket?.send(bytes, InternetAddress(ipAddress), port);
  }

  void dispose() {
    _socket?.close();
  }
}
