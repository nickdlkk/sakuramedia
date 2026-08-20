import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/hints/diagnostic_hints.dart';

/// 索引器（Torznab）先校验静态配置，再进行真实搜索连通性检测。
///
/// 「索引器」在配置页分类列表里的索引（`desktop_configuration_page.dart`）。
const DiagnosticFixTarget _indexerTarget = DiagnosticFixTarget.configurationTab(
  3,
);

/// `entries-empty`（前端读配置发现没条目）与 `no_indexers_configured`（后端发起
/// 搜索时发现没条目）在用户眼里是同一件事，共用一条文案。
const DiagnosticHint _noIndexersHint = DiagnosticHint(
  cause: '还没有添加任何站点。',
  fixHint: '在「索引器」页至少添加一个站点，并给它绑定一个下载器。',
  fixTarget: _indexerTarget,
);

const Map<String, DiagnosticHint> indexerHints = <String, DiagnosticHint>{
  'entries-empty': _noIndexersHint,
  'entry-url-invalid': DiagnosticHint(
    cause: '有站点的地址是空的，或者格式不对。',
    fixHint: '在「索引器」页检查每个站点的地址。',
    fixTarget: _indexerTarget,
  ),
  'entry-client-missing': DiagnosticHint(
    cause: '有站点没有绑定下载器。',
    fixHint: '在「索引器」页给它选一个下载器。',
    fixTarget: _indexerTarget,
  ),
  'entry-client-stale': DiagnosticHint(
    cause: '有站点绑定的下载器已经被删了。',
    fixHint: '在「索引器」页给它重新选一个下载器。',
    fixTarget: _indexerTarget,
  ),
  'no-indexers-configured': _noIndexersHint,
  'torznab-request-error': DiagnosticHint(
    cause: '搜索测试失败了。',
    fixHint: '确认索引器服务能访问，然后在「索引器」页核对各站点地址与 API Key。',
    fixTarget: _indexerTarget,
  ),
};

/// 索引器静态校验结果。`null` 表示可继续执行在线连通性检测。
///
/// 规则按顺序判定，命中第一条就返回。
String? resolveIndexerConfigHintKey({
  required IndexerSettingsDto settings,
  required List<DownloadClientDto> existingClients,
}) {
  if (settings.indexers.isEmpty) return 'entries-empty';
  final existingIds = existingClients.map((c) => c.id).toSet();
  for (final entry in settings.indexers) {
    if (entry.url.trim().isEmpty || !_isHttpUrl(entry.url)) {
      return 'entry-url-invalid';
    }
    if (entry.downloadClients.isEmpty) {
      return 'entry-client-missing';
    }
    if (!entry.downloadClientIds.every(existingIds.contains)) {
      return 'entry-client-stale';
    }
  }
  return null;
}

String resolveIndexerConnectionHintKey(String? errorType) {
  switch (errorType?.trim()) {
    case 'no_indexers_configured':
      return 'no-indexers-configured';
    case 'torznab_request_error':
    default:
      return 'torznab-request-error';
  }
}

bool _isHttpUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}
