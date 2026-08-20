// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_import_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// JAV 字幕导入：分页作业、详情缓存、操作与 task_run SSE 的唯一状态源。

@ProviderFor(SubtitleImport)
final subtitleImportProvider = SubtitleImportProvider._();

/// JAV 字幕导入：分页作业、详情缓存、操作与 task_run SSE 的唯一状态源。
final class SubtitleImportProvider
    extends $AsyncNotifierProvider<SubtitleImport, SubtitleImportState> {
  /// JAV 字幕导入：分页作业、详情缓存、操作与 task_run SSE 的唯一状态源。
  SubtitleImportProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'subtitleImportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleImportHash();

  @$internal
  @override
  SubtitleImport create() => SubtitleImport();
}

String _$subtitleImportHash() => r'189e04b8290a243a74ae365baddc77d5ecda9f98';

/// JAV 字幕导入：分页作业、详情缓存、操作与 task_run SSE 的唯一状态源。

abstract class _$SubtitleImport extends $AsyncNotifier<SubtitleImportState> {
  FutureOr<SubtitleImportState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SubtitleImportState>, SubtitleImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SubtitleImportState>, SubtitleImportState>,
              AsyncValue<SubtitleImportState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
