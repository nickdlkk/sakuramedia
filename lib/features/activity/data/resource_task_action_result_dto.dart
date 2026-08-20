import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_exception.dart';

/// 统一 action 连点被 mutex 顶回（单资源互斥到 `resource_action:{task_key}:{id}`）。
///
/// 调用方据此给「已有相同操作在执行中」一类的友好提示，而不是透传后端原文。
bool isResourceTaskActionConflict(Object error) {
  return error is ApiException &&
      error.statusCode == 409 &&
      error.error?.code == 'resource_task_action_conflict';
}

/// 统一资源任务操作（`POST /system/resource-task-actions`）里被跳过的单项。
///
/// 部分成功语义：合格记录直接生效，不合格记录只出现在这里，不整批 4xx。
/// 一个 `resource_id` 只回报一个最主要的原因。
class ResourceTaskActionSkippedItemDto {
  const ResourceTaskActionSkippedItemDto({
    required this.resourceId,
    required this.reason,
  });

  /// 协议级：retry_now / reset 要求已有状态行（rerun 会播种，不报此项）。
  static const String reasonTaskStateNotFound = 'task_state_not_found';

  /// 协议级：当前投影状态不允许该 action。
  static const String reasonStateNotActionable = 'state_not_actionable';

  /// 领域合格性：影片已删除。
  static const String reasonMovieNotFound = 'movie_not_found';

  /// 领域合格性：缺 JavDB ID（互动同步）。
  static const String reasonMovieJavdbIdMissing = 'movie_javdb_id_missing';

  /// 领域合格性：影片未订阅（订阅查询任务）。
  static const String reasonMovieNotSubscribed = 'movie_not_subscribed';

  /// 领域合格性：媒体已被删除。
  static const String reasonMediaNotFound = 'media_not_found';

  /// 领域合格性：媒体存在但 valid = false。
  static const String reasonMediaInvalid = 'media_invalid';

  final int resourceId;
  final String reason;

  /// 展示用中文文案；未知原因回落为原始值，便于后端新增原因时不至于空白。
  String get reasonLabel {
    switch (reason) {
      case reasonTaskStateNotFound:
        return '没有任务记录';
      case reasonStateNotActionable:
        return '当前状态不支持该操作';
      case reasonMovieNotFound:
        return '影片已被删除';
      case reasonMovieJavdbIdMissing:
        return '影片缺少 JavDB ID';
      case reasonMovieNotSubscribed:
        return '影片未订阅';
      case reasonMediaNotFound:
        return '媒体已被删除';
      case reasonMediaInvalid:
        return '媒体已失效';
      default:
        return reason.isEmpty ? '未知原因' : reason;
    }
  }

  factory ResourceTaskActionSkippedItemDto.fromJson(Map<String, dynamic> json) {
    return ResourceTaskActionSkippedItemDto(
      resourceId: asInt(json['resource_id']),
      reason: asStringOrNull(json['reason'], trim: true) ?? '',
    );
  }
}

/// `POST /system/resource-task-actions` 的响应。
///
/// 全部选择项都不合格时也返回 200——按 [acceptedResourceIds] 为空提示，
/// 不能按请求失败处理。
class ResourceTaskActionResultDto {
  const ResourceTaskActionResultDto({
    required this.taskKey,
    required this.action,
    this.taskRunId,
    this.acceptedResourceIds = const <int>[],
    this.skipped = const <ResourceTaskActionSkippedItemDto>[],
  });

  final String taskKey;
  final String action;

  /// retry_now / rerun 入队的可跟踪 run；reset_retry_budget 不建 run，为 null。
  final int? taskRunId;

  /// 实际生效的资源 ID，不含被跳过的。
  final List<int> acceptedResourceIds;

  final List<ResourceTaskActionSkippedItemDto> skipped;

  int get acceptedCount => acceptedResourceIds.length;
  int get skippedCount => skipped.length;
  bool get hasSkipped => skipped.isNotEmpty;

  Set<int> get skippedResourceIds =>
      skipped.map((item) => item.resourceId).toSet();

  factory ResourceTaskActionResultDto.fromJson(Map<String, dynamic> json) {
    final rawAccepted = json['accepted_resource_ids'];
    final rawSkipped = json['skipped'];
    return ResourceTaskActionResultDto(
      taskKey: json['task_key'] as String? ?? '',
      action: json['action'] as String? ?? '',
      taskRunId: asIntOrNull(json['task_run_id']),
      acceptedResourceIds: rawAccepted is List
          ? rawAccepted
                .whereType<num>()
                .map((value) => value.toInt())
                .toList(growable: false)
          : const <int>[],
      skipped: rawSkipped is List
          ? rawSkipped
                .map(asMapOrNull)
                .whereType<Map<String, dynamic>>()
                .map(ResourceTaskActionSkippedItemDto.fromJson)
                .toList(growable: false)
          : const <ResourceTaskActionSkippedItemDto>[],
    );
  }
}
