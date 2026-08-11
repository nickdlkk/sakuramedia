import 'package:flutter/material.dart';

enum AppModulePermission {
  search,
  mediaLibraries,
  downloadManagement,
}

const Set<AppModulePermission> kDefaultEnabledModules =
    <AppModulePermission>{
      AppModulePermission.search,
      AppModulePermission.mediaLibraries,
      AppModulePermission.downloadManagement,
    };

extension AppModulePermissionX on AppModulePermission {
  String get label {
    return switch (this) {
      AppModulePermission.search => '搜索',
      AppModulePermission.mediaLibraries => '媒体库',
      AppModulePermission.downloadManagement => '下载管理',
    };
  }

  String get description {
    return switch (this) {
      AppModulePermission.search => '控制文本搜索与以图搜图入口。',
      AppModulePermission.mediaLibraries => '控制媒体库设置页入口。',
      AppModulePermission.downloadManagement =>
        '控制下载器、索引器和下载偏好入口。',
    };
  }

  IconData get icon {
    return switch (this) {
      AppModulePermission.search => Icons.search_rounded,
      AppModulePermission.mediaLibraries => Icons.folder_open_outlined,
      AppModulePermission.downloadManagement => Icons.download_outlined,
    };
  }

  String get wireValue {
    return name;
  }

  static AppModulePermission? fromWireValue(String value) {
    for (final module in AppModulePermission.values) {
      if (module.wireValue == value) {
        return module;
      }
    }
    return null;
  }
}
