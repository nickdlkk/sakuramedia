import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/media_import/data/failure_reason_descriptions.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';

/// `GET /movie-subscriptions` 的单条订阅影片。
///
/// 字段构成与 `MovieListItemDto` 差别很大——它描述的是「这部订阅片的资源查询走到
/// 哪一步了」，而不是影片资料本身，因此后端也独立成一套 schema。复用
/// [MovieImageDto] 只是因为封面结构相同。
class MovieSubscriptionListItemDto {
  const MovieSubscriptionListItemDto({
    required this.movieId,
    required this.movieNumber,
    required this.title,
    required this.status,
    this.coverImage,
    this.releaseDate,
    this.subscribedAt,
    this.isFresh = false,
    this.attemptCount = 0,
    this.attemptLimit = 0,
    this.lastSearchedAt,
    this.lastError,
    this.deadDownloadTaskCount = 0,
    this.mediaCount = 0,
    this.importOperation,
  });

  /// 统一 action 协议（`POST /system/resource-task-actions`）的操作主键。
  ///
  /// 行内/多选/广播仍以 [movieNumber] 为标识（Key、跨页补丁都按番号建模），
  /// 本字段只在调 API 时把选中番号映射成整数 `resource_ids`。
  final int movieId;

  final String movieNumber;
  final String title;
  final MovieImageDto? coverImage;

  /// 后端按 `YYYY-MM-DD` 下发，保持字符串原样展示（无需时区换算）。
  final String? releaseDate;
  final DateTime? subscribedAt;
  final MovieSubscriptionStatus status;

  /// 是否算新片（`release_date` 在 90 天内，含未来日期）。
  ///
  /// 新片**每轮都查、不计次数、永不放弃**，所以为 `true` 时 [attemptCount] 恒为 0，
  /// UI 该展示「持续查询中」而不是次数进度。
  final bool isFresh;

  /// 老片本轮没找到资源的次数 / 放弃阈值（默认 3）。成功找到资源后后端清零，
  /// 所以下载中 / 已入库等状态恒为 0。[isFresh] 为 true 时这对值无意义。
  final int attemptCount;
  final int attemptLimit;

  final DateTime? lastSearchedAt;

  /// 仅 `status == failed` 时有值，为索引器调用的错误详情。
  final String? lastError;

  /// 该影片已判死的下载任务数：试过几个种子都失败了。
  final int deadDownloadTaskCount;

  final int mediaCount;

  /// `import_failed`（未入库）档的可操作上下文：最新导入作业与后端计算的可用动作。
  final MovieSubscriptionImportOperationDto? importOperation;

  factory MovieSubscriptionListItemDto.fromJson(Map<String, dynamic> json) {
    final coverImage = asMapOrNull(json['cover_image']);
    return MovieSubscriptionListItemDto(
      movieId: asInt(json['movie_id']),
      movieNumber: asStringOrNull(json['movie_number']) ?? '',
      title: asStringOrNull(json['title']) ?? '',
      coverImage: coverImage == null
          ? null
          : MovieImageDto.fromJson(coverImage),
      releaseDate: asStringOrNull(json['release_date'], trim: true),
      subscribedAt: asDateTime(json['subscribed_at']),
      status: MovieSubscriptionStatusX.fromWire(json['status']),
      isFresh: json['is_fresh'] as bool? ?? false,
      attemptCount: asInt(json['attempt_count']),
      attemptLimit: asInt(json['attempt_limit']),
      lastSearchedAt: asDateTime(json['last_searched_at']),
      lastError: asStringOrNull(json['last_error'], trim: true),
      deadDownloadTaskCount: asInt(json['dead_download_task_count']),
      mediaCount: asInt(json['media_count']),
      importOperation: MovieSubscriptionImportOperationDto.fromJsonOrNull(
        asMapOrNull(json['import_operation']),
      ),
    );
  }

  /// 列表主标题：标题非空用标题，否则回落番号（title_zh 已随后端下线，
  /// 中文标题收拢进 title，这里保留番号分支作为防御性兜底）。
  String get displayTitle {
    final original = title.trim();
    return original.isNotEmpty ? original : movieNumber;
  }

  /// 行内展示文案：后端的 `import_failed` 是一个操作桶，零产出需要和真正失败区分。
  String get displayStatusLabel {
    if (status != MovieSubscriptionStatus.importFailed) {
      return status.label;
    }
    return importOperation?.isNoMedia == true ? '未产出媒体' : '导入失败';
  }

  bool get isNoMediaImport =>
      status == MovieSubscriptionStatus.importFailed &&
      importOperation?.isNoMedia == true;

  /// 重置查询状态对该条目是否有意义。
  ///
  /// 已入库的片不再参与资源查询，重置它只会平白多打一轮索引器；下载中的片已经
  /// 找到种子，重置同样无意义；**导入失败的片文件已经在盘上，卡的是入库那一步，
  /// 让它去重新找种子只会白下一遍**。「待查」在统一 action 协议下会被后端按
  /// `state_not_actionable` 跳过（投影是 pending，不属三个失败态），所以也不给
  /// 按钮。只剩三态（缺资源 / 已放弃 / 查询出错）允许重置。
  bool get canResetSearch =>
      status == MovieSubscriptionStatus.missing ||
      status == MovieSubscriptionStatus.exhausted ||
      status == MovieSubscriptionStatus.failed;

  /// 重置资源查询状态后的本地投影，供列表就地打补丁、不整页重拉。
  ///
  /// 统一 action 的 `reset_retry_budget` 语义是**保留历史、重开预算**（回
  /// `pending`、本轮计数归零、`retry_round + 1`），所以这里对齐那个终态：状态回
  /// `pending`、次数归零、上次查询与错误清空。[deadDownloadTaskCount] **保留
  /// 不动**：重置不放开选种黑名单，已判死的种子仍然是死的。
  MovieSubscriptionListItemDto afterSearchReset() {
    return MovieSubscriptionListItemDto(
      movieId: movieId,
      movieNumber: movieNumber,
      title: title,
      coverImage: coverImage,
      releaseDate: releaseDate,
      subscribedAt: subscribedAt,
      status: MovieSubscriptionStatus.pending,
      isFresh: isFresh,
      attemptCount: 0,
      attemptLimit: attemptLimit,
      deadDownloadTaskCount: deadDownloadTaskCount,
      mediaCount: mediaCount,
    );
  }
}

/// `import_failed`（未入库）档的最新导入作业上下文；`availableActions` 由后端计算，
/// 前端只按枚举渲染（open_import_job / retry_failed_files / rerun_import）。
class MovieSubscriptionImportOperationDto {
  const MovieSubscriptionImportOperationDto({
    required this.importJobId,
    this.downloadTaskId,
    required this.state,
    this.outcome = 'failed',
    this.importedCount = 0,
    this.skippedCount = 0,
    this.failedCount = 0,
    this.retryableFileCount = 0,
    this.availableActions = const <String>[],
    this.failureReason,
    this.failureDetail,
  });

  final int importJobId;

  /// 失败导入关联的下载任务 id；手动目录导入的作业为 null。
  final int? downloadTaskId;
  final String state;

  /// `no_media` 表示作业完成但没有任何 Media 产出；`failed` 表示存在失败项。
  final String outcome;
  final int importedCount;
  final int skippedCount;
  final int failedCount;

  /// 可重导（kind=file）失败条目数：为 0 时后端不会下发 retry_failed_files。
  final int retryableFileCount;
  final List<String> availableActions;

  /// 最新导入作业首条失败条目的 reason 原始码；无失败条目时为 null。
  final String? failureReason;

  /// 最新导入作业首条失败条目的 detail 文案（可能为空串）。
  final String? failureDetail;

  bool get isNoMedia => outcome == 'no_media';

  bool get canRetryFailedFiles =>
      availableActions.contains('retry_failed_files');
  bool get canRerun => availableActions.contains('rerun_import');
  bool get canOpenImportJob => availableActions.contains('open_import_job');
  bool get canDeleteFailedDownload =>
      availableActions.contains('delete_failed_download') &&
      downloadTaskId != null;

  /// 订阅行直接展示的导入结果说明。
  ///
  /// 后端 reason 描述本身常已带 detail（如 no_media_files_found 的映射文案就
  /// 包含"下载目录中没有扫描到可导入的视频"），detail 与描述重合时不重复拼接。
  String? get importFailureMessage {
    final reason = failureReason?.trim() ?? '';
    final description = reason.isEmpty ? '' : describeFailureReason(reason);
    final detail = failureDetail?.trim() ?? '';
    final reasonMessage = reason.isEmpty
        ? ''
        : detail.isEmpty || description.contains(detail)
        ? description
        : '$description：$detail';

    if (isNoMedia) {
      final skippedMessage = skippedCount > 0 ? '跳过 $skippedCount 个文件' : '';
      if (skippedMessage.isEmpty && reasonMessage.isEmpty) {
        return '未产出媒体';
      }
      if (reasonMessage.isEmpty) {
        return '未产出媒体：$skippedMessage';
      }
      if (skippedMessage.isEmpty) {
        return '未产出媒体：$reasonMessage';
      }
      return '未产出媒体：$skippedMessage；$reasonMessage';
    }
    return reasonMessage.isEmpty ? null : reasonMessage;
  }

  static MovieSubscriptionImportOperationDto? fromJsonOrNull(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return null;
    }
    return MovieSubscriptionImportOperationDto(
      importJobId: asInt(json['import_job_id']),
      downloadTaskId: asIntOrNull(json['download_task_id']),
      state: asStringOrNull(json['state']) ?? '',
      outcome: asStringOrNull(json['outcome']) ?? 'failed',
      importedCount: asInt(json['imported_count']),
      skippedCount: asInt(json['skipped_count']),
      failedCount: asInt(json['failed_count']),
      retryableFileCount: asInt(json['retryable_file_count']),
      availableActions:
          (json['available_actions'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
      failureReason: asStringOrNull(json['failure_reason'], trim: true),
      failureDetail: asStringOrNull(json['failure_detail'], trim: true),
    );
  }
}
