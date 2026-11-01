import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// Who said a message.
enum AssistantRole {
  /// The person.
  user,

  /// The assistant.
  assistant,
}

/// {@template assistant_message}
/// One message of a conversation with the assistant.
/// {@endtemplate}
class AssistantMessage extends Equatable {
  /// {@macro assistant_message}
  const AssistantMessage({required this.role, required this.content});

  /// Who said it.
  final AssistantRole role;

  /// What was said.
  final String content;

  /// As `POST /assistant/chat` takes it.
  Map<String, String> toJson() => {'role': role.name, 'content': content};

  @override
  List<Object?> get props => [role, content];
}

/// {@template assistant_repository}
/// Talks to the server's assistant (`/api/assistant`).
///
/// The server keeps nothing: every turn sends the whole conversation.
/// {@endtemplate}
class AssistantRepository {
  /// {@macro assistant_repository}
  const AssistantRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// The assistant's answer to [messages], the last one the person's.
  ///
  /// Throws the server's refusal as a [DioException]; its `message` is
  /// already in the person's language.
  Future<String> reply(List<AssistantMessage> messages) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/assistant/chat',
      data: {
        'messages': [for (final message in messages) message.toJson()],
      },
    );

    return response.data?['reply'] as String? ?? '';
  }
}
