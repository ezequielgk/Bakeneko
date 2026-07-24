import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakeneko/core/daemon/rpc.dart';
import 'package:bakeneko/core/xdg.dart';
import 'package:path/path.dart' as p;

/// Cliente del daemon de parsers sobre socket Unix de dominio.
///
/// Ciclo de vida:
/// - [start] ubica el fat JAR, spawnea `java -jar`, espera al socket y
///   conecta. Reintenta con backoff hasta [connectTimeout].
/// - [call] envía una request JSON-RPC y espera su respuesta (id match).
/// - [stop] cierra el socket y mata el proceso hijo.
///
/// Diseño suposición: el daemon contesta en orden (no hay pipelining),
/// por lo que mantenemos una única pending request. Suficiente y mantenible.
class DaemonClient {
  DaemonClient();

  Process? _process;
  Socket? _socket;
  int _nextId = 1;
  final _pending = <int, Completer<dynamic>>{};
  StreamSubscription<String>? _sub;

  static const Duration connectTimeout = Duration(seconds: 15);

  /// Path del fat JAR: por defecto sibling `daemon/build/libs/bakeneko-daemon.jar`.
  /// Se puede override (tests, distribución empaquetada).
  static String defaultJarPath() {
    // En build empaquetado, el JAR viaja junto al binario en lib/.
    final here = p.dirname(Platform.script.path);
    final candidates = [
      p.join(here, 'bakeneko-daemon.jar'),
      p.join(here, 'lib', 'bakeneko-daemon.jar'),
      p.join(here, '..', 'daemon', 'build', 'libs', 'bakeneko-daemon.jar'),
      // Desarrollo: el binario corre desde app/build/.../bundle; subimos al repo.
      p.join(here, '..', '..', '..', '..', 'daemon', 'build', 'libs', 'bakeneko-daemon.jar'),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return File(c).resolveSymbolicLinksSync();
    }
    return candidates.first;
  }

  /// Arranca el daemon y conecta. Lanza [DaemonException] si no conecta.
  Future<void> start({String? jarPath, String? javaPath}) async {
    final jar = jarPath ?? defaultJarPath();
    if (!File(jar).existsSync()) {
      throw DaemonException('No se encuentra el JAR del daemon: $jar');
    }
    final java = javaPath ?? await _resolveJava();

    final socketPath = Xdg.daemonSocket.path;
    // Borra socket viejo (queda de un crash anterior) para que el daemon
    // pueda hacer bind limpio.
    final sockFile = File(socketPath);
    if (sockFile.existsSync()) {
      try {
        sockFile.deleteSync();
      } catch (_) {}
    }

    final proc = await Process.start(
      java,
      ['-jar', jar],
      workingDirectory: p.dirname(jar),
      mode: ProcessStartMode.normal,
    );
    _process = proc;
    // Redirigimos stderr del daemon para diagnóstico; lo drenamos.
    unawaited(_drain(proc.stderr));

    // Esperar a que el socket aparezca y conecte.
    final deadline = DateTime.now().add(connectTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final s = await _tryConnect(socketPath);
      if (s != null) {
        _socket = s;
        _wire(s);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await stop();
    throw DaemonException('El daemon no abrió el socket tras ${connectTimeout.inSeconds}s');
  }

  Future<Socket?> _tryConnect(String socketPath) async {
    try {
      final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
      return await Socket.connect(addr, 0, timeout: const Duration(seconds: 1));
    } catch (_) {
      return null;
    }
  }

  void _wire(Socket s) {
    // Convertimos el stream de bytes en líneas y despachamos por id.
    final lines = s.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
    _sub = lines.listen(
      (line) {
        if (line.isEmpty) return;
        try {
          final r = RpcResponse.decode(line);
          final c = _pending.remove(r.id);
          if (c == null) return; // respuesta huérfana (no esperada)
          if (r.isOk) {
            c.complete(r.result);
          } else {
            c.completeError(RpcException(r.error!.code, r.error!.message));
          }
        } catch (e) {
          // línea no JSON: la ignoramos silenciosamente (logging verbose off).
        }
      },
      onError: (e) => _failAll('socket error: $e'),
      onDone: () => _failAll('socket cerrado'),
    );
  }

  void _failAll(String reason) {
    for (final id in _pending.keys.toList()) {
      _pending.remove(id)!.completeError(DaemonException(reason));
    }
  }

  Future<dynamic> call(String method, [Map<String, dynamic>? params]) async {
    final s = _socket;
    if (s == null) throw const DaemonException('daemon no iniciado');
    final id = _nextId++;
    final req = RpcRequest(id: id, method: method, params: params);
    final c = Completer<dynamic>();
    _pending[id] = c;
    s
      ..write(req.encode())
      ..write('\n');
    return c.future;
  }

  /// Facade tipado para los 7 métodos. Devuelven Dart Maps/Listas nativas.
  Future<Map<String, dynamic>> ping() async =>
      Map<String, dynamic>.from(await call('ping') as Map);
  Future<List<Map<String, dynamic>>> listSources() async =>
      (await call('sources.list') as List).cast<Map<String, dynamic>>();
  Future<List<Map<String, dynamic>>> catalogList({
    required String source,
    int offset = 0,
    String? query,
  }) async => (await call('catalog.list', {
    if (query != null && query.isNotEmpty) 'query': query,
    'source': source,
    'offset': offset,
  }) as List).cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> mangaDetails(String source, Map<String, dynamic> manga) async =>
      Map<String, dynamic>.from(await call('manga.details', {'source': source, 'manga': manga}));
  Future<List<Map<String, dynamic>>> chapterPages(String source, Map<String, dynamic> chapter) async =>
      (await call('chapter.pages', {'source': source, 'chapter': chapter}) as List)
          .cast<Map<String, dynamic>>();
  Future<String> pageUrl(String source, Map<String, dynamic> page) async =>
      (await call('page.url', {'source': source, 'page': page})).toString();
  Future<Map<String, String>> sourceHeaders(String source) async {
    final raw = await call('source.headers', {'source': source});
    return Map<String, String>.from(raw as Map);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await _socket?.close();
    _socket = null;
    _process?.kill(ProcessSignal.sigterm);
    final proc = _process;
    if (proc != null) {
      await proc.exitCode.timeout(const Duration(seconds: 2), onTimeout: () async {
        proc.kill(ProcessSignal.sigkill);
        return 0;
      });
    }
    _process = null;
  }

  Future<String> _resolveJava() async {
    // JAVA_HOME del entorno, o 'java' en PATH.
    final home = Platform.environment['JAVA_HOME'];
    if (home != null && home.isNotEmpty) {
      final f = File(p.join(home, 'bin', 'java'));
      if (f.existsSync()) return f.path;
    }
    return 'java';
  }

  Future<void> _drain(Stream<List<int>> stream) async {
    await for (final _ in stream) {
      // descartamos silenciosamente; el daemon ya loguea a su stderr.
    }
  }
}

class DaemonException implements Exception {
  const DaemonException(this.message);
  final String message;
  @override
  String toString() => 'DaemonException: $message';
}