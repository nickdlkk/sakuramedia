// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(llmSettingsApi)
final llmSettingsApiProvider = LlmSettingsApiProvider._();

final class LlmSettingsApiProvider
    extends
        $FunctionalProvider<
          MovieDescTranslationSettingsApi,
          MovieDescTranslationSettingsApi,
          MovieDescTranslationSettingsApi
        >
    with $Provider<MovieDescTranslationSettingsApi> {
  LlmSettingsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'llmSettingsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmSettingsApiHash();

  @$internal
  @override
  $ProviderElement<MovieDescTranslationSettingsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MovieDescTranslationSettingsApi create(Ref ref) {
    return llmSettingsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieDescTranslationSettingsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieDescTranslationSettingsApi>(
        value,
      ),
    );
  }
}

String _$llmSettingsApiHash() => r'5f94e355793ef5eb2da4dd0b9a26cd5a9ddb033e';

@ProviderFor(LlmSettings)
final llmSettingsProvider = LlmSettingsProvider._();

final class LlmSettingsProvider
    extends $AsyncNotifierProvider<LlmSettings, LlmSettingsState> {
  LlmSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'llmSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$llmSettingsHash();

  @$internal
  @override
  LlmSettings create() => LlmSettings();
}

String _$llmSettingsHash() => r'c623109344d4f89c0d64a59ebe76b513455b8191';

abstract class _$LlmSettings extends $AsyncNotifier<LlmSettingsState> {
  FutureOr<LlmSettingsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<LlmSettingsState>, LlmSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LlmSettingsState>, LlmSettingsState>,
              AsyncValue<LlmSettingsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
