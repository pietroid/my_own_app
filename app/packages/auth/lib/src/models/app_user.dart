import 'package:equatable/equatable.dart';

/// {@template app_user}
/// Information about an authenticated user.
/// {@endtemplate}
class AppUser extends Equatable {
  /// {@macro app_user}
  const AppUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
  });

  /// Creates an [AppUser] from Better Auth's user object.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      photoUrl: json['image'] as String?,
    );
  }

  /// Unique identifier of the user.
  final String id;

  /// Display name of the user, if available.
  final String? name;

  /// Email address of the user, if available.
  final String? email;

  /// Profile photo URL of the user, if available.
  final String? photoUrl;

  @override
  List<Object?> get props => [id, name, email, photoUrl];
}
