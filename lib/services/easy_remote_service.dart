import 'dart:io';
import 'dart:async';

/// Client Dart autonome pour le protocole Sunlite Suite 3 "EasyRemote" (UDP 4003).
///
/// Protocole validé : Suite3 répond à `action=ready` et accepte
/// `action=update_element&id=ID&page=PAGE&value=V&type=btn|...`
/// pour commander des scènes/projecteurs.
class EasyRemoteService {
  final String ipAddress;
  final int port;
  final void Function()? onConnected;
  final void Function(String error)? onError;

  RawDatagramSocket? _socket;
  bool _ready = false;

  EasyRemoteService({
    required this.ipAddress,
    this.port = 4003,
    this.onConnected,
    this.onError,
  });

  bool get isReady => _ready;

  Future<void> connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.listen((event) {
        // ignore input events; EasyRemote mainly sends commands
      }, onError: (e) {
        onError?.call('Socket error: $e');
      });
      // Send init packet; Suite3 responds with layout (done/refresh).
      sendRaw('action=ready&width=0&height=0\r\n');
      // Mark as ready after init (we don't strictly need the layout to send updates)
      _ready = true;
      onConnected?.call();
      print('EasyRemote: ready to send commands to $ipAddress:$port');
    } catch (e) {
      onError?.call('Bind error: $e');
    }
  }

  void sendRaw(String message) {
    _socket?.send(
      message.codeUnits,
      InternetAddress(ipAddress),
      port,
    );
  }

  /// Sends an update_element command.
  ///
  /// page=1 is the main scene/page in the show.
  void updateElement({
    required int elementId,
    required int page,
    required int value,
    String type = 'btn',
    String event = 'up',
  }) {
    sendRaw('action=update_element&id=$elementId&page=$page&value=$value&type=$type&event=$event');
  }

  /// Activates/deactivates projecteur scène (button toggle).
  /// value=127 → on, value=0 → off
  void setProjector(int projectorId, double intensity) {
    int val = (intensity * 255).round().clamp(0, 255);
    updateElement(elementId: projectorId, page: 1, value: val, type: 'sld', event: 'move');
  }

  /// Set master fader (id=0 is usually the global master)
  void setMaster(double intensity) {
    int val = (intensity * 255).round().clamp(0, 255);
    updateElement(elementId: 0, page: 1, value: val, type: 'sld', event: 'move');
  }

  void dispose() {
    _socket?.close();
    _socket = null;
  }
}
