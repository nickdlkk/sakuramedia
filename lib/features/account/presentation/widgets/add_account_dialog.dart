import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/app_module_permission.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_tokens_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

class AuthenticatedAccountDraft {
  const AuthenticatedAccountDraft({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.tokens,
    required this.enabledModules,
  });

  final String baseUrl;
  final String username;
  final String password;
  final AuthTokensDto tokens;
  final Set<AppModulePermission> enabledModules;
}

Future<AuthenticatedAccountDraft?> showAddAccountDialog(
  BuildContext context, {
  required SessionStore sessionStore,
}) {
  return showAppAdaptiveModal<AuthenticatedAccountDraft>(
    context: context,
    modalKey: const Key('saved-accounts-add-modal'),
    desktopWidth: 520,
    mobileMaxHeightFactor: 0.92,
    builder: (_) => _AddAccountDialogBody(sessionStore: sessionStore),
  );
}

class _AddAccountDialogBody extends StatefulWidget {
  const _AddAccountDialogBody({required this.sessionStore});

  final SessionStore sessionStore;

  @override
  State<_AddAccountDialogBody> createState() => _AddAccountDialogBodyState();
}

class _AddAccountDialogBodyState extends State<_AddAccountDialogBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;
  String? _submitError;
  late final Set<AppModulePermission> _selectedModules =
      <AppModulePermission>{...kDefaultEnabledModules};

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  String get _baseUrl => widget.sessionStore.baseUrl;

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!_hasAttemptedSubmit) {
      setState(() {
        _hasAttemptedSubmit = true;
      });
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final apiClient = ApiClient(sessionStore: widget.sessionStore);
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final permissions = _selectedModules
          .map((module) => module.wireValue)
          .toList(growable: false);

      // 1) 先在后端创建账号（需要当前账号为管理员）。账号已存在时视为
      //    “添加已有账号”，跳过创建直接登录。
      try {
        await apiClient.post(
          '/accounts',
          requiresAuth: true,
          data: <String, dynamic>{
            'username': username,
            'password': password,
            'role': 'user',
            'permissions': permissions,
          },
        );
      } on ApiException catch (error) {
        if (error.error?.code != 'username_conflict') {
          if (!mounted) {
            return;
          }
          setState(() {
            _submitError = _accountCreateErrorMessage(error);
          });
          return;
        }
      }

      // 2) 登录新账号以获取令牌。
      final response = await apiClient.post(
        '/auth/tokens',
        requiresAuth: false,
        data: <String, dynamic>{
          'username': username,
          'password': password,
        },
      );
      final tokens = AuthTokensDto.fromJson(response);

      // 3) 以后端返回的功能权限为准，同步客户端可见模块。
      final backendModules = _modulesFromPermissions(tokens.user.permissions);
      final enabledModules = backendModules.isNotEmpty
          ? backendModules
          : <AppModulePermission>{..._selectedModules};

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        AuthenticatedAccountDraft(
          baseUrl: _baseUrl,
          username: username,
          password: password,
          tokens: tokens,
          enabledModules: enabledModules,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = apiErrorMessage(error, fallback: '添加账号失败，请稍后重试');
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = '添加账号失败，请检查网络或服务器地址';
      });
    } finally {
      apiClient.dispose();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _accountCreateErrorMessage(ApiException error) {
    switch (error.error?.code) {
      case 'username_conflict':
        return '该用户名已存在，请更换后重试';
      case 'forbidden':
        return '当前账号不是管理员，无法创建账号';
      case 'invalid_username':
        return '用户名不能为空或包含非法字符';
      case 'invalid_role':
      case 'invalid_module':
        return '账号权限参数无效，请调整后重试';
      default:
        return apiErrorMessage(error, fallback: '创建账号失败，请稍后重试');
    }
  }

  Set<AppModulePermission> _modulesFromPermissions(List<String>? permissions) {
    if (permissions == null) {
      return <AppModulePermission>{};
    }
    final result = <AppModulePermission>{};
    for (final value in permissions) {
      final module = AppModulePermissionX.fromWireValue(value);
      if (module != null) {
        result.add(module);
      }
    }
    return result;
  }

  String? _validateRequired(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    return null;
  }

  Widget _buildModuleToggle(AppModulePermission module) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            module.icon,
            size: 20,
            color: context.appTextPalette.secondary,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
                Text(
                  module.description,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _selectedModules.contains(module),
            onChanged: _isSubmitting
                ? null
                : (selected) {
                    setState(() {
                      if (selected) {
                        _selectedModules.add(module);
                      } else {
                        _selectedModules.remove(module);
                      }
                    });
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '添加账号',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s20,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                '在当前服务器（$_baseUrl）创建并保存新账号，所选权限会同步到服务器；创建后不会切换当前登录账号。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.lg),
              AppTextField(
                fieldKey: const Key('saved-accounts-username-field'),
                controller: _usernameController,
                label: '用户名',
                hintText: '输入登录用户名',
                enabled: !_isSubmitting,
                validator: (value) => _validateRequired('用户名', value),
              ),
              SizedBox(height: spacing.lg),
              AppPasswordField(
                fieldKey: const Key('saved-accounts-password-field'),
                controller: _passwordController,
                label: '密码',
                validator: (value) => _validateRequired('密码', value),
              ),
              SizedBox(height: spacing.lg),
              Text(
                '账号权限',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                '选择该账号可用的功能模块，会同步写入服务器权限；可后续在账号列表中调整。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.sm),
              for (final module in AppModulePermission.values)
                _buildModuleToggle(module),
              if (_submitError != null) ...[
                SizedBox(height: spacing.md),
                Text(
                  _submitError!,
                  key: const Key('saved-accounts-submit-error'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
              ],
              SizedBox(height: spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    key: const Key('saved-accounts-cancel-button'),
                    label: '取消',
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: spacing.md),
                  AppButton(
                    key: const Key('saved-accounts-submit-button'),
                    label: '添加',
                    variant: AppButtonVariant.primary,
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
