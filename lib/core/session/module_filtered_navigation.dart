import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';

List<AppNavGroup> filterNavGroupsForModules(
  List<AppNavGroup> groups, {
  required Set<AppModulePermission> enabledModules,
}) {
  return groups
      .map((group) {
        final items = group.items
            .where(
              (item) => _isNavItemAllowed(
                path: item.path,
                enabledModules: enabledModules,
              ),
            )
            .toList(growable: false);
        if (items.isEmpty) {
          return null;
        }
        return AppNavGroup(
          id: group.id,
          label: group.label,
          icon: group.icon,
          items: items,
          isCollapsible: group.isCollapsible,
          sectionLabel: group.sectionLabel,
        );
      })
      .whereType<AppNavGroup>()
      .toList(growable: false);
}

bool _isNavItemAllowed({
  required String path,
  required Set<AppModulePermission> enabledModules,
}) {
  if ((path == desktopSearchPath || path == mobileSearchPath) &&
      !enabledModules.contains(AppModulePermission.search)) {
    return false;
  }
  if (!enabledModules.contains(AppModulePermission.mediaLibraries) &&
      path == mobileSettingsMediaLibrariesPath) {
    return false;
  }
  return true;
}
