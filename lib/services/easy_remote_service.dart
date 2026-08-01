import 'dart:io';
import 'dart:async';

/// Client Dart pour le protocole Sunlite Suite 3 "EasyRemote" (UDP 4003).
///
/// Protocole validé : Suite3 répond à `action=ready` avec la description
/// des pages (`set_page_layer`/`add_element`/`set_layer`/`done`) puis
/// accepte `action=update_element&id=ID&page=PAGE&value=V`.
class EasyRemoteService {
  final String ipAddress;
  final int port;
  final void Function(String message)? onMessage;
  final void Function()? onConnected;
  final void Function(String error)? onError;

  RawDatagramSocket? _socket;
  final List<EasyRemoteElement> elements = [];
  bool _ready = false;

  EasyRemoteService({
    required this.ipAddress,
    this.port = 4003,
    this.onMessage,
    this.onConnected,
    this.onError,
  });

  /// Liste des éléments (pages) reçus après l'init.
  Map<int, List<EasyRemoteElement>> get pages {
    final Map<int, List<EasyRemoteElement>> result = {};
    for (final e in elements) {
      result.putIfAbsent(e.page, () => []).add(e);
    }
    return result;
  }

  Future<void> connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.openRead().listen(_onData);
      _socket?.listen(_onErrorState, onError: (e) {
        onError?.call('Socket error: $e');
      });
      // Demande la description de la console (EasyRemote handshake).
      sendRaw('action=ready&width=0&height=0\r\n');
      print('EasyRemote: connected, requesting console layout from $ipAddress:$port');
    } catch (e) {
      onError?.call('Bind error: $e');
    }
  }

  void _onData(RawSocketEvent event) {
    if (_socket == null || _socket!.available() <= 0) return;
    final dg = _socket!.receive();
    if (dg == null) return;
    final msg = String.fromCharCodes(dg.data);
    onMessage?.call(msg);
    _handleMessage(msg);
  }

  void _onErrorState(RawSocketEvent event) {
    // nothing, errors handled via onError callback
  }

  void _handleMessage(String message) {
    for (final line in message.split(RegExp(r'[\r\n]+'))) {
      if (line.isEmpty) continue;
      _parseLine(line);
    }
  }

  void _parseLine(String line) {
    final p = Uri.splitQueryString(line);
    final action = p['action'];
    if (action == null) return;

    switch (action) {
      case 'clear_screen':
        elements.clear();
        break;
      case 'object_count':
        break;
      case 'set_page_layer':
        // setCurrentPage
        break;
      case 'add_element':
        final id = int.tryParse(p['id'] ?? '') ?? 0;
        final page = int.tryParse(p['page'] ?? '0') ?? 0;
        final type = p['type'] ?? '';
        elements.add(EasyRemoteElement(
          id: id,
          page: page,
          type: type,
          value: p['value'] ?? '',
          x: _parseInt(p['x']),
          y: _parseInt(p['y']),
          width: _parseInt(p['width']),
          height: _parseInt(p['height']),
          extra: p,
        ));
        break;
      case 'set_layer':
        // update existing element's layer metadata
        final id = int.tryParse(p['id'] ?? '') ?? 0;
        final page = int.tryParse(p['page'] ?? '0') ?? 0;
        final el = elements.firstWhere(
          (e) => e.id == id && e.page == page,
          orElse: () => EasyRemoteElement(id: id, page: page, type: ''),
        );
        el.extra.addAll(p);
        if (!elements.contains(el)) elements.add(el);
        break;
      case 'done':
        _ready = true;
        onConnected?.call();
        break;
      case 'set_value':
        // feedback value update from console
        break;
    }
  }

  static int _parseInt(String? s) => int.tryParse(s ?? '') ?? 0;

  void sendRaw(String message) {
    _socket?.send(
      message.codeUnits,
      InternetAddress(ipAddress),
      port,
    );
  }

  /// Envoie une commande de mise à jour sur un contrôle.
  ///
  /// [elementId] = ID du contrôle (ex. 2 pour le premier bouton de scène).
  /// [page] = page de la console (ex. 1).
  /// [value] = niveau 0-255 (ou 0-65535 selon le type).
  /// [event] = 'up' (relâché), 'down' (appuyé), 'move' (glissé).
  void updateElement({
    required int elementId,
    required int page,
    required int value,
    String type = 'btn',
    String event = 'up',
  }) {
    final msg = 'action=update_element&id=$elementId&page=$page&value=$value&type=$type&event=$event';
    sendRaw(msg);
  }

  /// Active une scène (bouton) sur une page donnée.
  void triggerScene(int page, int elementId) {
    updateElement(elementId: elementId, page: page, value: 127, type: 'btn', event: 'up');
  }

  /// Positionne un slider (fader/chaser) sur une page.
  void setSlider(int page, int elementId, int value) {
    updateElement(elementId: elementId, page: page, value: value, type: 'sld', event: 'move');
  }

  bool get isReady => _ready;

  void dispose() {
    _socket?.close();
    _socket = null;
  }
}

class EasyRemoteElement {
  final int id;
  final int page;
  final String type;
  final String value;
  final int x, y, width, height;
  final Map<String, String> extra = {};

  EasyRemoteElement({
    required this.id,
    required this.page,
    required this.type,
    this.value = '',
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
  });

  bool operator ==(Object other) =>
      other is EasyRemoteElement && id == other.id && page == other.page;
  int get hashCode => Object.hash(id, page);
}
