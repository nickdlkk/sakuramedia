import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media_import/data/subtitle_import_job_dto.dart';

/// JAV 字幕目录导入接口封装（后端 `subtitle-import` 标签，挂载于根路径）。
class SubtitleImportApi {
  const SubtitleImportApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 从后端白名单目录创建异步字幕导入作业。
  Future<SubtitleImportTriggerResponseDto> createImportJob({
    required String sourcePath,
  }) async {
    final response = await _apiClient.post(
      '/subtitle-imports',
      data: <String, dynamic>{'source_path': sourcePath},
    );
    return SubtitleImportTriggerResponseDto.fromJson(response);
  }

  /// 分页查询字幕导入作业（按 id 倒序）。
  Future<PaginatedResponseDto<SubtitleImportJobListItemDto>> listImportJobs({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/subtitle-imports',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<SubtitleImportJobListItemDto>.fromJson(
      response,
      SubtitleImportJobListItemDto.fromJson,
    );
  }

  /// 查询作业详情（含失败文件）。
  Future<SubtitleImportJobDto> getImportJob(int subtitleImportJobId) async {
    final response = await _apiClient.get(
      '/subtitle-imports/$subtitleImportJobId',
    );
    return SubtitleImportJobDto.fromJson(response);
  }

  /// 重导失败文件；[files] 为空时由后端重导全部可重导文件。
  Future<SubtitleImportTriggerResponseDto> retryFailedFiles(
    int subtitleImportJobId, {
    List<String>? files,
  }) async {
    final response = await _apiClient.post(
      '/subtitle-imports/$subtitleImportJobId/retry',
      data: <String, dynamic>{if (files != null) 'files': files},
    );
    return SubtitleImportTriggerResponseDto.fromJson(response);
  }

  /// 删除一个终态作业中的失败源文件。
  Future<SubtitleImportJobDto> deleteFailedFile(
    int subtitleImportJobId, {
    required String path,
  }) async {
    final response = await _apiClient.delete(
      '/subtitle-imports/$subtitleImportJobId/failed-files',
      data: <String, dynamic>{'path': path},
    );
    return SubtitleImportJobDto.fromJson(response);
  }

  /// 重命名一个终态作业中的失败源文件。
  Future<SubtitleImportJobDto> renameFailedFile(
    int subtitleImportJobId, {
    required String path,
    required String newName,
  }) async {
    final response = await _apiClient.post(
      '/subtitle-imports/$subtitleImportJobId/failed-files/rename',
      data: <String, dynamic>{'path': path, 'new_name': newName},
    );
    return SubtitleImportJobDto.fromJson(response);
  }
}
