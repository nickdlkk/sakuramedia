// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugins_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 已安装插件列表与安装 / 启停 / 删除操作的会话级共享状态。

@ProviderFor(Plugins)
final pluginsProvider = PluginsProvider._();

/// 已安装插件列表与安装 / 启停 / 删除操作的会话级共享状态。
final class PluginsProvider
    extends $AsyncNotifierProvider<Plugins, PluginsState> {
  /// 已安装插件列表与安装 / 启停 / 删除操作的会话级共享状态。
  PluginsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'pluginsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pluginsHash();

  @$internal
  @override
  Plugins create() => Plugins();
}

String _$pluginsHash() => r'aa462d9e60660123f5c0cf680de2053a7de62151';

/// 已安装插件列表与安装 / 启停 / 删除操作的会话级共享状态。

abstract class _$Plugins extends $AsyncNotifier<PluginsState> {
  FutureOr<PluginsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PluginsState>, PluginsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PluginsState>, PluginsState>,
              AsyncValue<PluginsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
