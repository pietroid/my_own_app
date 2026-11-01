import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';

/// Hands the API client the session token the phone keeps.
///
/// On the web there is no token: the session rides in a cookie the browser
/// sends by itself.
class AuthTokenProvider implements TokenProvider {
  /// Reads tokens off the given auth repository.
  AuthTokenProvider(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<String?> getToken() => _authRepository.token();

  /// Sessions are long-lived and not refreshed from here: a 401 means the
  /// session is over, and the next launch lands on the sign-in screen.
  @override
  Future<String?> refreshToken() async => null;
}
