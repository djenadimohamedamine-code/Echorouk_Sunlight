import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Represents a vslider control discovered from show.json
class SunliteSlider {
  final String uuid;
  final double value;
  final double posX;
  final String label;

  SunliteSlider({
    required this.uuid,
    required this.value,
    required this.posX,
    this.label = '',
  });
}

/// TCP-based service for Sunlite Suite 3 control via port 2431.
///
/// Protocol (reverse-engineered):
///   Header = b'Sunlite_' (8) + 0x1F 0x00 (2) + filename padded to 34 bytes + 4-byte LE payload size
///   Total header = 48 bytes
///   For show.json: payload size = 0, server replies with JSON containing controls
///   For update.json: payload = JSON with {"controls":[{"uuid":"...","value":0.5}]}
class SunliteTcpService {
  final String ipAddress;
  final int port;
  final void Function()? onConnected;
  final void Function(String error)? onError;
  final void Function(double value)? onMasterValueChanged;

  String? _masterUuid;
  double _lastKnownValue = 0.0;
  Timer? _refreshTimer;
  bool _refreshPaused = false;
  bool _connected = false;
  bool _disposed = false;

  SunliteTcpService({
    required this.ipAddress,
    this.port = 2431,
    this.onConnected,
    this.onError,
    this.onMasterValueChanged,
  });

  bool get isConnected => _connected;
  String? get masterUuid => _masterUuid;

  /// Build a Sunlite protocol message
  Uint8List _buildMessage(String filename, [Map<String, dynamic>? payload]) {
    final builder = BytesBuilder();

    // 8-byte magic header
    builder.add(utf8.encode('Sunlite_'));

    // 2-byte separator
    builder.addByte(0x1F);
    builder.addByte(0x00);

    // Filename padded to 34 bytes
    final nameBytes = utf8.encode(filename);
    builder.add(nameBytes);
    for (int i = nameBytes.length; i < 34; i++) {
      builder.addByte(0x00);
    }

    // 4-byte little-endian payload size + payload
    if (payload != null) {
      final jsonStr = jsonEncode(payload);
      final jsonBytes = utf8.encode(jsonStr);
      final sizeBytes = ByteData(4);
      sizeBytes.setUint32(0, jsonBytes.length, Endian.little);
      builder.add(sizeBytes.buffer.asUint8List());
      builder.add(jsonBytes);
    } else {
      builder.add(Uint8List(4)); // size = 0
    }

    return builder.toBytes();
  }

  /// Read a full response from the TCP socket
  Future<Map<String, dynamic>?> _readResponse(Socket socket) async {
    final completer = Completer<Map<String, dynamic>?>();
    final buffer = BytesBuilder();
    int? expectedPayloadSize;
    bool headerRead = false;

    late StreamSubscription sub;
    Timer? timeout;

    timeout = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        sub.cancel();
        completer.complete(null);
      }
    });

    sub = socket.listen(
      (data) {
        buffer.add(data);
        final bytes = buffer.toBytes();

        if (!headerRead && bytes.length >= 48) {
          // Parse header
          final bd = ByteData.sublistView(Uint8List.fromList(bytes.sublist(44, 48)));
          expectedPayloadSize = bd.getUint32(0, Endian.little);
          headerRead = true;
        }

        if (headerRead && expectedPayloadSize != null) {
          final totalExpected = 48 + expectedPayloadSize!;
          if (bytes.length >= totalExpected) {
            timeout?.cancel();
            sub.cancel();
            try {
              final payloadBytes = bytes.sublist(48, totalExpected);
              final jsonStr = utf8.decode(payloadBytes);
              final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
              if (!completer.isCompleted) completer.complete(parsed);
            } catch (e) {
              if (!completer.isCompleted) completer.complete(null);
            }
          }
        }
      },
      onError: (e) {
        timeout?.cancel();
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        timeout?.cancel();
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }

  /// Send a single request and get the response on a fresh TCP connection
  Future<Map<String, dynamic>?> _sendRequest(
      String filename, [Map<String, dynamic>? payload]) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ipAddress, port,
          timeout: const Duration(seconds: 3));
      socket.add(_buildMessage(filename, payload));
      await socket.flush();

      if (payload == null) {
        // Expect a response (show.json)
        return await _readResponse(socket);
      } else {
        // update.json — fire and forget, no response expected
        await Future.delayed(const Duration(milliseconds: 50));
        return null;
      }
    } catch (e) {
      print('SunliteTCP: request error: $e');
      return null;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// Fetch show.json and extract the master slider (leftmost vslider)
  Future<SunliteSlider?> _fetchMasterSlider() async {
    final data = await _sendRequest('show.json');
    if (data == null) return null;

    final pages = data['pages'] as List<dynamic>? ?? [];
    final sliders = <SunliteSlider>[];

    for (final page in pages) {
      final controls = (page as Map<String, dynamic>)['controls']
          as List<dynamic>? ?? [];
      for (final ctrl in controls) {
        final c = ctrl as Map<String, dynamic>;
        if (c['type'] == 'vslider') {
          sliders.add(SunliteSlider(
            uuid: c['uuid'] as String,
            value: (c['value'] as num?)?.toDouble() ?? 0.0,
            posX: (c['posX'] as num?)?.toDouble() ?? 0.0,
            label: c['label'] as String? ?? '',
          ));
        }
      }
    }

    if (sliders.isEmpty) return null;

    // Master = leftmost slider (smallest posX)
    sliders.sort((a, b) => a.posX.compareTo(b.posX));
    return sliders.first;
  }

  /// Connect and start periodic UUID refresh
  Future<void> connect() async {
    if (_disposed) return;

    try {
      // First connection: get the master slider
      final master = await _fetchMasterSlider();
      if (master != null) {
        _masterUuid = master.uuid;
        _lastKnownValue = master.value;
        _connected = true;
        onConnected?.call();
        onMasterValueChanged?.call(master.value);
        print('SunliteTCP: connected, master uuid=${master.uuid} '
            'value=${master.value}');

        // Start periodic refresh every 3 seconds
        _startRefresh();
      } else {
        _connected = false;
        onError?.call('No vslider found in show.json');
      }
    } catch (e) {
      _connected = false;
      onError?.call('Connection error: $e');
    }
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_refreshPaused || _disposed) return;
      await _refreshUuid();
    });
  }

  Future<void> _refreshUuid() async {
    try {
      final master = await _fetchMasterSlider();
      if (master != null && !_disposed) {
        _masterUuid = master.uuid;
        if (!_refreshPaused) {
          _lastKnownValue = master.value;
          onMasterValueChanged?.call(master.value);
        }
        if (!_connected) {
          _connected = true;
          onConnected?.call();
        }
      }
    } catch (e) {
      print('SunliteTCP: refresh error: $e');
      if (_connected) {
        _connected = false;
        onError?.call('Lost connection: $e');
      }
    }
  }

  /// Pause UUID refresh during drag
  void pauseRefresh() {
    _refreshPaused = true;
  }

  /// Resume UUID refresh after drag ends, and fetch fresh UUID
  Future<void> resumeRefresh() async {
    _refreshPaused = false;
    await _refreshUuid();
  }

  /// Set master value (0.0 to 1.0)
  Future<void> setMaster(double intensity) async {
    final uuid = _masterUuid;
    if (uuid == null) {
      print('SunliteTCP: no master UUID, refreshing...');
      await _refreshUuid();
      if (_masterUuid == null) return;
    }

    final actualUuid = _masterUuid!;
    final payload = {
      'controls': [
        {'uuid': actualUuid, 'value': intensity}
      ]
    };

    await _sendRequest('update.json', payload);
  }

  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
