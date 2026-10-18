import 'package:flutter/services.dart';

abstract interface class AiCredentialVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Android Keystore AES-GCM; a restored/inaccessible key fails closed and is
/// never silently deleted or replaced while reading a saved session.
final class AndroidAiCredentialVault implements AiCredentialVault {
  const AndroidAiCredentialVault({
    this.namespace = 'session',
    this.channel = const MethodChannel('piko/ai_access_vault'),
  });
  final String namespace;
  final MethodChannel channel;
  @override
  Future<String?> read() =>
      channel.invokeMethod<String>('read', {'namespace': namespace});
  @override
  Future<void> write(String value) => channel.invokeMethod<void>('write', {
    'namespace': namespace,
    'value': value,
  });
  @override
  Future<void> delete() =>
      channel.invokeMethod<void>('delete', {'namespace': namespace});
}
