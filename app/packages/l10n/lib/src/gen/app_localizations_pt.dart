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
  String get homeEmptyTitle => 'Nenhum app ainda';

  @override
  String get homeEmptyBody => 'Descreva o app que você quer, e o assistente monta para você.';

  @override
  String get homeSignOut => 'Sair';

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

  @override
  String get homeAssistant => 'Assistente';

  @override
  String get appsCreateHint => 'Ex.: uma lista de tarefas';

  @override
  String get appsCreate => 'Criar app';

  @override
  String get appsCreating => 'Montando o seu app…';

  @override
  String get appsCreateFailed => 'Não foi possível criar o app. Tente de novo.';

  @override
  String get appsLoadFailed => 'Não foi possível abrir o app.';

  @override
  String get appsActionFailed => 'Essa ação falhou.';

  @override
  String get appsRetry => 'Tentar de novo';

  @override
  String get appsEditorFailed => 'O editor não abriu. O app está aberto sozinho.';

  @override
  String get appsEditorReset => 'Restaurar editor';

  @override
  String get appsEditorCaption => 'O editor dos seus apps';

  @override
  String get appsFormMobile => 'Celular';

  @override
  String get appsFormWeb => 'Web';
}
