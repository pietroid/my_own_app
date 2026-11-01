/// {@template token_provider}
/// Provides access tokens for authenticated requests and can refresh them.
/// {@endtemplate}
abstract class TokenProvider {
  /// {@macro token_provider}
  const TokenProvider();

  /// Returns the current access token, or `null` if the user is not
  /// authenticated.
  Future<String?> getToken();

  /// Refreshes the current access token and returns the new value, or `null`
  /// if the user can no longer be authenticated.
  Future<String?> refreshToken();
}
