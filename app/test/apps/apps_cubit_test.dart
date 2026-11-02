import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_own_app/apps/apps_cubit.dart';
import 'package:my_own_app/apps/apps_repository.dart';

class _MockRepository extends Mock implements AppsRepository {}

void main() {
  test('a build that fails in any way stops loading', () async {
    final repository = _MockRepository();
    // Not a DioException: an answer the app could not read.
    when(
      () => repository.create('Tarefas'),
    ).thenThrow(TypeError());
    final cubit = AppsCubit(repository: repository);

    expect(await cubit.create('Tarefas'), isNull);

    expect(cubit.state.creating, isFalse);
    expect(cubit.state.failed, isTrue);
  });
}
