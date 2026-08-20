import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/media_import/data/import_job_dto.dart';

/// JAV 字幕目录导入作业列表项。
///
/// 字幕资产按影片番号归档，不归属于某个媒体库；其余作业状态语义与影片导入保持一致。
class SubtitleImportJobListItemDto implements ImportJobCardData {
  const SubtitleImportJobListItemDto({
    required this.id,
    required this.sourcePath,
    required this.taskRunId,
    required this.state,
    required this.importedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.startedAt,
    required this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final int id;
  @override
  final String sourcePath;
  @override
  String get displaySourcePath => sourcePath;
  @override
  final int? taskRunId;
  @override
  final String state;
  @override
  final int importedCount;
  @override
  final int skippedCount;
  @override
  final int failedCount;
  final DateTime? startedAt;
  @override
  final DateTime? finishedAt;
  @override
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  bool get isCloud115 => false;

  /// 字幕失败文件位于本地白名单目录，后端允许重命名和删除后再重导。
  @override
  bool get canMutateFailedSource => true;

  /// 字幕导入没有可选的传输方式，源文件始终保留。
  @override
  String? get importModeLabel => null;

  @override
  bool get canReimport => sourcePath.trim().isNotEmpty;

  @override
  bool get isTerminal => state == 'completed' || state == 'failed';

  factory SubtitleImportJobListItemDto.fromJson(Map<String, dynamic> json) {
    return SubtitleImportJobListItemDto(
      id: asInt(json['id']),
      sourcePath: json['source_path'] as String? ?? '',
      taskRunId: asIntOrNull(json['task_run_id']),
      state: json['state'] as String? ?? '',
      importedCount: asInt(json['imported_count']),
      skippedCount: asInt(json['skipped_count']),
      failedCount: asInt(json['failed_count']),
      startedAt: asDateTime(json['started_at']),
      finishedAt: asDateTime(json['finished_at']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

/// JAV 字幕导入作业详情（包含失败与跳过文件）。
class SubtitleImportJobDto extends SubtitleImportJobListItemDto
    implements ImportJobCardDetailData {
  const SubtitleImportJobDto({
    required super.id,
    required super.sourcePath,
    required super.taskRunId,
    required super.state,
    required super.importedCount,
    required super.skippedCount,
    required super.failedCount,
    required super.startedAt,
    required super.finishedAt,
    required super.createdAt,
    required super.updatedAt,
    required this.failedFiles,
  });

  @override
  final List<FailedFileDto> failedFiles;

  @override
  List<FailedFileDto> get actionableFailedFiles =>
      failedFiles.where((file) => file.isActionable).toList(growable: false);

  factory SubtitleImportJobDto.fromJson(Map<String, dynamic> json) {
    final base = SubtitleImportJobListItemDto.fromJson(json);
    final rawFiles = json['failed_files'];
    final failedFiles = rawFiles is List
        ? rawFiles
              .whereType<Map>()
              .map(
                (item) => FailedFileDto.fromJson(
                  item.map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
        : const <FailedFileDto>[];

    return SubtitleImportJobDto(
      id: base.id,
      sourcePath: base.sourcePath,
      taskRunId: base.taskRunId,
      state: base.state,
      importedCount: base.importedCount,
      skippedCount: base.skippedCount,
      failedCount: base.failedCount,
      startedAt: base.startedAt,
      finishedAt: base.finishedAt,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      failedFiles: failedFiles,
    );
  }
}

/// 字幕导入 / 重导请求的受理响应（202）。
class SubtitleImportTriggerResponseDto {
  const SubtitleImportTriggerResponseDto({
    required this.subtitleImportJobId,
    required this.taskRunId,
    required this.status,
  });

  final int subtitleImportJobId;
  final int taskRunId;
  final String status;

  factory SubtitleImportTriggerResponseDto.fromJson(Map<String, dynamic> json) {
    return SubtitleImportTriggerResponseDto(
      subtitleImportJobId: asInt(json['subtitle_import_job_id']),
      taskRunId: asInt(json['task_run_id']),
      status: json['status'] as String? ?? '',
    );
  }
}
