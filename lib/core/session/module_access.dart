import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';

AppModulePermission? requiredModuleForPath(String path) {
  if (path == desktopSearchPath ||
      path.startsWith('$desktopSearchPath/') ||
      path == mobileSearchPath ||
      path.startsWith('$mobileSearchPath/')) {
    return AppModulePermission.search;
  }
  if (path == mobileSettingsMediaLibrariesPath) {
    return AppModulePermission.mediaLibraries;
  }
  if (path == mobileSettingsDownloadersPath ||
      path == mobileSettingsIndexersPath) {
    return AppModulePermission.downloadManagement;
  }
  return null;
}

bool isPathAllowed({
  required Set<AppModulePermission> enabledModules,
  required String path,
}) {
  final required = requiredModuleForPath(path);
  return required == null || enabledModules.contains(required);
}
