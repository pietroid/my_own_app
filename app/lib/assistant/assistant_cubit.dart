import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_own_app/assistant/assistant_repository.dart';

/// {@template assistant_state}
/// The conversation on screen, and whether an answer is on its way.
/// {@endtemplate}
class AssistantState extends Equatable {
  /// {@macro assistant_state}
  const AssistantState({
    this.messages = const [],
    this.waiting = false,
    this.failed = false,
    this.error,
  });

  /// Everything said so far, oldest first.
  final List<AssistantMessage> messages;

  /// Whether the assistant is answering.
  final bool waiting;

  /// Whether the last turn went unanswered.
  final bool failed;

  /// The server's own words for it, when it gave any.
  final String? error;

  @override
  List<Object?> get props => [messages, waiting, failed, error];
}

/// {@template assistant_cubit}
/// One conversation with the assistant, kept in memory for as long as its
/// page is open.
/// {@endtemplate}
class AssistantCubit extends Cubit<AssistantState> {
  /// {@macro assistant_cubit}
  AssistantCubit({required this._repository})
    : super(const AssistantState());

  final AssistantRepository _repository;

  /// Says [text] and waits for the answer. Nothing while one is on its way.
  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.waiting) return;

    final messages = [
      ...state.messages,
      AssistantMessage(role: AssistantRole.user, content: content),
    ];
    emit(AssistantState(messages: messages, waiting: true));

    try {
      final reply = await _repository.reply(messages);
      emit(
        AssistantState(
          messages: [
            ...messages,
            AssistantMessage(role: AssistantRole.assistant, content: reply),
          ],
        ),
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map<String, dynamic> ? data['message'] : null;
      emit(
        AssistantState(
          messages: messages,
          failed: true,
          error: message is String ? message : null,
        ),
      );
    }
  }
}
