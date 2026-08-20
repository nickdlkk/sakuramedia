// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task_center_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 下载任务中心（Riverpod）：分页拉 `/download-tasks` + SSE 实时进度 + 暂停/恢复/删除。
///
/// 迁移前对应：`DownloadTaskCenterController extends ChangeNotifier`。
///
/// 差异：
/// - 首屏 loading / error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）；
///   retry 走 `ref.invalidateSelf()`。
/// - 筛选切换（[applyFilter]）先同步更新筛选控件，保留旧列表并防抖刷新第一页。
/// - SSE 触发的「首页去抖合并」维持原生流程：独立 fetchPage(1) + 手工 upsert，
///   有 [_minMergeInterval] 限流兜底。

@ProviderFor(DownloadTaskCenter)
final downloadTaskCenterProvider = DownloadTaskCenterProvider._();

/// 下载任务中心（Riverpod）：分页拉 `/download-tasks` + SSE 实时进度 + 暂停/恢复/删除。
///
/// 迁移前对应：`DownloadTaskCenterController extends ChangeNotifier`。
///
/// 差异：
/// - 首屏 loading / error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）；
///   retry 走 `ref.invalidateSelf()`。
/// - 筛选切换（[applyFilter]）先同步更新筛选控件，保留旧列表并防抖刷新第一页。
/// - SSE 触发的「首页去抖合并」维持原生流程：独立 fetchPage(1) + 手工 upsert，
///   有 [_minMergeInterval] 限流兜底。
final class DownloadTaskCenterProvider
    extends
        $AsyncNotifierProvider<DownloadTaskCenter, DownloadTaskCenterState> {
  /// 下载任务中心（Riverpod）：分页拉 `/download-tasks` + SSE 实时进度 + 暂停/恢复/删除。
  ///
  /// 迁移前对应：`DownloadTaskCenterController extends ChangeNotifier`。
  ///
  /// 差异：
  /// - 首屏 loading / error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）；
  ///   retry 走 `ref.invalidateSelf()`。
  /// - 筛选切换（[applyFilter]）先同步更新筛选控件，保留旧列表并防抖刷新第一页。
  /// - SSE 触发的「首页去抖合并」维持原生流程：独立 fetchPage(1) + 手工 upsert，
  ///   有 [_minMergeInterval] 限流兜底。
  DownloadTaskCenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'downloadTaskCenterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadTaskCenterHash();

  @$internal
  @override
  DownloadTaskCenter create() => DownloadTaskCenter();
}

String _$downloadTaskCenterHash() =>
    r'f59705ed4e19faf4a34e49ac10260c40c791d2a0';

/// 下载任务中心（Riverpod）：分页拉 `/download-tasks` + SSE 实时进度 + 暂停/恢复/删除。
///
/// 迁移前对应：`DownloadTaskCenterController extends ChangeNotifier`。
///
/// 差异：
/// - 首屏 loading / error 由外层 [AsyncValue] 表达（[AsyncLoading]/[AsyncError]）；
///   retry 走 `ref.invalidateSelf()`。
/// - 筛选切换（[applyFilter]）先同步更新筛选控件，保留旧列表并防抖刷新第一页。
/// - SSE 触发的「首页去抖合并」维持原生流程：独立 fetchPage(1) + 手工 upsert，
///   有 [_minMergeInterval] 限流兜底。

abstract class _$DownloadTaskCenter
    extends $AsyncNotifier<DownloadTaskCenterState> {
  FutureOr<DownloadTaskCenterState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DownloadTaskCenterState>,
              DownloadTaskCenterState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DownloadTaskCenterState>,
                DownloadTaskCenterState
              >,
              AsyncValue<DownloadTaskCenterState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
