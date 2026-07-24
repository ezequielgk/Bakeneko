import 'dart:convert';

import 'package:bakeneko/core/daemon/rpc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RpcRequest codifica method, params e id', () {
    final req = RpcRequest(id: 7, method: 'catalog.list', params: {'source': 'MANGADEX', 'offset': 10});
    final m = jsonDecode(req.encode()) as Map<String, dynamic>;
    expect(m['method'], 'catalog.list');
    expect(m['id'], 7);
    expect(m['params'], {'source': 'MANGADEX', 'offset': 10});
    expect(m['jsonrpc'], '2.0');
  });

  test('RpcRequest sin params no incluye el campo', () {
    final m = jsonDecode(RpcRequest(id: 1, method: 'ping').encode()) as Map<String, dynamic>;
    expect(m.containsKey('params'), isFalse);
  });

  test('RpcResponse.decode de respuesta OK devuelve result', () {
    final r = RpcResponse.decode('{"id":1,"result":{"version":"1.0.0"},"jsonrpc":"2.0"}');
    expect(r.isOk, isTrue);
    expect(r.id, 1);
    expect((r.result as Map)['version'], '1.0.0');
    expect(r.unwrap()['version'], '1.0.0');
  });

  test('RpcResponse.decode de error lanza RpcException en unwrap', () {
    final r = RpcResponse.decode('{"id":2,"error":{"code":-32602,"message":"fuente no soportada"},"jsonrpc":"2.0"}');
    expect(r.isOk, isFalse);
    expect(r.error!.code, -32602);
    expect(() => r.unwrap(), throwsA(isA<RpcException>()));
  });

  test('RpcResponse.decode tolera id ausente', () {
    final r = RpcResponse.decode('{"result":[]}');
    expect(r.id, isNull);
    expect(r.result, []);
  });
}