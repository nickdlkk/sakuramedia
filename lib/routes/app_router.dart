import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/core/session/saved_accounts_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/desktop_routes.dart' as desktop_routes;
import 'package:sakuramedia/routes/mobile_routes.dart' as mobile_routes;

GoRouter buildAppRouter(
  AppPlatform platform,
  SessionStore sessionStore, {
  SavedAccountsStore? savedAccountsStore,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  switch (platform) {
    case AppPlatform.desktop:
      return buildDesktopRouter(
        sessionStore: sessionStore,
        savedAccountsStore: savedAccountsStore,
      );
    case AppPlatform.mobile:
      return buildMobileRouter(
        sessionStore: sessionStore,
        savedAccountsStore: savedAccountsStore,
      );
    case AppPlatform.web:
      return buildWebRouter(
        sessionStore: sessionStore,
        savedAccountsStore: savedAccountsStore,
      );
  }
}

GoRouter buildDesktopRouter({
  required SessionStore sessionStore,
  SavedAccountsStore? savedAccountsStore,
}) {
  desktop_routes.currentDesktopRoutePlatform = AppPlatform.desktop;
  return _buildRouter(
    sessionStore: sessionStore,
    savedAccountsStore: savedAccountsStore,
    navigatorKey: desktop_routes.desktopRootNavigatorKey,
    routes: desktop_routes.$appRoutes,
    rootRedirectPath: desktopOverviewPath,
  );
}

GoRouter buildMobileRouter({
  required SessionStore sessionStore,
  SavedAccountsStore? savedAccountsStore,
}) {
  mobile_routes.currentMobileRoutePlatform = AppPlatform.mobile;
  return _buildRouter(
    sessionStore: sessionStore,
    savedAccountsStore: savedAccountsStore,
    navigatorKey: mobile_routes.mobileRootNavigatorKey,
    routes: mobile_routes.$appRoutes,
    rootRedirectPath: mobileOverviewPath,
  );
}

GoRouter buildWebRouter({
  required SessionStore sessionStore,
  SavedAccountsStore? savedAccountsStore,
}) {
  desktop_routes.currentDesktopRoutePlatform = AppPlatform.web;
  return _buildRouter(
    sessionStore: sessionStore,
    savedAccountsStore: savedAccountsStore,
    navigatorKey: desktop_routes.desktopRootNavigatorKey,
    routes: desktop_routes.$appRoutes,
    rootRedirectPath: desktopOverviewPath,
  );
}

GoRouter _buildRouter({
  required SessionStore sessionStore,
  SavedAccountsStore? savedAccountsStore,
  required GlobalKey<NavigatorState> navigatorKey,
  required List<RouteBase> routes,
  required String rootRedirectPath,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // Combine listenables for session + saved-accounts changes
  final refreshListenable = savedAccountsStore != null
      ? ListenableGroup([sessionStore, savedAccountsStore])
      : sessionStore;

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    refreshListenable: refreshListenable,
    routes: routes,
    redirect: (context, state) {
      final path = state.uri.path;
      final hasSession = sessionStore.hasSession;
      final isLoginPage = path == loginPath;

      if (!hasSession && !isLoginPage) {
        return loginPath;
      }
      if (hasSession && isLoginPage) {
        return rootRedirectPath;
      }
      if (path == '/') {
        return hasSession ? rootRedirectPath : loginPath;
      }

      // Module permission guard — block access to restricted paths
      if (savedAccountsStore != null) {
        final redirect = _moduleBlockedRedirect(path, savedAccountsStore, rootRedirectPath);
        if (redirect != null) return redirect;
      }

      return null;
    },
  );
}

/// Returns the redirect path if the path is blocked by module permissions,
/// or null if access is allowed.
String? _moduleBlockedRedirect(
  String path,
  SavedAccountsStore store,
  String overviewPath,
) {
  final enabledModules = store.activeAccount?.enabledModules;
  if (enabledModules == null) return null;

  // Block search paths when search is disabled
  if ((path == desktopSearchPath || path == mobileSearchPath) &&
      !enabledModules.contains(AppModulePermission.search)) {
    return overviewPath;
  }

  // Block media libraries path when disabled
  if (path == mobileSettingsMediaLibrariesPath &&
      !enabledModules.contains(AppModulePermission.mediaLibraries)) {
    return overviewPath;
  }

  // Block download paths when download management is disabled
  final downloadPaths = [
    mobileSettingsDownloadersPath,
    mobileSettingsIndexersPath,
  ];
  if (downloadPaths.contains(path) &&
      !enabledModules.contains(AppModulePermission.downloadManagement)) {
    return overviewPath;
  }

  return null; // allowed
}

/// Helper that combines multiple Listenable into one.
class ListenableGroup implements Listenable {
  ListenableGroup(List<Listenable> listeners)
      : _listeners = listeners;

  final List<Listenable> _listeners;

  @override
  void addListener(VoidCallback listener) {
    for (final l in _listeners) {
      l.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final l in _listeners) {
      l.removeListener(listener);
    }
  }
}
