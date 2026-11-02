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
  String get studioChatTitle => 'Conversa';

  @override
  String get studioChatHint => 'Peça uma mudança no app';

  @override
  String get studioChatHintFocused => 'O que mudar neste componente?';

  @override
  String get studioSend => 'Enviar';

  @override
  String get studioSending => 'Mudando o app…';

  @override
  String get studioSendFailed => 'Não foi possível mudar o app. Tente de novo.';

  @override
  String get studioHistoryFailed => 'Não foi possível carregar a conversa.';

  @override
  String get studioOpenChat => 'Conversa';

  @override
  String get studioFirstReply => 'Pronto: o app está montado.';

  @override
  String get studioNoChanges => 'Sem mudanças no app';

  @override
  String studioVersion(int n) {
    return 'Versão $n';
  }

  @override
  String get studioCurrent => 'atual';

  @override
  String studioRestored(int n) {
    return 'Voltou à versão $n';
  }

  @override
  String studioComponents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count componentes',
      one: '1 componente',
    );
    return '$_temp0';
  }

  @override
  String studioActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ações',
      one: '1 ação',
    );
    return '$_temp0';
  }

  @override
  String studioViewing(int n) {
    return 'Vendo a versão $n';
  }

  @override
  String get studioViewingBody => 'Só para ver: os toques não fazem nada.';

  @override
  String get studioBackToCurrent => 'Voltar à atual';

  @override
  String get studioRestore => 'Restaurar esta';

  @override
  String get studioViewFailed => 'Não foi possível abrir essa versão.';

  @override
  String get studioSelect => 'Selecionar componente';

  @override
  String get studioSelectDone => 'Usar o app';

  @override
  String get studioTreeTitle => 'Componentes';

  @override
  String get studioNothingSelected => 'Selecione um componente no app ou na árvore.';

  @override
  String get studioPerItem => 'por item';

  @override
  String get studioId => 'Id';

  @override
  String get studioText => 'Texto';

  @override
  String get studioLabel => 'Rótulo';

  @override
  String get studioValue => 'Valor';

  @override
  String get studioItems => 'Itens';

  @override
  String get studioChildren => 'Filhos';

  @override
  String get studioAction => 'Ação';

  @override
  String get studioSaved => 'salva no servidor';

  @override
  String get studioScreenOnly => 'só na tela';

  @override
  String get studioReads => 'Lê';

  @override
  String get studioAskChange => 'Pedir mudança';

  @override
  String studioFocus(String component) {
    return 'Sobre: $component';
  }

  @override
  String get studioClearFocus => 'Tirar o foco';

  @override
  String get componentColumn => 'Coluna';

  @override
  String get componentRow => 'Linha';

  @override
  String get componentList => 'Lista';

  @override
  String get componentText => 'Texto';

  @override
  String get componentTextField => 'Campo';

  @override
  String get componentCheckBox => 'Caixa de seleção';

  @override
  String get componentButton => 'Botão';

  @override
  String get componentUnknown => 'Componente';
}
