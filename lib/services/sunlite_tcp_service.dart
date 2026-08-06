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
  final int index; // order index left-to-right

  SunliteSlider({
    required this.uuid,
    required this.value,
    required this.posX,
    this.label = '',
    this.index = 0,
  });
}

/// TCP-based service for Sunlite Suite 3 control via port 2431.
class SunliteTcpService {
  final String ipAddress;
  final int port;
  final void Function()? onConnected;
  final void Function(String error)? onError;
  final void Function(List<SunliteSlider> sliders)? onSlidersUpdated;

  List<SunliteSlider> _sliders = [];
  Timer? _refreshTimer;
  bool _refreshPaused = false;
  bool _connected = false;
  bool _disposed = false;

  SunliteTcpService({
    required this.ipAddress,
    this.port = 2431,
    this.onConnected,
    this.onError,
    this.onSlidersUpdated,
  });

  bool get isConnected => _connected;
  List<SunliteSlider> get sliders => _sliders;

  /// Build a Sunlite protocol message
  Uint8List _buildMessage(String filename, [Map<String, dynamic>? payload]) {
    final builder = BytesBuilder();
    builder.add(utf8.encode('Sunlite_'));
    builder.addByte(0x1F);
    builder.addByte(0x00);
    final nameBytes = utf8.encode(filename);
    builder.add(nameBytes);
    for (int i = nameBytes.length; i < 34; i++) {
      builder.addByte(0x00);
    }
    if (payload != null) {
      final jsonStr = jsonEncode(payload);
      final jsonBytes = utf8.encode(jsonStr);
      final sizeBytes = ByteData(4);
      sizeBytes.setUint32(0, jsonBytes.length, Endian.little);
      builder.add(sizeBytes.buffer.asUint8List());
      builder.add(jsonBytes);
    } else {
      builder.add(Uint8List(4));
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

  /// Send a request on a fresh TCP connection
  Future<Map<String, dynamic>?> _sendRequest(
      String filename, [Map<String, dynamic>? payload]) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ipAddress, port,
          timeout: const Duration(seconds: 3));
      socket.add(_buildMessage(filename, payload));
      await socket.flush();
      if (payload == null) {
        return await _readResponse(socket);
      } else {
        await Future.delayed(const Duration(milliseconds: 50));
        return null;
      }
    } catch (e) {
      print('SunliteTCP: request error: $e');
      return null;
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  /// Fetch show.json and extract ALL vsliders sorted left-to-right
  Future<List<SunliteSlider>> _fetchAllSliders() async {
    final data = await _sendRequest('show.json');
    if (data == null) return [];

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

    // Sort left-to-right and assign index
    sliders.sort((a, b) => a.posX.compareTo(b.posX));
    final indexed = <SunliteSlider>[];
    for (int i = 0; i < sliders.length; i++) {
      final s = sliders[i];
      indexed.add(SunliteSlider(
        uuid: s.uuid,
        value: s.value,
        posX: s.posX,
        label: s.label,
        index: i,
      ));
    }
    return indexed;
  }

  /// Connect and get initial state
  Future<void> connect() async {
    if (_disposed) return;
    try {
      final sliders = await _fetchAllSliders();
      if (sliders.isNotEmpty) {
        _sliders = sliders;
        _connected = true;
        onConnected?.call();
        onSlidersUpdated?.call(sliders);
        print('SunliteTCP: connected, found ${sliders.length} sliders');
        _startRefresh();
      } else {
        _connected = false;
        onError?.call('No sliders found');
      }
    } catch (e) {
      _connected = false;
      onError?.call('Connection error: $e');
    }
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_refreshPaused || _disposed) return;
      await _refreshUuids();
    });
  }

  /// Refresh UUIDs silently — never update UI slider positions
  Future<void> _refreshUuids() async {
    try {
      final sliders = await _fetchAllSliders();
      if (sliders.isNotEmpty && !_disposed) {
        _sliders = sliders;
        if (!_connected) {
          _connected = true;
          onConnected?.call();
        }
      }
    } catch (e) {
      print('SunliteTCP: refresh error: $e');
      if (_connected) {
        _connected = false;
        onError?.call('Lost connection');
      }
    }
  }

  void pauseRefresh() { _refreshPaused = true; }

  Future<void> resumeRefresh() async {
    _refreshPaused = false;
    await _refreshUuids();
  }

  /// Set a specific slider value by its index (0 = leftmost = master)
  Future<void> setSliderValue(int index, double value) async {
    if (index < 0 || index >= _sliders.length) return;
    final uuid = _sliders[index].uuid;
    final payload = {
      'controls': [
        {'uuid': uuid, 'value': value}
      ]
    };
    await _sendRequest('update.json', payload);
  }

  /// Reconnect (e.g. after app resume)
  Future<void> reconnect() async {
    _refreshTimer?.cancel();
    _connected = false;
    await connect();
  }

  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
