import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/core/session/saved_account.dart';
import 'package:sakuramedia/core/session/session_store.dart';

abstract class SavedAccountsStorageBackend {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesSavedAccountsStorageBackend
    implements SavedAccountsStorageBackend {
  SharedPreferencesSavedAccountsStorageBackend(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? getString(String key) {
    return _preferences.getString(key);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _preferences.setString(key, value);
  }
}

class InMemorySavedAccountsStorageBackend implements SavedAccountsStorageBackend {
  final Map<String, String> _storage = <String, String>{};

  @override
  String? getString(String key) {
    return _storage[key];
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }
}

@immutable
class SavedAccountsSnapshot {
  const SavedAccountsSnapshot({
    required this.accounts,
    required this.activeAccountId,
  });

  final List<SavedAccount> accounts;
  final String? activeAccountId;

  SavedAccount? get activeAccount {
    final activeId = activeAccountId;
    if (activeId == null) {
      return null;
    }
    for (final account in accounts) {
      if (account.id == activeId) {
        return account;
      }
    }
    return null;
  }

  Set<AppModulePermission> get activeModules {
    return activeAccount?.enabledModules ??
        <AppModulePermission>{...kDefaultEnabledModules};
  }
}

class SavedAccountsStore extends ChangeNotifier {
  SavedAccountsStore._(this._backend) {
    _restore();
  }

  static const String _accountsKey = 'saved_accounts.items';
  static const String _activeAccountIdKey = 'saved_accounts.active_id';

  final SavedAccountsStorageBackend _backend;
  List<SavedAccount> _accounts = const <SavedAccount>[];
  String? _activeAccountId;

  static Future<SavedAccountsStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    return SavedAccountsStore._(
      SharedPreferencesSavedAccountsStorageBackend(preferences),
    );
  }

  factory SavedAccountsStore.inMemory() {
    return SavedAccountsStore._(InMemorySavedAccountsStorageBackend());
  }

  List<SavedAccount> get accounts => List<SavedAccount>.unmodifiable(_accounts);
  String? get activeAccountId => _activeAccountId;

  SavedAccount? get activeAccount {
    final activeId = _activeAccountId;
    if (activeId == null) {
      return null;
    }
    for (final account in _accounts) {
      if (account.id == activeId) {
        return account;
      }
    }
    return null;
  }

  SavedAccountsSnapshot get snapshot => SavedAccountsSnapshot(
    accounts: accounts,
    activeAccountId: _activeAccountId,
  );

  Future<SavedAccount> upsertAuthenticatedAccount({
    required String baseUrl,
    required String username,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    Set<AppModulePermission>? enabledModules,
    bool activate = true,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedUsername = username.trim();
    final existingIndex = _accounts.indexWhere(
      (account) => account.matchesIdentity(
        baseUrl: normalizedBaseUrl,
        username: normalizedUsername,
      ),
    );
    final existing = existingIndex >= 0 ? _accounts[existingIndex] : null;
    final next = SavedAccount(
      id: existing?.id ?? _newAccountId(),
      baseUrl: normalizedBaseUrl,
      username: normalizedUsername,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
      enabledModules:
          enabledModules ??
          existing?.enabledModules ??
          <AppModulePermission>{...kDefaultEnabledModules},
    );
    final nextAccounts = List<SavedAccount>.from(_accounts);
    if (existingIndex >= 0) {
      nextAccounts[existingIndex] = next;
    } else {
      nextAccounts.add(next);
    }
    _accounts = nextAccounts;
    if (activate) {
      _activeAccountId = next.id;
    }
    await _persistAccounts();
    await _persistActiveAccountId(autoActivateIfNull: activate);
    notifyListeners();
    return next;
  }

  Future<void> activateAccount(String accountId, SessionStore sessionStore) async {
    if (_activeAccountId == accountId) {
      return;
    }
    _activeAccountId = accountId;
    await _persist();
    await syncSession(sessionStore);
    notifyListeners();
  }

  Future<void> updateEnabledModules({
    required String accountId,
    required Set<AppModulePermission> enabledModules,
  }) async {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index < 0) {
      return;
    }
    final nextAccounts = List<SavedAccount>.from(_accounts);
    nextAccounts[index] = nextAccounts[index].copyWith(
      enabledModules: <AppModulePermission>{...enabledModules},
    );
    _accounts = nextAccounts;
    await _persist();
    notifyListeners();
  }

  Future<void> removeAccount(String accountId, SessionStore sessionStore) async {
    final removingActive = accountId == _activeAccountId;
    _accounts = _accounts.where((account) => account.id != accountId).toList(
      growable: false,
    );
    if (_accounts.isEmpty) {
      _activeAccountId = null;
      await _persist();
      if (removingActive) {
        await sessionStore.clearSession();
        await sessionStore.saveBaseUrl('');
      }
      notifyListeners();
      return;
    }
    if (removingActive) {
      _activeAccountId = _accounts.first.id;
      await _persist();
      await syncSession(sessionStore);
      notifyListeners();
      return;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> logOutActiveAccount(SessionStore sessionStore) async {
    final active = activeAccount;
    if (active == null) {
      await sessionStore.clearSession();
      return;
    }
    final index = _accounts.indexWhere((account) => account.id == active.id);
    if (index >= 0) {
      final nextAccounts = List<SavedAccount>.from(_accounts);
      nextAccounts[index] = active.copyWith(
        accessToken: '',
        refreshToken: '',
        clearExpiresAt: true,
      );
      _accounts = nextAccounts;
      await _persist();
    }
    await sessionStore.clearSession();
    await sessionStore.saveBaseUrl(active.baseUrl);
    notifyListeners();
  }

  Future<void> syncSession(SessionStore sessionStore) async {
    final active = activeAccount;
    if (active == null) {
      return;
    }
    await sessionStore.saveBaseUrl(active.baseUrl);
    if (active.hasSession && active.expiresAt != null) {
      await sessionStore.saveTokens(
        accessToken: active.accessToken,
        refreshToken: active.refreshToken,
        expiresAt: active.expiresAt!,
      );
      return;
    }
    await sessionStore.clearSession();
    await sessionStore.saveBaseUrl(active.baseUrl);
  }

  Future<void> updateActiveUsername(String username) async {
    final active = activeAccount;
    if (active == null) {
      return;
    }
    final normalized = username.trim();
    if (normalized.isEmpty || normalized == active.username) {
      return;
    }
    final index = _accounts.indexWhere((account) => account.id == active.id);
    if (index < 0) {
      return;
    }
    final nextAccounts = List<SavedAccount>.from(_accounts);
    nextAccounts[index] = active.copyWith(username: normalized);
    _accounts = nextAccounts;
    await _persist();
    notifyListeners();
  }

  void _restore() {
    final rawAccounts = _backend.getString(_accountsKey);
    if (rawAccounts != null && rawAccounts.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAccounts);
        if (decoded is List) {
          _accounts = decoded
              .whereType<Object?>()
              .map(
                (item) => SavedAccount.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .where((account) => account.id.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        _accounts = const <SavedAccount>[];
      }
    }
    final activeId = _backend.getString(_activeAccountIdKey);
    if (activeId != null &&
        _accounts.any((account) => account.id == activeId)) {
      _activeAccountId = activeId;
    } else {
      _activeAccountId = _accounts.isEmpty ? null : _accounts.first.id;
    }
  }

  Future<void> _persist() async {
    await _persistAccounts();
    await _persistActiveAccountId(autoActivateIfNull: true);
  }

  Future<void> _persistAccounts() async {
    await _backend.setString(
      _accountsKey,
      jsonEncode(
        _accounts.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }

  Future<void> _persistActiveAccountId({bool autoActivateIfNull = true}) async {
    final activeId = _activeAccountId;
    if (activeId == null ||
        !_accounts.any((account) => account.id == activeId)) {
      _activeAccountId =
          autoActivateIfNull && _accounts.isNotEmpty
              ? _accounts.first.id
              : null;
    }
    if (_activeAccountId == null) {
      await _backend.remove(_activeAccountIdKey);
      return;
    }
    await _backend.setString(_activeAccountIdKey, _activeAccountId!);
  }

  static String _newAccountId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    return 'account-$micros';
  }
}
