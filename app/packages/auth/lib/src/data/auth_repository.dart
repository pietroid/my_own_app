import 'dart:async';

import 'package:auth/src/data/token_store.dart';
import 'package:auth/src/models/app_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

/// {@template auth_repository}
/// Repository that abstracts authentication operations.
/// {@endtemplate}
abstract class AuthRepository {
  /// {@macro auth_repository}
  const AuthRepository();

  /// Stream of the currently signed-in [AppUser].
  ///
  /// Emits `null` when no user is signed in.
  Stream<AppUser?> get user;

  /// The signed-in user, as last known.
  AppUser? get currentUser;

  /// The session token to send as a bearer, when this platform keeps one.
  ///
  /// Null on the web, where the session rides in a cookie instead.
  Future<String?> token();

  /// Reads back the session this device already has, if it still holds.
  Future<AppUser?> restore();

  /// Signs in with Google.
  Future<void> signInWithGoogle();

  /// Signs the current user out.
  Future<void> signOut();
}

/// {@template auth_failure}
/// A sign-in that did not go through, with the server's reason when it gave
/// one.
/// {@endtemplate}
class AuthFailure implements Exception {
  /// {@macro auth_failure}
  const AuthFailure([this.message]);

  /// What the server said, already in the user's language, if anything.
  final String? message;

  @override
  String toString() => message ?? 'AuthFailure';
}

/// {@template better_auth_repository}
/// [AuthRepository] backed by the server's Better Auth routes.
///
/// Google is the only way in, by two roads:
///
/// - **Web** goes through the OAuth redirect. The browser leaves for Google,
///   comes back to the app, and from then on carries the session cookie,
///   which the API shares an origin with.
/// - **iOS and Android** sign in with the native Google SDK and hand its ID
///   token to the server, which checks it with Google and answers with a
///   session token. That token is kept in [TokenStore] and sent as a bearer.
/// {@endtemplate}
class BetterAuthRepository implements AuthRepository {
  /// {@macro better_auth_repository}
  BetterAuthRepository({
    required String apiBaseUrl,
    TokenStore? tokenStore,
    GoogleSignIn? googleSignIn,
    String? googleClientId,
    String? googleServerClientId,
    String googleWebProvider = 'google',
    Dio? dio,
  }) : _webProvider = googleWebProvider,
       _tokens = tokenStore ?? TokenStore(),
       _google =
           googleSignIn ??
           GoogleSignIn(
             clientId: googleClientId,
             serverClientId: googleServerClientId,
             scopes: const ['email', 'profile'],
           ),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: apiBaseUrl,
               contentType: Headers.jsonContentType,
               // The web adapter reads this to send the session cookie.
               extra: const {'withCredentials': true},
             ),
           );

  /// The provider the web redirect goes through. The phones always post
  /// their ID tokens to `google`, which accepts every client the server
  /// lists.
  final String _webProvider;
  final TokenStore _tokens;
  final GoogleSignIn _google;
  final Dio _dio;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> get user => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<String?> token() => kIsWeb ? Future.value() : _tokens.read();

  @override
  Future<AppUser?> restore() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/get-session',
        options: await _authorized(),
      );
      final raw = response.data?['user'];
      _emit(raw is Map<String, dynamic> ? AppUser.fromJson(raw) : null);
    } on DioException catch (error) {
      // No network is not the same as signed out: keep the token for the
      // next launch, and let the app open on the sign-in screen meanwhile.
      if (error.response?.statusCode == 401) await _tokens.clear();
      _emit(null);
    }

    return _current;
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) return _redirectToGoogle();

    final account = await _google.signIn();
    if (account == null) return; // The user closed the picker.

    final idToken = (await account.authentication).idToken;
    if (idToken == null) throw const AuthFailure();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/sign-in/social',
        data: {
          'provider': 'google',
          'idToken': {'token': idToken},
        },
      );

      final token = response.data?['token'];
      final raw = response.data?['user'];
      if (token is! String || raw is! Map<String, dynamic>) {
        throw const AuthFailure();
      }

      await _tokens.write(token);
      _emit(AppUser.fromJson(raw));
    } on DioException catch (error) {
      await _google.signOut();
      throw AuthFailure(_messageOf(error));
    }
  }

  /// Leaves for Google. The app is loaded again when the browser comes back,
  /// and [restore] finds the session cookie the server set on the way.
  Future<void> _redirectToGoogle() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/sign-in/social',
        data: {
          'provider': _webProvider,
          'callbackURL': Uri.base.origin,
        },
      );

      final url = response.data?['url'];
      if (url is! String) throw const AuthFailure();

      await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    } on DioException catch (error) {
      throw AuthFailure(_messageOf(error));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _dio.post<void>(
        '/auth/sign-out',
        data: const <String, dynamic>{},
        options: await _authorized(),
      );
    } on DioException {
      // Signed out here whatever the server says: the token is forgotten
      // either way, and an orphaned session expires on its own.
    }

    await _tokens.clear();
    if (!kIsWeb) await _google.signOut();
    _emit(null);
  }

  Future<Options> _authorized() async {
    final token = await this.token();

    return Options(
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
  }

  void _emit(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  static String? _messageOf(DioException error) {
    final data = error.response?.data;
    final message = data is Map<String, dynamic> ? data['message'] : null;

    return message is String && message.isNotEmpty ? message : null;
  }
}
