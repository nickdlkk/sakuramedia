import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
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
  });

  final String baseUrl;
  final String username;
  final String password;
  final AuthTokensDto tokens;
}

Future<AuthenticatedAccountDraft?> showAddAccountDialog(BuildContext context) {
  return showAppAdaptiveModal<AuthenticatedAccountDraft>(
    context: context,
    modalKey: const Key('saved-accounts-add-modal'),
    desktopWidth: 520,
    mobileMaxHeightFactor: 0.92,
    builder: (_) => const _AddAccountDialogBody(),
  );
}

class _AddAccountDialogBody extends StatefulWidget {
  const _AddAccountDialogBody();

  @override
  State<_AddAccountDialogBody> createState() => _AddAccountDialogBodyState();
}

class _AddAccountDialogBodyState extends State<_AddAccountDialogBody> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;
  String _protocol = 'https';
  String? _submitError;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  String _composeBaseUrl() => '$_protocol://${_baseUrlController.text.trim()}';

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

    final tempSession = SessionStore.inMemory();
    final apiClient = ApiClient(sessionStore: tempSession);
    try {
      final baseUrl = _composeBaseUrl();
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      await tempSession.saveBaseUrl(baseUrl);
      final response = await apiClient.post(
        '/auth/tokens',
        requiresAuth: false,
        data: <String, dynamic>{'username': username, 'password': password},
      );
      final tokens = AuthTokensDto.fromJson(response);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        AuthenticatedAccountDraft(
          baseUrl: baseUrl,
          username: username,
          password: password,
          tokens: tokens,
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
      tempSession.dispose();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateBaseUrl(String? value) {
    final host = value?.trim() ?? '';
    if (host.isEmpty) {
      return '请输入服务器地址';
    }
    final uri = Uri.tryParse('$_protocol://$host');
    if (uri == null || uri.host.isEmpty) {
      return '请输入有效的 http(s) 地址';
    }
    return null;
  }

  String? _validateRequired(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    return null;
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
                '新账号验证成功后会立即保存，并切换为当前账号。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.lg),
              Row(
                children: [
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'http', label: Text('http')),
                      ButtonSegment<String>(
                        value: 'https',
                        label: Text('https'),
                      ),
                    ],
                    selected: <String>{_protocol},
                    onSelectionChanged:
                        _isSubmitting
                            ? null
                            : (value) {
                              setState(() {
                                _protocol = value.first;
                              });
                            },
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppTextField(
                      fieldKey: const Key('saved-accounts-base-url-field'),
                      controller: _baseUrlController,
                      label: '服务器地址',
                      hintText: '127.0.0.1:38000',
                      enabled: !_isSubmitting,
                      validator: _validateBaseUrl,
                    ),
                  ),
                ],
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
                    label: '验证并切换',
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
