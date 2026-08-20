// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlists_overview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
/// 创建 / 编辑 / 删除的就地补丁。
///
/// autoDispose family([PlaylistsOverviewScope])：4 个消费入口（桌面/移动
/// playlists 独立页、configuration 管理 section、overview 移动骨架）按 scope
/// 定位实例，orderScopeKey=null 表不持久化顺序（configuration / mobile 独立页）。
///
/// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
/// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
/// provider），scope 只留 orderScopeKey + includeSystem 两个业务参数。
///
/// **reorder 保持 fire-and-forget 语义**（原 controller
/// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
/// 等待窗口。

@ProviderFor(PlaylistsOverview)
final playlistsOverviewProvider = PlaylistsOverviewFamily._();

/// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
/// 创建 / 编辑 / 删除的就地补丁。
///
/// autoDispose family([PlaylistsOverviewScope])：4 个消费入口（桌面/移动
/// playlists 独立页、configuration 管理 section、overview 移动骨架）按 scope
/// 定位实例，orderScopeKey=null 表不持久化顺序（configuration / mobile 独立页）。
///
/// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
/// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
/// provider），scope 只留 orderScopeKey + includeSystem 两个业务参数。
///
/// **reorder 保持 fire-and-forget 语义**（原 controller
/// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
/// 等待窗口。
final class PlaylistsOverviewProvider
    extends $AsyncNotifierProvider<PlaylistsOverview, PlaylistsOverviewState> {
  /// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
  /// 创建 / 编辑 / 删除的就地补丁。
  ///
  /// autoDispose family([PlaylistsOverviewScope])：4 个消费入口（桌面/移动
  /// playlists 独立页、configuration 管理 section、overview 移动骨架）按 scope
  /// 定位实例，orderScopeKey=null 表不持久化顺序（configuration / mobile 独立页）。
  ///
  /// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
  /// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
  /// provider），scope 只留 orderScopeKey + includeSystem 两个业务参数。
  ///
  /// **reorder 保持 fire-and-forget 语义**（原 controller
  /// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
  /// 等待窗口。
  PlaylistsOverviewProvider._({
    required PlaylistsOverviewFamily super.from,
    required PlaylistsOverviewScope super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'playlistsOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$playlistsOverviewHash();

  @override
  String toString() {
    return r'playlistsOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PlaylistsOverview create() => PlaylistsOverview();

  @override
  bool operator ==(Object other) {
    return other is PlaylistsOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$playlistsOverviewHash() => r'fdaf52dc346e656947546bf8434da2307ff929a8';

/// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
/// 创建 / 编辑 / 删除的就地补丁。
///
/// autoDispose family([PlaylistsOverviewScope])：4 个消费入口（桌面/移动
/// playlists 独立页、configuration 管理 section、overview 移动骨架）按 scope
/// 定位实例，orderScopeKey=null 表不持久化顺序（configuration / mobile 独立页）。
///
/// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
/// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
/// provider），scope 只留 orderScopeKey + includeSystem 两个业务参数。
///
/// **reorder 保持 fire-and-forget 语义**（原 controller
/// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
/// 等待窗口。

final class PlaylistsOverviewFamily extends $Family
    with
        $ClassFamilyOverride<
          PlaylistsOverview,
          AsyncValue<PlaylistsOverviewState>,
          PlaylistsOverviewState,
          FutureOr<PlaylistsOverviewState>,
          PlaylistsOverviewScope
        > {
  PlaylistsOverviewFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'playlistsOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
  /// 创建 / 编辑 / 删除的就地补丁。
  ///
  /// autoDispose family([PlaylistsOverviewScope])：4 个消费入口（桌面/移动
  /// playlists 独立页、configuration 管理 section、overview 移动骨架）按 scope
  /// 定位实例，orderScopeKey=null 表不持久化顺序（configuration / mobile 独立页）。
  ///
  /// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
  /// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
  /// provider），scope 只留 orderScopeKey + includeSystem 两个业务参数。
  ///
  /// **reorder 保持 fire-and-forget 语义**（原 controller
  /// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
  /// 等待窗口。

  PlaylistsOverviewProvider call(PlaylistsOverviewScope scope) =>
      PlaylistsOverviewProvider._(argument: scope, from: this);

  @override
  String toString() => r'playlistsOverviewProvider';
}

/// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
/// 创建 / 编辑 / 删除的就地补丁。
///
/// autoDispose family([PlaylistsOverviewScope])：4 个消费入口（桌面/移动
/// playlists 独立页、configuration 管理 section、overview 移动骨架）按 scope
/// 定位实例，orderScopeKey=null 表不持久化顺序（configuration / mobile 独立页）。
///
/// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
/// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
/// provider），scope 只留 orderScopeKey + includeSystem 两个业务参数。
///
/// **reorder 保持 fire-and-forget 语义**（原 controller
/// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
/// 等待窗口。

abstract class _$PlaylistsOverview
    extends $AsyncNotifier<PlaylistsOverviewState> {
  late final _$args = ref.$arg as PlaylistsOverviewScope;
  PlaylistsOverviewScope get scope => _$args;

  FutureOr<PlaylistsOverviewState> build(PlaylistsOverviewScope scope);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PlaylistsOverviewState>, PlaylistsOverviewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PlaylistsOverviewState>,
                PlaylistsOverviewState
              >,
              AsyncValue<PlaylistsOverviewState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
