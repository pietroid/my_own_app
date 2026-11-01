// dart format off
// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'My Own App';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authSignInWithGoogle => 'Entrar com Google';

  @override
  String get authSignInFailed => 'Não foi possível entrar';

  @override
  String homeGreeting(String name) {
    return 'Olá, $name';
  }

  @override
  String get homeGreetingAnonymous => 'Olá';

  @override
  String get homeEmptyTitle => 'Tudo pronto';

  @override
  String get homeEmptyBody => 'Esta tela está em branco. É aqui que o app começa.';

  @override
  String get homeSignOut => 'Sair';

  @override
  String get assistantOpen => 'Falar com o assistente';

  @override
  String get assistantTitle => 'Assistente';

  @override
  String get assistantHint => 'Pergunte qualquer coisa';

  @override
  String get assistantSend => 'Enviar';

  @override
  String get assistantEmpty => 'Como posso ajudar?';

  @override
  String get assistantFailed => 'O assistente não respondeu. Tente de novo.';
}
