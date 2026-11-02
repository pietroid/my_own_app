// dart format off
// coverage:ignore-file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt')
  ];

  /// The app's name, as it is written everywhere.
  ///
  /// In pt, this message translates to:
  /// **'My Own App'**
  String get appName;

  /// No description provided for @authSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignIn;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authSignInFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível entrar'**
  String get authSignInFailed;

  /// The greeting at the top of the home screen.
  ///
  /// In pt, this message translates to:
  /// **'Olá, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeGreetingAnonymous.
  ///
  /// In pt, this message translates to:
  /// **'Olá'**
  String get homeGreetingAnonymous;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum app ainda'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Descreva o app que você quer, e o assistente monta para você.'**
  String get homeEmptyBody;

  /// No description provided for @homeSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get homeSignOut;

  /// No description provided for @assistantTitle.
  ///
  /// In pt, this message translates to:
  /// **'Assistente'**
  String get assistantTitle;

  /// No description provided for @assistantHint.
  ///
  /// In pt, this message translates to:
  /// **'Pergunte qualquer coisa'**
  String get assistantHint;

  /// No description provided for @assistantSend.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get assistantSend;

  /// No description provided for @assistantEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Como posso ajudar?'**
  String get assistantEmpty;

  /// No description provided for @assistantFailed.
  ///
  /// In pt, this message translates to:
  /// **'O assistente não respondeu. Tente de novo.'**
  String get assistantFailed;

  /// No description provided for @homeAssistant.
  ///
  /// In pt, this message translates to:
  /// **'Assistente'**
  String get homeAssistant;

  /// No description provided for @appsCreateHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: uma lista de tarefas'**
  String get appsCreateHint;

  /// No description provided for @appsCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar app'**
  String get appsCreate;

  /// No description provided for @appsCreating.
  ///
  /// In pt, this message translates to:
  /// **'Montando o seu app…'**
  String get appsCreating;

  /// No description provided for @appsCreateFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível criar o app. Tente de novo.'**
  String get appsCreateFailed;

  /// No description provided for @appsLoadFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir o app.'**
  String get appsLoadFailed;

  /// No description provided for @appsActionFailed.
  ///
  /// In pt, this message translates to:
  /// **'Essa ação falhou.'**
  String get appsActionFailed;

  /// No description provided for @appsRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get appsRetry;

  /// No description provided for @studioChatTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conversa'**
  String get studioChatTitle;

  /// No description provided for @studioChatHint.
  ///
  /// In pt, this message translates to:
  /// **'Peça uma mudança no app'**
  String get studioChatHint;

  /// No description provided for @studioChatHintFocused.
  ///
  /// In pt, this message translates to:
  /// **'O que mudar neste componente?'**
  String get studioChatHintFocused;

  /// No description provided for @studioSend.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get studioSend;

  /// No description provided for @studioSending.
  ///
  /// In pt, this message translates to:
  /// **'Mudando o app…'**
  String get studioSending;

  /// No description provided for @studioSendFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível mudar o app. Tente de novo.'**
  String get studioSendFailed;

  /// No description provided for @studioHistoryFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar a conversa.'**
  String get studioHistoryFailed;

  /// No description provided for @studioOpenChat.
  ///
  /// In pt, this message translates to:
  /// **'Conversa'**
  String get studioOpenChat;

  /// No description provided for @studioFirstReply.
  ///
  /// In pt, this message translates to:
  /// **'Pronto: o app está montado.'**
  String get studioFirstReply;

  /// No description provided for @studioNoChanges.
  ///
  /// In pt, this message translates to:
  /// **'Sem mudanças no app'**
  String get studioNoChanges;

  /// A version of the app in its history.
  ///
  /// In pt, this message translates to:
  /// **'Versão {n}'**
  String studioVersion(int n);

  /// No description provided for @studioCurrent.
  ///
  /// In pt, this message translates to:
  /// **'atual'**
  String get studioCurrent;

  /// A version that brought an earlier one back.
  ///
  /// In pt, this message translates to:
  /// **'Voltou à versão {n}'**
  String studioRestored(int n);

  /// How many components a version changed.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 componente} other{{count} componentes}}'**
  String studioComponents(int count);

  /// How many actions a version changed.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 ação} other{{count} ações}}'**
  String studioActions(int count);

  /// Above the phone, when an earlier version is shown.
  ///
  /// In pt, this message translates to:
  /// **'Vendo a versão {n}'**
  String studioViewing(int n);

  /// No description provided for @studioViewingBody.
  ///
  /// In pt, this message translates to:
  /// **'Só para ver: os toques não fazem nada.'**
  String get studioViewingBody;

  /// No description provided for @studioBackToCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Voltar à atual'**
  String get studioBackToCurrent;

  /// No description provided for @studioRestore.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar esta'**
  String get studioRestore;

  /// No description provided for @studioViewFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir essa versão.'**
  String get studioViewFailed;

  /// No description provided for @studioSelect.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar componente'**
  String get studioSelect;

  /// No description provided for @studioSelectDone.
  ///
  /// In pt, this message translates to:
  /// **'Usar o app'**
  String get studioSelectDone;

  /// No description provided for @studioTreeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Componentes'**
  String get studioTreeTitle;

  /// No description provided for @studioNothingSelected.
  ///
  /// In pt, this message translates to:
  /// **'Selecione um componente no app ou na árvore.'**
  String get studioNothingSelected;

  /// No description provided for @studioPerItem.
  ///
  /// In pt, this message translates to:
  /// **'por item'**
  String get studioPerItem;

  /// No description provided for @studioId.
  ///
  /// In pt, this message translates to:
  /// **'Id'**
  String get studioId;

  /// No description provided for @studioText.
  ///
  /// In pt, this message translates to:
  /// **'Texto'**
  String get studioText;

  /// No description provided for @studioLabel.
  ///
  /// In pt, this message translates to:
  /// **'Rótulo'**
  String get studioLabel;

  /// No description provided for @studioValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get studioValue;

  /// No description provided for @studioItems.
  ///
  /// In pt, this message translates to:
  /// **'Itens'**
  String get studioItems;

  /// No description provided for @studioChildren.
  ///
  /// In pt, this message translates to:
  /// **'Filhos'**
  String get studioChildren;

  /// No description provided for @studioAction.
  ///
  /// In pt, this message translates to:
  /// **'Ação'**
  String get studioAction;

  /// No description provided for @studioSaved.
  ///
  /// In pt, this message translates to:
  /// **'salva no servidor'**
  String get studioSaved;

  /// No description provided for @studioScreenOnly.
  ///
  /// In pt, this message translates to:
  /// **'só na tela'**
  String get studioScreenOnly;

  /// No description provided for @studioReads.
  ///
  /// In pt, this message translates to:
  /// **'Lê'**
  String get studioReads;

  /// No description provided for @studioAskChange.
  ///
  /// In pt, this message translates to:
  /// **'Pedir mudança'**
  String get studioAskChange;

  /// The chip over the composer naming the selected component.
  ///
  /// In pt, this message translates to:
  /// **'Sobre: {component}'**
  String studioFocus(String component);

  /// No description provided for @studioClearFocus.
  ///
  /// In pt, this message translates to:
  /// **'Tirar o foco'**
  String get studioClearFocus;

  /// No description provided for @componentColumn.
  ///
  /// In pt, this message translates to:
  /// **'Coluna'**
  String get componentColumn;

  /// No description provided for @componentRow.
  ///
  /// In pt, this message translates to:
  /// **'Linha'**
  String get componentRow;

  /// No description provided for @componentList.
  ///
  /// In pt, this message translates to:
  /// **'Lista'**
  String get componentList;

  /// No description provided for @componentText.
  ///
  /// In pt, this message translates to:
  /// **'Texto'**
  String get componentText;

  /// No description provided for @componentTextField.
  ///
  /// In pt, this message translates to:
  /// **'Campo'**
  String get componentTextField;

  /// No description provided for @componentCheckBox.
  ///
  /// In pt, this message translates to:
  /// **'Caixa de seleção'**
  String get componentCheckBox;

  /// No description provided for @componentButton.
  ///
  /// In pt, this message translates to:
  /// **'Botão'**
  String get componentButton;

  /// No description provided for @componentUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Componente'**
  String get componentUnknown;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
