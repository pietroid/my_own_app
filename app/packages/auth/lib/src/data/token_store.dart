import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// {@template token_store}
/// Where the phone keeps its session token between launches.
///
/// The Keychain on iOS and the Keystore-backed storage on Android. The
/// background refresh reads it too, from an isolate of its own, which is why
/// it is a store on disk and not a field in memory.
/// {@endtemplate}
class TokenStore {
  /// {@macro token_store}
  TokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Readable by the background refresh while the phone is locked.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _key = 'session_token';

  final FlutterSecureStorage _storage;

  /// The token, or null when signed out.
  Future<String?> read() => _storage.read(key: _key);

  /// Keeps [token] for the next launch.
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  /// Forgets the token.
  Future<void> clear() => _storage.delete(key: _key);
}
