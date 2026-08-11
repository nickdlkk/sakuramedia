import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/session/app_module_permission.dart';

@immutable
class SavedAccount {
  const SavedAccount({
    required this.id,
    required this.baseUrl,
    required this.username,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.enabledModules,
  });

  final String id;
  final String baseUrl;
  final String username;
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
  final Set<AppModulePermission> enabledModules;

  bool get hasSession => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  String get displayLabel => username.trim().isNotEmpty ? username.trim() : baseUrl;

  String get subtitle => baseUrl.trim();

  SavedAccount copyWith({
    String? id,
    String? baseUrl,
    String? username,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    Set<AppModulePermission>? enabledModules,
  }) {
    return SavedAccount(
      id: id ?? this.id,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      enabledModules: enabledModules ?? this.enabledModules,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'base_url': baseUrl,
      'username': username,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      'enabled_modules':
          enabledModules
              .map((module) => module.wireValue)
              .toList(growable: false),
    };
  }

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    final rawModules = json['enabled_modules'];
    final modules =
        rawModules is List
            ? rawModules
                .whereType<Object?>()
                .map((value) => AppModulePermissionX.fromWireValue('$value'))
                .whereType<AppModulePermission>()
                .toSet()
            : <AppModulePermission>{};
    return SavedAccount(
      id: json['id'] as String? ?? '',
      baseUrl: json['base_url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      enabledModules:
          modules.isEmpty ? {...kDefaultEnabledModules} : modules,
    );
  }

  static String normalizedIdentity({
    required String baseUrl,
    required String username,
  }) {
    return '${baseUrl.trim().toLowerCase()}|${username.trim().toLowerCase()}';
  }

  bool matchesIdentity({required String baseUrl, required String username}) {
    return normalizedIdentity(baseUrl: this.baseUrl, username: this.username) ==
        normalizedIdentity(baseUrl: baseUrl, username: username);
  }
}
