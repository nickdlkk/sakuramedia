import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/shared/presentation/file_picker_with_bytes.dart';

class PluginZipFile {
  const PluginZipFile({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

typedef PluginZipPicker = Future<PluginZipFile?> Function();

@visibleForTesting
PluginZipPicker? debugPluginZipPicker;

class PluginZipPickerException implements Exception {
  const PluginZipPickerException(this.message);

  final String message;
}

Future<PluginZipFile?> pickPluginZip() async {
  final override = debugPluginZipPicker;
  if (override != null) {
    return override();
  }

  try {
    final picked = await pickFileWithBytes(
      allowedExtensions: const <String>['zip'],
      unreadableMessage: '无法读取所选插件包，请换一个文件再试',
      pickerUnavailableMessage: '文件选择器尚未加载，请完整重启应用后再试',
      openFailureMessage: '打开文件选择器失败，请稍后再试',
    );
    if (picked == null) {
      return null;
    }
    return PluginZipFile(bytes: picked.bytes, fileName: picked.fileName);
  } on FilePickerWithBytesException catch (error) {
    throw PluginZipPickerException(error.message);
  }
}
