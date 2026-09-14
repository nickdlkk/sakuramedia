// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_center_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ActivityCenter)
final activityCenterProvider = ActivityCenterProvider._();

final class ActivityCenterProvider
    extends $AsyncNotifierProvider<ActivityCenter, ActivityCenterState> {
  ActivityCenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'activityCenterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activityCenterHash();

  @$internal
  @override
  ActivityCenter create() => ActivityCenter();
}

String _$activityCenterHash() => r'e05f24e031a1310d338b9ff54c1c5abe1efe6d4c';

abstract class _$ActivityCenter extends $AsyncNotifier<ActivityCenterState> {
  FutureOr<ActivityCenterState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ActivityCenterState>, ActivityCenterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActivityCenterState>, ActivityCenterState>,
              AsyncValue<ActivityCenterState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
