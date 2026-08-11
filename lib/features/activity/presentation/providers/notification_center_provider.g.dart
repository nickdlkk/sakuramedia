// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_center_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局常驻通知中心。会话登录后自动 bootstrap 并连接 SSE，登出时断流清空。

@ProviderFor(NotificationCenter)
final notificationCenterProvider = NotificationCenterProvider._();

/// 全局常驻通知中心。会话登录后自动 bootstrap 并连接 SSE，登出时断流清空。
final class NotificationCenterProvider
    extends $NotifierProvider<NotificationCenter, NotificationCenterState> {
  /// 全局常驻通知中心。会话登录后自动 bootstrap 并连接 SSE，登出时断流清空。
  NotificationCenterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationCenterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationCenterHash();

  @$internal
  @override
  NotificationCenter create() => NotificationCenter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationCenterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationCenterState>(value),
    );
  }
}

String _$notificationCenterHash() =>
    r'94d7807279bd945791f1a3e8010e9d2c2db589e4';

/// 全局常驻通知中心。会话登录后自动 bootstrap 并连接 SSE，登出时断流清空。

abstract class _$NotificationCenter extends $Notifier<NotificationCenterState> {
  NotificationCenterState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<NotificationCenterState, NotificationCenterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NotificationCenterState, NotificationCenterState>,
              NotificationCenterState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
