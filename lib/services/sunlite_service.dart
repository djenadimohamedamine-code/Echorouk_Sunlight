import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

class SunliteService {
  final String ipAddress;
  final void Function()? onConnected;
  final void Function(String error)? onError;

  RawDatagramSocket? _socket;

  SunliteService({
    required this.ipAddress,
    this.onConnected,
    this.onError,
  });

  Future<void> connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.listen((event) {});
      
      // Init EasyRemote
      sendEasyRemoteRaw('action=ready&width=0&height=0\r\n');
      
      onConnected?.call();
      print('SunliteService: ready to send commands to $ipAddress');
    } catch (e) {
      onError?.call('Bind error: $e');
    }
  }

  void sendEasyRemoteRaw(String message) {
    _socket?.send(message.codeUnits, InternetAddress(ipAddress), 4003);
  }

  void sendOscRaw(List<int> bytes) {
    _socket?.send(bytes, InternetAddress(ipAddress), 7000);
  }

  List<int> _buildOscMessage(String address, double value) {
    final builder = BytesBuilder();
    builder.add(address.codeUnits);
    builder.addByte(0);
    while (builder.length % 4 != 0) {
      builder.addByte(0);
    }
    builder.add([44, 102, 0, 0]);
    final bd = ByteData(4);
    bd.setFloat32(0, value, Endian.big);
    builder.add(bd.buffer.asUint8List());
    return builder.toBytes();
  }

  void setMaster(double intensity) {
    int val255 = (intensity * 255).round().clamp(0, 255);
    
    // 1. EASYREMOTE BLAST (On tape large pour etre sur que ca marche)
    for (int page in [0, 1, 2, 120, 121, 122]) {
      for (int eid = 0; eid < 10; eid++) {
        sendEasyRemoteRaw('action=update_element&id=$eid&page=$page&value=$val255&type=sld&event=move');
      }
    }
    
    // 2. OSC BLAST
    final oscAddrs = [
        '/master', '/master/dimmer', '/master/intensity', '/masterdimmer',
        '/dimmer/master', '/grandmaster', '/page/_MASTER/dimmer', '/page/120/dimmer',
        '/page/0/dimmer', '/console/master', '/dmx/master',
        '/1/dimmer', '/2/dimmer', '/0/dimmer',
        '/fader/0', '/fader/1', '/slider/0', '/slider/1'
    ];
    for (final addr in oscAddrs) {
      sendOscRaw(_buildOscMessage(addr, intensity));
    }
  }

  void dispose() {
    _socket?.close();
    _socket = null;
  }
}
