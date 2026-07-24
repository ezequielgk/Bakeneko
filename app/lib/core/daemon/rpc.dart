import 'dart:convert';

/// Codificación/decodificación de frames JSON-RPC delimitados por líneas.
/// Stateless y testeable sin red.
class RpcRequest {
  RpcRequest({required this.id, required this.method, this.params});
  final int id;
  final String method;
  final Map<String, dynamic>? params;

  String encode() => jsonEncode({
    if (params != null) 'params': params,
    'method': method,
    'id': id,
    'jsonrpc': '2.0',
  });
}

/// Resultado decodificado de una línea de respuesta.
class RpcResponse {
  RpcResponse({this.id, this.result, this.error});
  final int? id;
  final dynamic result;
  final RpcError? error;

  bool get isOk => error == null;

  /// Lanza [RpcException] si la respuesta es de error.
  dynamic unwrap() {
    if (error != null) throw RpcException(error!.code, error!.message);
    return result;
  }

  static RpcResponse decode(String line) {
    final m = jsonDecode(line) as Map<String, dynamic>;
    final id = m['id'] is int ? m['id'] as int : (m['id'] as num?)?.toInt();
    final errRaw = m['error'];
    return RpcResponse(
      id: id,
      result: m['result'],
      error: errRaw is Map<String, dynamic> ? RpcError.fromJson(errRaw) : null,
    );
  }
}

class RpcError {
  const RpcError({required this.code, required this.message});
  final int code;
  final String message;
  factory RpcError.fromJson(Map<String, dynamic> json) =>
      RpcError(code: json['code'] as int, message: json['message'] as String);
}

class RpcException implements Exception {
  const RpcException(this.code, this.message);
  final int code;
  final String message;
  @override
  String toString() => 'RpcException($code): $message';
}