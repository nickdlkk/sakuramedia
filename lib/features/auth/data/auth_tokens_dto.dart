class AuthUserDto {
  const AuthUserDto({
    required this.username,
    this.role = 'user',
    this.permissions,
  });

  final String username;
  final String role;
  final List<String>? permissions;

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    final permissions = rawPermissions is List
        ? rawPermissions
            .whereType<Object?>()
            .map((value) => '$value')
            .toList(growable: false)
        : null;
    return AuthUserDto(
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      'role': role,
      if (permissions != null) 'permissions': permissions,
    };
  }
}

class AuthTokensDto {
  const AuthTokensDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.expiresAt,
    required this.refreshExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime expiresAt;
  final DateTime refreshExpiresAt;
  final AuthUserDto user;

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) {
    return AuthTokensDto(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      refreshExpiresAt:
          DateTime.tryParse(json['refresh_expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      user: AuthUserDto.fromJson(_asJsonMap(json['user'])),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
      'user': user.toJson(),
    };
  }

  static Map<String, dynamic> _asJsonMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
