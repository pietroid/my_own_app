import 'package:api_client/api_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/assistant/assistant.dart';

class _MockRepository extends Mock implements AssistantRepository {}

const _hi = AssistantMessage(role: AssistantRole.user, content: 'Oi');
const _hello = AssistantMessage(role: AssistantRole.assistant, content: 'Olá!');

void main() {
  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  blocTest<AssistantCubit, AssistantState>(
    'adds the answer after the question',
    setUp: () => when(
      () => repository.reply(any()),
    ).thenAnswer((_) async => 'Olá!'),
    build: () => AssistantCubit(repository: repository),
    act: (cubit) => cubit.send('  Oi '),
    expect: () => const [
      AssistantState(messages: [_hi], waiting: true),
      AssistantState(messages: [_hi, _hello]),
    ],
  );

  blocTest<AssistantCubit, AssistantState>(
    'sends nothing blank',
    build: () => AssistantCubit(repository: repository),
    act: (cubit) => cubit.send('   '),
    expect: () => const <AssistantState>[],
  );

  blocTest<AssistantCubit, AssistantState>(
    "keeps the question and the server's words when it fails",
    setUp: () => when(() => repository.reply(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/assistant/chat'),
        response: Response(
          requestOptions: RequestOptions(path: '/assistant/chat'),
          statusCode: 503,
          data: {'message': 'Sem modelo.'},
        ),
      ),
    ),
    build: () => AssistantCubit(repository: repository),
    act: (cubit) => cubit.send('Oi'),
    expect: () => const [
      AssistantState(messages: [_hi], waiting: true),
      AssistantState(messages: [_hi], failed: true, error: 'Sem modelo.'),
    ],
  );
}
