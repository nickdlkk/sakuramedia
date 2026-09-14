import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_provider.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
  });

  test('refresh updates actor detail after initial load', () async {
    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorJson('Old actor'),
      )
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorJson('New actor'),
      );
    final subscription = container.listen(
      actorDetailProvider(1),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      (await container.read(actorDetailProvider(1).future)).actor?.summary.name,
      'Old actor',
    );
    await container.read(actorDetailProvider(1).notifier).refresh();

    expect(
      container.read(actorDetailProvider(1)).requireValue.actor?.summary.name,
      'New actor',
    );
  });

  test('refresh rethrows and keeps existing actor on failure', () async {
    bundle.adapter
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        body: _actorJson('Old actor'),
      )
      ..enqueueJson(
        method: 'GET',
        path: '/actors/1',
        statusCode: 500,
        body: <String, dynamic>{'error': 'server_error'},
      );
    final subscription = container.listen(
      actorDetailProvider(1),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(actorDetailProvider(1).future);

    await expectLater(
      container.read(actorDetailProvider(1).notifier).refresh(),
      throwsA(isA<Object>()),
    );

    expect(
      container.read(actorDetailProvider(1)).requireValue.actor?.summary.name,
      'Old actor',
    );
  });
}

Map<String, dynamic> _actorJson(String name) => <String, dynamic>{
  'id': 1,
  'javdb_id': 'actor-1',
  'name': name,
  'alias_name': '',
  'profile_image': null,
  'is_subscribed': false,
};
