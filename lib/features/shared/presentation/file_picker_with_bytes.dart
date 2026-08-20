import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

export 'package:file_picker/file_picker.dart' show FileType;

/// 通过 file_picker 选择单个文件并读取字节的结果。
class PickedFileWithBytes {
  const PickedFileWithBytes({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// 文件选择失败（读取失败 / 平台插件不可用 / 平台异常）的领域异常。
class FilePickerWithBytesException implements Exception {
  const FilePickerWithBytesException(this.message);

  final String message;
}

/// 统一的“选择单个文件并读取字节”原语。
///
/// image_search 与 plugins 的文件选择器此前复制了同一套
/// `FilePicker.platform.pickFiles` + 空结果 / 空字节处理 + 平台异常映射，
/// 这里把横切逻辑收拢，业务侧只保留扩展名、初始目录、路径回退与文案。
Future<PickedFileWithBytes?> pickFileWithBytes({
  List<String>? allowedExtensions,
  FileType type = FileType.custom,
  String? initialDirectory,
  bool allowCompression = false,
  Future<Uint8List?> Function(String path)? readPathFallback,
  required String unreadableMessage,
  required String pickerUnavailableMessage,
  required String openFailureMessage,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: type == FileType.custom ? allowedExtensions : null,
      allowMultiple: false,
      withData: true,
      allowCompression: allowCompression,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && readPathFallback != null && file.path != null) {
      bytes = await readPathFallback(file.path!);
    }
    if (bytes == null || bytes.isEmpty) {
      throw FilePickerWithBytesException(unreadableMessage);
    }
    return PickedFileWithBytes(bytes: bytes, fileName: file.name);
  } on MissingPluginException catch (error, stackTrace) {
    debugPrint('File picker plugin is unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
    throw FilePickerWithBytesException(pickerUnavailableMessage);
  } on PlatformException catch (error, stackTrace) {
    debugPrint('File picker failed: ${error.message ?? error.code}');
    debugPrintStack(stackTrace: stackTrace);
    throw FilePickerWithBytesException(error.message ?? openFailureMessage);
  }
}
