import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/core/session/providers/credential_store_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/saved_account.dart';
import 'package:sakuramedia/core/session/saved_accounts_store.dart';

final savedAccountsStoreRuntimeProvider = Provider<SavedAccountsStore>((ref) {
  throw UnimplementedError('Override savedAccountsStoreRuntimeProvider at the app root');
});

final savedAccountsRuntimeProvider =
    NotifierProvider<SavedAccountsRuntimeNotifier, SavedAccountsSnapshot>(
      SavedAccountsRuntimeNotifier.new,
    );

class SavedAccountsRuntimeNotifier extends Notifier<SavedAccountsSnapshot> {
  VoidCallback? _listener;

  @override
  SavedAccountsSnapshot build() {
    final store = ref.watch(savedAccountsStoreRuntimeProvider);
    _listener ??= () {
      ref.invalidateSelf();
    };
    store.addListener(_listener!);
    ref.onDispose(() {
      if (_listener != null) {
        store.removeListener(_listener!);
        _listener = null;
      }
    });
    return store.snapshot;
  }

  Future<SavedAccount> saveAuthenticatedAccount({
    required String baseUrl,
    required String username,
    required String password,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    final store = ref.read(savedAccountsStoreRuntimeProvider);
    final account = await store.upsertAuthenticatedAccount(
      baseUrl: baseUrl,
      username: username,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
    await ref.read(credentialStoreProvider).saveAccountPassword(
      accountId: account.id,
      password: password,
    );
    await store.syncSession(ref.read(sessionStoreProvider));
    return account;
  }

  Future<void> activate(String accountId) {
    return ref.read(savedAccountsStoreRuntimeProvider).activateAccount(
      accountId,
      ref.read(sessionStoreProvider),
    );
  }

  Future<void> removeAccount(String accountId) async {
    await ref.read(savedAccountsStoreRuntimeProvider).removeAccount(
      accountId,
      ref.read(sessionStoreProvider),
    );
    await ref.read(credentialStoreProvider).deleteAccountPassword(accountId);
  }

  Future<void> updateEnabledModules({
    required String accountId,
    required Set<AppModulePermission> enabledModules,
  }) {
    return ref.read(savedAccountsStoreRuntimeProvider).updateEnabledModules(
      accountId: accountId,
      enabledModules: enabledModules,
    );
  }

  Future<void> logOutActiveAccount() {
    return ref.read(savedAccountsStoreRuntimeProvider).logOutActiveAccount(
      ref.read(sessionStoreProvider),
    );
  }

  Future<void> updateActiveUsername(String username) {
    return ref.read(savedAccountsStoreRuntimeProvider).updateActiveUsername(username);
  }
}

final enabledModulesRuntimeProvider = Provider<Set<AppModulePermission>>((ref) {
  return ref.watch(savedAccountsRuntimeProvider).activeModules;
});

final hasModulePermissionRuntimeProvider = Provider.family<bool, AppModulePermission>((
  ref,
  module,
) {
  return ref.watch(enabledModulesRuntimeProvider).contains(module);
});
