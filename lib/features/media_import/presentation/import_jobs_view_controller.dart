import 'package:sakuramedia/features/activity/data/task_run_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';

/// 导入作业页共享的动作契约。
///
/// 状态由 Riverpod provider 暴露为不可变的 [ImportJobsViewState]；页面只把
/// notifier 当作动作入口，不再依赖 `Listenable` 或可变 controller 字段。
abstract interface class ImportJobsViewController {
  Future<void> loadFirstPage();
  Future<void> refresh();
  Future<void> loadMore();
  Future<void> ensureDetail(int jobId, {bool force = false});
  Future<String?> retryFailedFiles(int jobId, {List<String>? files});

  /// 按作业原参数新建一个导入任务。
  Future<String?> reimportJob(int jobId);
}

/// 页面渲染所需的只读状态视图。
abstract interface class ImportJobsViewData {
  List<ImportJobCardData> get jobs;
  bool get isInitialLoading;
  bool get isLoadingMore;
  String? get initialError;
  String? get loadMoreError;

  TaskRunDto? taskRunFor(int? taskRunId);
  ImportJobCardDetailData? detailFor(int jobId);
  bool isDetailLoading(int jobId);
  String? detailError(int jobId);
}
